---
title: nginx-0x0D-关于伪事件的防御
category_bar: true
date: 2025-04-09 17:43:56
categories: nginx
---

### 1 僵尸事件和伪事件

在聊清楚僵尸事件和伪事件之前先要理清楚多路复用器的工作流程和对fd的生命周期管理，以epoll为例

epoll管理了2个容器，红黑树管理监听的fd，ready list就绪列表记录已经发生事件的fd

这里需要有几个问题弄清楚

- fd是什么，fd就是一个整数，代表着一个数组的脚标，这个数组是文件描述符数组，数组里面放的是file实例
- file实例是什么，linux中万物皆文件指的就是file，它的管理者是内核，生命周期的管理方式是引用计数，只要file对象的引用计数到0内核就会自动释放file
- 红黑树是epoll中用于管理监听fd的地方
- 就绪列表里面fd的存放是内核自动完成的，fd指向的file仅仅是抽象概念，它一定对应计算机真实物理设备，比如网卡，当网卡传来数据，意味着某个socket可读，也就是fd可读，然后内核自动将这个fd指向的file*放到就绪列表，并且这个地方并不涉及对file引用计数的增加
- 当用户态调用epoll_wait时如果就绪列表有值就立即返回告诉用户态，如果就绪列表为空就阻塞等待就绪列表有值或者epoll_wait调用超时

至此来梳理一下实际开发过程

| 步骤 | 系统调用                                    | soket对象引用计数 | file对象引用计数 | epoll对象引用计数 |
| ---- | ------------------------------------------- | ----------------- | ---------------- | ----------------- |
| 1    | int fd = socket(AF_INET, SOCK_STREAM, 0)    | 1                 | 1                | 0                 |
| 2    | epoll_fd = epoll_create1(0);                | 1                 | 1                | 1                 |
| 3    | epoll_ctl(epoll_fd, EPOLL_CTL_ADD, fd, &ev) | 1                 | 2                | 1                 |
| 4    | epoll_ctl(epfd, EPOLL_CTL_DEL, fd, NULL)    | 1                 | 1                | 1                 |
| 5    | close(fd)                                   | 0                 | 0                | 1                 |
| 6    | close(epoll_fd)                             | 0                 | 0                | 0                 |

这样操作步骤是没有问题的，最终socket对象和file对象都会因为引用计数归为0被内核回收释放资源

至此，假设没有步骤4和6

| 步骤 | 系统调用                                    | soket对象引用计数 | file对象引用计数 |
| ---- | ------------------------------------------- | ----------------- | ---------------- |
| 1    | int fd = socket(AF_INET, SOCK_STREAM, 0)    | 1                 | 1                |
| 2    | epoll_fd = epoll_create1(0);                | 1                 | 1                |
| 3    | epoll_ctl(epoll_fd, EPOLL_CTL_ADD, fd, &ev) | 1                 | 2                |
| 5    | close(fd)                                   | 0                 | 1                |

epoll红黑树中有对fd对应的file对象引用，计数是1

#### 1.1 僵尸事件

假如在3之后fd代表的socket有连接请求过来，此时内核会将fd代表的file*放到就绪列表，在5之后执行一次`int nfds = epoll_wait(epoll_fd, events, MAX_EVENTS, 1000)`，这个时候fd指向的socket已经释放了没法操作了，可能会引发崩溃。

假如我拿到这个就绪事件也不处理让程序继续执行，那么epoll红黑树中是永远监听着这个fd的，但是虽然监听fd但是这个fd已经没有了物理设备，自然也就永远不会被触发，这个事件就是僵尸事件永远挂在红黑树上。


#### 1.2 伪事件

比起僵尸事件，伪事件危害是更大的。
在5之后，fd又被系统分配出去了，系统的分配机制是最小可用，比如恰好是另一个进程执行的`int fd=socket()`，恰好这个fd可读了，内核就会将fd指向的file*放到epoll的就绪列表，然后执行`epoll_wait`就能拿到这个fd。这个时候拿到的fd其实不该被拿到，相当于是一个过期事件，就是伪事件。

继续
- 用户态处理了后果是可想而知的，无法预料的后果
- 如果用户态代码拿到fd后不知道如何处理会有什么后果，这个时候又要讨论多路复用器的触发模式了

依然以epoll为例，有两种触发模式
- 水平式触发，只要可读或可写就一直在就绪列表，比如socket收到10Byte，执行一次`epoll_wait`，现在只读取5Byte还有5Byte留在缓冲区，下一次`epoll_wait`还会被触发说可读
- 边缘式触发，触发非就绪到就绪才会被放到就绪列表，比如socket收到10Byte，执行一次`epoll_wait`，现在只读取5Byte还有5Byte留在缓冲区，下一次`epoll_wait`这个fd不会被触发

所以
- 当水平式模式时，不处理伪事件，就会一直被触发就绪，导致epoll空转，cpu打满
- 当边缘式模式时，不处理伪事件，后面这个伪事件也不会被触发，等于几乎没有其他风险

### 2 Netty中的优化
{% post_link Netty/Netty源码-04-Selector %}在这篇提过Netty对这个问题的优化方案，根据经验值计数判定重新注册事件。

### 3 Nginx中的方案
上面Netty中的方案采用的是曲线救国方式，用一点点的cpu负载代价来减少空转，并不能从根上解决问题。
而问题的根因是fd被系统复用了，因此只要能识别出fd是不是被复用就行了，一旦从复用器拿到的fd是被复用的就直接不处理，并且保证复用器是边缘式触发模式，就可以彻底解决伪事件的不良影响。

- 但是直观上判断系统的fd有没有被复用是没办法做到的
- nginx抽象了几个结构体
  - nginx_event_s 事件
  - nginx_connection_s 连接
- 事件分为读写两个 event:connection:fd=2:1:1

![](./nginx-0x0D-关于伪事件的防御/1744264828.png)

换言之fd跟event是可以互相回溯的，二者是等价的，所以判断fd有没有被复用就变成了判断event跟fd之间的映射关系是不是正确的

所以nginx通过两个设计就可以避免伪事件的影响
- epoll\kequeue边缘式触发
- instance防伪码

#### 3.1 多路复用器触发方式

```c
// 多路复用器触发模式 边缘式 搭配instance机制防御僵尸事件和伪事件
#define NGX_CLEAR_EVENT    EV_CLEAR
```

```c
        if (!rev->active && !rev->ready) {
            // 向多路复用器注册事件 监听读 设置为边缘式触发方式 将来配合instance机制防御僵尸事件和伪事件
            if (ngx_add_event(rev, NGX_READ_EVENT, NGX_CLEAR_EVENT)
                == NGX_ERROR)
            {
                return NGX_ERROR;
            }
        }
```

#### 3.2 instance机制
```c
            /*
             * 读写事件的处理
             * <ul>
             *   <li>可读的触发条件
             *     <ul>
             *       <li>socket中有数据没有被读取</li>
             *       <li>文件 设备准备好可以读取</li>
             *       <li>连接被关闭 连接被关闭的时候会返回事件可读并且可读的data长度是0</li>
             *     </ul>
             *   </li>
             *   <li>可写的触发条件
             *     <ul>
             *       <li>socket写缓冲区中有数据</li>
             *       <li>文件描述符已就绪可写 但不表示对方一定能收完数据</li>
             *     </ul>
             *   </li>
             * </ul>
             */
            /*
             * 伪事件的防御设计
             * 在复用器kq的udata中存放的是一个变种地址
             * <ul>
             *   <li>指针后3位是0</li>
             *   <li>最低位被放上了翻转版本号</li>
             * </ul>
             * 所以拿到内核返回的udata
             * <ul>
             *   <li>只要把最低位抹成0就是真正的用户事件地址</li>
             *   <li>只解析最低位的1bit就是翻转版本号 防伪码</li>
             * </ul>
             */
            instance = (uintptr_t) ev & 1;
            ev = (ngx_event_t *) ((uintptr_t) ev & (uintptr_t) ~1);
            /*
             * 解决事件伪触发问题的体现
             * 这边有几个关注点
             * <ul>
             *   <li>1 防伪码为什么只要2种就行 也就是0和1翻转为什么可以达到验伪事件效果 为什么不需要考虑更久之前的连接</li>
             *   <li>2 event是nginx抽象的 在向复用器注册事件时翻转instance值 所谓反转就是上次是0这次就是1 上次是1这次就是0 所以nginx是怎么知道event上一次的instance值是多少的</li>
             * </ul>
             * 这两个问题
             * <ul>
             *   <li>第1个问题 是操作系统保证的 内核中过时事件的保留是短暂的 只会保留一次触发后没被消费掉的伪事件 之后会被清理或覆盖 也就是伪事件根本不会出现更早的连接 最多只有上一次的连接 所以nginx要做的事情就是不要把伪事件注册回复用器就行 识别出伪事件什么也不用做</li>
             *   <li>第2个问题 nginx中有内存池 所谓的连接关闭仅仅是在结构体标识位打上关闭标识然后把内存还给内存池 并没有真正把内存free给操作系统 所以下一次分配到的event地址里面就是上一次遗留的instance值</li>
             * </ul>
             * 操作系统的伪事件留存机制和nginx内存池设计一起作用 只要翻转instance就足够保证防御伪事件
             * event在内存池中 在上一次释放后 再拿到同一个event地址后 event状态无非就两种
             * <ul>
             *   <li>再没被分配出去 也就是没有被复用 它的状态还是close</li>
             *   <li>被分配出去了 也就是被复用了 它的状态不是close 所以要进行验证 看看是不是过期了 也就是伪事件</li>
             * </ul>
             */
            if (ev->closed || ev->instance != instance) {
                /*
                 * the stale event from a file descriptor
                 * that was just closed in this iteration
                 */

                ngx_log_debug1(NGX_LOG_DEBUG_EVENT, cycle->log, 0,
                               "kevent: stale event %p", ev);
                // 不用处理 操作系统自会回收清除没有被处理的伪事件
                continue;
            }
```
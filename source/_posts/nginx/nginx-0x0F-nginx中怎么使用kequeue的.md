---
title: nginx-0x0F-nginx中怎么使用kequeue的
category_bar: true
date: 2025-04-11 16:53:24
categories: nginx
---

出于对模块化和跨平台化的考虑，nginx对kq进行了一层封装，核心就3个API

- 实例化kq
- 管理监听列表
- 获取就绪列表

### 1 实例化

在实例化过程中有个功能点需要关注{% post_link nginx/nginx-0x0A-定时器 %}

```c
    // 需要借助kq实现高精度定时器 定时器间隔就是timer(ms)
    if (timer) {
        kev.ident = 0;
        // 表明注册的事件类型是定时器事件 不是读写事件 kq会在设定的时间间隔触发这个事件
        kev.filter = EVFILT_TIMER;
        /*
         * 两个作用
         * <ul>
         *   <li>ADD表明向kq注册新事件 如果kq中已经存在这个事件就更新</li>
         *   <li>ENABLE表明启用这个事件 让它开始工作</li>
         * </ul>
         */
        kev.flags = EV_ADD|EV_ENABLE;
        // 定时器不需要子标志
        kev.fflags = 0;
        // 间隔时间 ms
        kev.data = timer;
        kev.udata = 0;

        ts.tv_sec = 0;
        ts.tv_nsec = 0;
        // 向kq注册定时器
        if (kevent(ngx_kqueue, &kev, 1, NULL, 0, &ts) == -1) {
            ngx_log_error(NGX_LOG_ALERT, cycle->log, ngx_errno,
                          "kevent(EVFILT_TIMER) failed");
            return NGX_ERROR;
        }
        // 全局变量标识使用了定时器
        ngx_event_flags |= NGX_USE_TIMER_EVENT;
    }
```

### 2 管理监听列表

不管是kqueue还是epoll对事件的管理无非也就是添加事件或者删除事件。

#### 2.1 nginx对kevent注册事件封装

kqueue相对于epoll而言有两点不同

- 注册事件和获取就绪事件的系统调用都是kevent
- kqueue支持批量注册而epoll只支持单个提交

```c
/*
 * 注册事件 这个注册可能是个延迟注册 需要立即注册到内核需要指定falgs操作指令
 * 对kevent系统调用的封装 因为kevent支持批量提交 因此nginx维护了change_list作缓存实现特定时机的批量提交
 * @param ev nginx封装的事件
 * @param event 监听的事件类型 EVFILT_READ
 * @param flags 操作指令
 *              <ul>
 *                <li>EV_ADD 添加事件</li>
 *                <li>EV_ENABLE 启用事件</li>
 *                <li>EV_ONESHOT 触发一次后自动移除</li>
 *                <li>EV_CLEAR 边缘触发模式</li>
 *                <li>NGX_FLUSH_EVENT 立即注册事件到kq</li>
 *              </ul>
 */
static ngx_int_t
ngx_kqueue_set_event(ngx_event_t *ev, ngx_int_t filter, ngx_uint_t flags)
{
    // kq的事件体 在udata域上存放的是nginx封装的事件体
    struct kevent     *kev;
    struct timespec    ts;
    ngx_connection_t  *c;
    // 连接
    c = ev->data;

    ngx_log_debug3(NGX_LOG_DEBUG_EVENT, ev->log, 0,
                   "kevent set event: %d: ft:%i fl:%04Xi",
                   c->fd, filter, flags);
    // kq支持批量注册 当前可能是立即注册可能是懒注册 不管咋样都要把事件先缓存在change_list中 所以先看看缓存满了没有
    if (nchanges >= max_changes) {
        // change_list队列满了 先批量注册到kq 把change_list空出来
        ngx_log_error(NGX_LOG_WARN, ev->log, 0,
                      "kqueue change list is filled up");

        ts.tv_sec = 0;
        ts.tv_nsec = 0;
        // 批量注册
        if (kevent(ngx_kqueue, change_list, (int) nchanges, NULL, 0, &ts)
            == -1)
        {
            ngx_log_error(NGX_LOG_ALERT, ev->log, ngx_errno, "kevent() failed");
            return NGX_ERROR;
        }
        // 移动change_list的脚标 逻辑上就清空了change_list队列了 可以继续缓存事件了
        nchanges = 0;
    }
    // 把要注册的事件缓存到change_list中
    kev = &change_list[nchanges];

    kev->ident = c->fd;
    kev->filter = (short) filter;
    kev->flags = (u_short) flags;
    /*
     * 这个地方的设计是用来防事件过期的校验
     * udata存的是一个nginx封装的事件的伪地址 包括两部分信息
     * <ul>
     *   <li>nginx事件的真实地址信息</li>
     *   <li>事件伪触发过期的校验码</li>
     * </ul>
     * 首先关于地址对齐
     * <ul>
     *   <li>64位架构是8Byte对齐 地址低3位是0</li>
     *   <li>32位架构是4Byte对齐 地址低2位是0</li>
     * </ul>
     * 也就是说指针的最低位是没有用了 可以复用 只要在解引用的时候还原成0就行了
     * 那么就可以在指针的最低位放上版本号
     */
    kev->udata = NGX_KQUEUE_UDATA_T ((uintptr_t) ev | ev->instance);

    if (filter == EVFILT_VNODE) {
        kev->fflags = NOTE_DELETE|NOTE_WRITE|NOTE_EXTEND
                                 |NOTE_ATTRIB|NOTE_RENAME
#if (__FreeBSD__ == 4 && __FreeBSD_version >= 430000) \
    || __FreeBSD_version >= 500018
                                 |NOTE_REVOKE
#endif
                      ;
        kev->data = 0;

    } else {
#if (NGX_HAVE_LOWAT_EVENT)
        if (flags & NGX_LOWAT_EVENT) {
            kev->fflags = NOTE_LOWAT;
            kev->data = ev->available;

        } else {
            kev->fflags = 0;
            kev->data = 0;
        }
#else
        kev->fflags = 0;
        kev->data = 0;
#endif
    }
    // 记录当前事件在change_list数组的脚标 方便后面快速索引进行修改更新
    ev->index = nchanges;
    // 待注册事件已经缓存到了change_list中 更新当前change_list队列数量
    nchanges++;

    if (flags & NGX_FLUSH_EVENT) {
        /*
         * 这个地方等于是通过NGX_FLUSH_EVENT控制了注册时机
         * <ul>
         *   <li>可以及时注册</li>
         *   <li>可能缓存在change_list中等到下一次调用方指定及时注册</li>
         *   <li>也可能一直等到change_list满了 等到下一次调用时才注册</li>
         * </ul>
         * 所以把控制权交给调用方 对于时延有要求的场景把NGX_FLUSH_EVENT进行立即注册
         */
        ts.tv_sec = 0;
        ts.tv_nsec = 0;

        ngx_log_debug0(NGX_LOG_DEBUG_EVENT, ev->log, 0, "kevent flush");

        if (kevent(ngx_kqueue, change_list, (int) nchanges, NULL, 0, &ts)
            == -1)
        {
            ngx_log_error(NGX_LOG_ALERT, ev->log, ngx_errno, "kevent() failed");
            return NGX_ERROR;
        }

        nchanges = 0;
    }

    return NGX_OK;
}
```

#### 2.2 添加事件

添加事件比较简单，就是调用上面封装的方法。

```c
/**
 * kq中注册事件和获取就绪事件是同一个系统调用kevent
 * <ul>
 *   <li>通过不同的changelist和eventlist来控制是注册事件还是获取就绪事件</li>
 *   <li>通过不同的flags动作指令达到注册 删除 修改操作</li>
 * </ul>
 * 在kevent上封装一层主义清晰的事件注册增删改接口
 * 注册事件
 * @param flags NGX_FLUSH_EVENT指令控制及时注册到内核
 */
static ngx_int_t
ngx_kqueue_add_event(ngx_event_t *ev, ngx_int_t event, ngx_uint_t flags)
{
    ngx_int_t          rc;
#if 0
    ngx_event_t       *e;
    ngx_connection_t  *c;
#endif

    ev->active = 1;
    ev->disabled = 0;
    // 标识事件是一次性事件
    ev->oneshot = (flags & NGX_ONESHOT_EVENT) ? 1 : 0;

    // 添加到kq监听列表并立即生效
    rc = ngx_kqueue_set_event(ev, event, EV_ADD|EV_ENABLE|flags);

    return rc;
}
```

#### 2.3 删除事件

删除事件看到了数组原地删除的方法，这个在以前刷leetcode好像遇到过。

```c
	/*
	 * nginx层面的change_list是个缓存队列 意味着缓存在缓存队列中的事件可能已经被注册到了内核
	 * 所以
	 * <ul>
	 *   <li>index有效 在[0...nchanges)之间 说明事件可能还驻留在change_list缓存队列中</li>
	 *   <li>index无效 不在[0...nchanges)之间 说明事件肯定已经被注册到内核了 而不在change_list中缓存了</li>
	 * </ul>
	 * 经过初步的判断之后就从缓存脚标上拿到事件 比较指针
	 * change_list中存放的是内核kq的事件 从udata上拿到伪地址 把低位抹0拿到真是的nginx事件地址
	 */
    if (ev->index < nchanges
        && ((uintptr_t) change_list[ev->index].udata & (uintptr_t) ~1)
            == (uintptr_t) ev)
    {
        ngx_log_debug2(NGX_LOG_DEBUG_EVENT, ev->log, 0,
                       "kevent deleted: %d: ft:%i",
                       ngx_event_ident(ev->data), event);

        /* if the event is still not passed to a kernel we will not pass it */
		/*
		 * 事件并没有真正注册到内核上 从change_list缓存中删除就行
		 * 删除方式也是经典的数组原地删除 数组长度sz
		 * <ul>
		 *   <li>移动数组末脚标达到删除效果 此时数组长度sz-1</li>
		 *   <li>要删除的刚好就是刚才被删除的位置就结束了</li>
		 *   <li>否则就在原来数组[0...sz-2]上多了一个待删除位置 相当于数组空洞 用原来[sz-1]填上这个位置</li>
		 * </ul>
		 */
        nchanges--;

        if (ev->index < nchanges) {
			// 要保留的事件 用这个事件把因为删除产生的数组空洞填上
            e = (ngx_event_t *)
                    ((uintptr_t) change_list[nchanges].udata & (uintptr_t) ~1);
			// 空洞放上要保留的事件
            change_list[ev->index] = change_list[nchanges];
			// 事件在change_list上缓存脚标更新
            e->index = ev->index;
        }

        return NGX_OK;
    }
```

### 3 就绪列表

在这个地方有3个细节处理
- 借助kq的定时事件更新系统时间
- 僵尸事件\伪事件的处理
- 为了系统分派\吞吐\异步进行队列处理

#### 3.1 定时器事件更新系统时间

这个在之前的{% post_link nginx/nginx-0x0C-系统时间 %}已经提过。

```c
        // 就绪的事件是个定时器事件 借助这个事件更新系统时间 等会函数调用方的主线程要触发定时任务执行 依赖更新过后的系统时间来判断任务是否到期
        if (event_list[i].filter == EVFILT_TIMER) {
            // 更新系统时间
            ngx_time_update();
            continue;
        }
```

#### 3.2 伪事件处理

这个在之前的{% post_link nginx/nginx-0x0D-关于伪事件的防御 %}也提过。

```c
		// 拿到伪地址 对应nginx的event和instance防伪码
        ev = (ngx_event_t *) event_list[i].udata;
        // 就绪事件类型 看看是不是读写事件 连接事件也是可写事件 只是可写内容是0而已
        switch (event_list[i].filter) {

        case EVFILT_READ: // 可读
        case EVFILT_WRITE: // 可写
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
             *   <li>64位架构地址是64位8Byte对齐 说明指针的后3位是0</li>
             *   <li>最低位被放上了翻转版本号</li>
             * </ul>
             * 所以拿到内核返回的udata
             * <ul>
             *   <li>只要把最低位抹成0就是真正的用户事件地址 nginx封装的通用事件event</li>
             *   <li>只解析最低位的1bit就是翻转版本号 防伪码</li>
             * </ul>
             */
			// 拿到fd的防伪码
            instance = (uintptr_t) ev & 1;
			// 拿到nginx的event
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
				/*
				 * <ul>
				 *   <li>event已经close了说明内核给的fd是僵尸事件 因为在注册事件的时候指定的触发模式是边缘式触发 事件只会触发一次 所以不处理 让事件继续挂在内核监听列表也无所谓</li>
				 *   <li>instance防伪码不一致说明fd是伪事件 那就更不能处理了 后面自然会有fd真正的event</li>
				 * </ul>
				 */
                continue;
            }
```

#### 3.1 分派队列

```c
        if (flags & NGX_POST_EVENTS) {
            /*
             * 为什么要分开 因为这两类事件的处理场景 优先级 调度策略都不同
             * <ul>
             *   <li>ev->accept==1 新连接事件 投递到ngx_posted_accept_events队列</li>
             *   <li>已有连接上的读写 投递到ngx_posted_events队列</li>
             * </ul>
             * 为什么要分开处理
             * <ul>
             *   <li>Accept事件处理通常更轻 但更频繁 Accept事件只需要调用accept()接收新连接 然后创建连接结构体 这一步很快 但在高并发场景中非常频繁 如果和业务请求混在一起处理 可能会导致请求被延迟处理 所以优先或独立处理accept 可以提升请求接收效率</li>
             *   <li>防止惊群效应 Nginx多进程时 每个进程都可能监听相同的端口 如果同时处理accept和业务事件 很容易导致惊群 通过单独调度ngx_posted_accept_events 可以设置为只有一个进程处理accept 其余进程处理业务 提高负载均衡效果</li>
             *   <li>便于定制不同的处理策略 分开队列就能做到<ul>
             *     <li>accept队列 可以批量处理多个连接再处理请求</li>
             *     <li>普通事件队列 按照负载控制 节流处理业务请求</li>
             *   </ul></li>
             * </ul>
             * Nginx甚至可以配置multi_accept 一次处理多个accept事件 这种策略就只对ngx_posted_accept_events起作用
             */
            queue = ev->accept ? &ngx_posted_accept_events
                               : &ngx_posted_events;
            // 事件投递到队列
            ngx_post_event(ev, queue);

            continue;
        }
```
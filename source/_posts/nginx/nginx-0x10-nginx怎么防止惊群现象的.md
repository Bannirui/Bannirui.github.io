---
title: nginx-0x10-nginx怎么防止惊群现象的
category_bar: true
date: 2025-04-12 21:20:36
categories: nginx
---

accept静群的前提是多进程下共享服务端socket的fd，因此可以先看{% post_link nginx/nginx-0x11-进程模型 %}。

### 1 nginx服务要监听哪些端口

#### 1.1 怎么配置

在`nginx.conf`配置文件中指定要监听的端口，告诉nginx服务监听在哪些端口上。

```conf
    server {
        listen       80;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        location / {
            root   html;
            index  index.html index.htm;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
```

#### 1.2 socket插口初始化监听

在启动过程中会初始化一个重要的变量`cycle`，在`ngx_init_cycle`这个方法中涉及到开启socket套接字的监听。

```c
    /*
     * 要监听的端口开启tcp套接字的监听 等待连接过来
     * 上面在回调核心模块event模块的ngx_event_init_conf方法时会尝试为所有worker进程都复制一份监听端口
     * <ul>
     *   <li>端口复用reuseport就把监听端口复制出来编上worker号 还是放在cycle的listening数组里面
     *     <ul>
     *       <li>假如要监听的端口是80 有4个worker进程</li>
     *       <li>那么原来在listening数组的80端口给进程0用 啥也不用干</li>
     *       <li>从1到3开始遍历作为进程编号 把80复制一份 打上编号</li>
     *     </ul>
     *   </li>
     *   <li>默认不复用端口 那么cycle全局变量中listening数组中要监听的端口数量就是配置文件中指定的数理 就一份</li>
     * </ul>
     * master进程对要监听端口socket->bind->listen 相当于socket归master所有 master把socket对应的fd共享给worker
     * 端口不复用下 为80端口创建socket监听在80端口上 把这个socket的fd放在listening数组将来共享给worker进程
	 */
    if (ngx_open_listening_sockets(cycle) != NGX_OK) {
        goto failed;
    }
```

最后master进程把准备好的socket信息存储在cycle的listening数组中，将来大家共享。

```c
    /**
     * nginx监听的套接字端口
     * 这个数组里面端口可能不止一份 什么叫一份 就是配置文件中指定的所有要监听的端口是一份
     * <ul>
     *   <li>系统支持端口重用reuseport就为每个worker进程都复制一份 编上进程索引号 将来worker进程人手一份</li>
     *   <li>系统不支持端口重用 就在listening保存一份 所有worker进程共享 worker进程抢抢锁竞争决定谁监听socket插口连接</li>
     * </ul>
     * 但是不管几份 端口的socket->bind->listen都是在master进程中处理的
     */
    ngx_array_t               listening;
```

### 2 单进程下怎么注册监听连接的

虽然单进程下肯定不存在所谓的惊群，但是为了理解后面worker进程向内核多路复用器注册连接事件监听，有必要先看下在单进程下的注册连接事件的时机。

ngx_process_cycle.c中`ngx_single_process_cycle`方法会回调各模块的`init_process`方法，在ngx_event.c中的函数`ngx_event_process_init`中。

```c
        /*
		 * worker进程注册对端口的连接事件监听注册到多路复用器上 这个时机在worker进程启动后就注册 上面有个判断是不是启用了accept锁 如果没有启动互斥锁 每个进程启动后就开始注册连接事件 这种方式可能会引起accept惊群
		 * 那么执行到这的场景是
		 * <ul>
		 *   <li>单进程</li>
		 *   <li>虽然是master-worker进程模式 但是没有启用accept锁</li>
		 * </ul>
         */
        if (ngx_add_event(rev, NGX_READ_EVENT, 0) == NGX_ERROR) {
            return NGX_ERROR;
        }
```

### 3 多进程下监听连接的时机

#### 3.1 工作进程的初始化

在master进程创建worker进程成功后，每个worker进程会执行到`ngx_worker_process_init`方法里面，在这个方法里面，又会回调模块的初始化，跟上面单进程一样，会执行到事件模块的初始化方法，在ngx_event.c中的函数`ngx_event_process_init`中。只是在多进程下，会标记需要accept锁，并且此时不进行连接事件监听。

##### 3.1.1 事件模块初始化
```c
    if (ccf->master && ccf->worker_processes > 1 && ecf->accept_mutex) {
        /*
         * 多进程模式下开启竞争接收
         * 为什么要对网络连接进行互斥 在多进程下每个worker进程都有自己的循环处理 如果不对连接进行互斥 就意味着同一时刻多个进程同时进行accept操作 结果是只有一个进程能执行accept成功 其他都失败
         * 这就是accept引起了惊群
         * 所以要对accept操作进行上锁
         * 为什么其他读写事件任务不需要加锁呢 因为每个进程有自己的事件循环 accept后会将事件注册在各自的事件循环器 所以将来对应的读写事件也只有自己处理 不存在竞争问题
		 */
        ngx_use_accept_mutex = 1;
		// 这个函数调用时机是在worker进程创建好后 所以此时工作进程初始化占锁标识为0 标识没有抢到accept锁
        ngx_accept_mutex_held = 0;
        ngx_accept_mutex_delay = ecf->accept_mutex_delay;

    } else {
        // 单进程模式下不需要开启竞争接收
        ngx_use_accept_mutex = 0;
    }
```

##### 3.1.2 不注册连接事件

```c
        if (ngx_use_accept_mutex) {
			// 下面的逻辑是向多复用器注册连接事件 如果启用了accept互斥锁就不是每个worker进程启动后就注册连接事件而是把注册动作后置到事件循环中
            continue;
        }
```

#### 3.2 worker进程的事件循环

worker进程初始化好后就开启了事件循环，在`ngx_worker_process_cycle`方法调用`ngx_process_events_and_timers`方法。

### 4 注册监听连接事件

在调用内核获取就绪事件之前，会尝试抢accept锁。

- 如果没有参与抢锁，就不会发生注册连接事件监听的动作
- 如果抢锁失败，就要把自己曾经注册过监听连接的事件全部移除掉

只有抢到锁的worker进程才有资格监听连接。

#### 4.1 抢锁成功注册事件

```c
/*
 * master-worker多进程下抢到锁的worker进程才会执行到这
 * 到cycle的listening中拿没有被监听的socket注册到worker自己的事件循环器上
 */
ngx_int_t
ngx_enable_accept_events(ngx_cycle_t *cycle)
{
    ngx_uint_t         i;
    ngx_listening_t   *ls;
    ngx_connection_t  *c;

    ls = cycle->listening.elts;
    for (i = 0; i < cycle->listening.nelts; i++) {

        c = ls[i].connection;

        if (c == NULL || c->read->active) {
            // 找到候选监听端口没被注册的
            continue;
        }
		// 注册连接事件
        if (ngx_add_event(c->read, NGX_READ_EVENT, 0) == NGX_ERROR) {
            return NGX_ERROR;
        }
    }

    return NGX_OK;
}
```

#### 4.2 抢锁失败移除事件

```c
        /*
         * 从内核多路复用器移除事件的监听
         * <ul>
         *   <li>复用器红黑树上有这个事件才会发生移除<ul>
         *     为什么说明移除事件对真正的连接请求不会有影响 无非就是连接请求的接收比原来有一些滞后 但是这一点时间已经多发生的内核复用器系统调用对于accept惊群 都是小事
         *     <li>虽然注册了连接事件 但是一直没有连接请求进来 那么直接移除 将来别的worker注册连接事件的监听 这是最简单的场景 肯定不会有问题</li>
         *     <li>当前worker注册了连接事件 有连接请求进来 被accept过了 等于是已经发生过的事情 再把连接事件删除 将来别的worker进程注册 这也不会有问题</li>
         *     <li>当前worker注册了连接事件 有连接请求进来 自己还没处理 等于现在情况是连接已经进来在backlog中 事件也被内核放到复用器的ready list上 此时系统调用从复用器红黑树上移除事件 内核会从红黑树和ready list上都移除这个事件 因为实际连接已经到了backlog中 将来别的worker进程注册连接事件后 内核会立马把这个事件放到它的ready list中等着那个worker进程处理</li>
         *     <li></li>
         *   </ul></li>
         *   <li>复用器红黑树没有注册过这个事件 就等于是一次空调用 什么也不会发生</li>
         * </ul>
         */
        if (ngx_del_event(c->read, NGX_READ_EVENT, NGX_DISABLE_EVENT)
            == NGX_ERROR)
        {
            return NGX_ERROR;
        }
```
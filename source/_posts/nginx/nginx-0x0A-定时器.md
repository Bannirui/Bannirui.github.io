---
title: nginx-0x0A-定时器
category_bar: true
date: 2025-04-09 15:50:10
categories: nginx
---

{% post_link nginx/nginx-0x0B-事件模型 %}中定时任务的触发时机就需要定时器，换言之定时器的作用就触发定时任务的执行。

### 1 事件循环

广义上区分系统的事件类型
- 网络事件
- 普通任务

事件循环器的作用就是高效处理网络事件和普通任务
- 如果阻塞式调用复用器，虽然可以及时感知到网络事件就绪，但是可能会错过大量定时任务的期待的执时机
- 因此为了兼顾二者，就要非阻塞式调用系统调用，并且设置超时时间就是最近的一次定时任务执行时间，确保定时任务也可以被及时处理

```c
    /*
     * @param ngx_kqueue kq实例
     * @param tp 系统调用的超时设置 没有事件到达唤醒线程 就阻塞到这个时间后唤醒线程不要一直阻塞
     *           <ul>
     *             <li>有值 超时唤醒</li>
     *             <li>没值 用kq定时器事件 配置kq实例化时注册定时器事件</li>
     *           </ul>
     * @return events 就绪事件数量
     */
    events = kevent(ngx_kqueue, change_list, n, event_list, (int) nevents, tp);
```

### 2 关于定时任务的执行时机

事件循环的主线程
```c
    // 启动事件循环
    for ( ;; ) {
        ngx_log_debug0(NGX_LOG_DEBUG_EVENT, cycle->log, 0, "worker cycle");
        // 每一次事件循环的处理
        ngx_process_events_and_timers(cycle);
    }
```

```c
/**
 * 事件循环的处理
 */
void
ngx_process_events_and_timers(ngx_cycle_t *cycle)
{
       /*
     * <ul>
     *   <li>ngx_process_events是个宏定义</li>
     *   <li>这个宏是接口ngx_event_actions中的方法process_events</li>
     *   <li>至于接口对应的实现是在编译时根据启用的模块进行赋值 kequeue的是ngx_kqueue_module_ctx中的actions</li>
     * </ul>
     * 最终调用到系统的kq 拿到就绪的网络IO事件
     * 能继续执行下去的场景一定是
     * <ul>
     *   <li>虽然没有设置系统调用超时 但是有网络事件就绪</li>
     *   <li>设置了系统调用超时 在超时到期之前就有网络事件就绪</li>
     *   <li>设置了系统调用超时 一直没有网络事件就绪 直到超时到期</li>
     *   <li>在复用器上注册了定时器事件 虽然没有网络事件 但是定时器事件触发了</li>
     * </ul>
     */
    (void) ngx_process_events(cycle, timer, flags);
        // 先处理网络accept连接事件
    ngx_event_process_posted(cycle, &ngx_posted_accept_events);

    if (ngx_accept_mutex_held) {
        ngx_shmtx_unlock(&ngx_accept_mutex);
    }
    /*
     * 处理普通任务 定时任务
     * 执行到这的情况有两种
     * <ul>
     *   <li>系统调用kq指定的超时时间 超时到期了 而这个超时时间就是在系统调用前根据任务队列的到期时间算出来的</li>
     *   <li>系统调用kq没有指定超时时间 让系统调用阻塞执行 但是这种情况会搭配往复用器注册定时器事件来唤醒阻塞线程</li>
     * </ul>
     * 其实不管哪种方式执行到这 都是为了配合系统时间才起作用
     * 执行定时任务的时候的逻辑是拿着任务的过期时间跟当前系统时间比较 到期了就执行
     * 想要获得系统时间就要调用gettimeofday 对于高性能服务器而言 频繁的系统调用是笔很大的开销
     * nginx在性能和定时任务的执行精度做了权衡
     * <ul>
     *   <li>每次都系统调用获取系统时间开销大 时间精确</li>
     *   <li>缓存一个系统时间 每次从内存拿开销小 时间一定会不精准 有滞后</li>
     * </ul>
     * 所以现在的矛盾变成了怎么解决内存上缓存着的时间精度 换言之就是怎么更新缓存的系统时间 所以引申出来的机制就是更新缓存的系统时间的频率就是系统时间的精度
     * 怎么更新系统时间 对应的方式是向复用器注册定时器事件 定时器事件就绪就去更新系统时间
     * 更新系统时间的精度 对应的就是定时器事件的执行间隔 比如设置定时器间隔是100ms 那么每隔100s就会去更新一次缓存的系统时间 也就意味着缓存的系统时间比实时的系统时间滞后最多100ms
     * 意味着当执行定时任务的时候参考的系统时间存在的精度误差导致定时任务的执行精度问题
     * 所以
     * <ul>
     *   <li>如果不在乎定时任务的管理精度 就没必要启用高精度定时器机制</li>
     *   <li>如果需要精细管理定时任务 就可以依赖高精度定时器机制</li>
     * </ul>
     */
    ngx_event_expire_timers();
    // 再处理网络IO的读写事件
    ngx_event_process_posted(cycle, &ngx_posted_events);
}
```

### 3 定时任务要不要执行的判断标准

每个定时任务都维护上超时时间，每触发定时任务的执行时机就扫描一遍定时任务找到超时时间已经过期的，这些任务就是要执行的

```c
/**
 * 处理超时事件
 * 事件循环线程每个处理周期都会在恰当时机被唤醒
 * 在这个唤醒时机 定时任务就获得到一次被执行的机会
 * <ul>
 *   <li>找到过期的定时器从红黑树中移除</li>
 *   <li>根据定时器找到对应的事件 回调事件</li>
 * </ul>
 */
void
ngx_event_expire_timers(void)
{
    // 事件 根据timer定时器的地址倒推出来事件的地址
    ngx_event_t        *ev;
    ngx_rbtree_node_t  *node, *root, *sentinel;

    sentinel = ngx_event_timer_rbtree.sentinel;
    // 轮询检索红黑树把过期的定时器删除
    for ( ;; ) {
        // 红黑树的根
        root = ngx_event_timer_rbtree.root;
        // 到了树的边界 说明找遍了整棵树
        if (root == sentinel) {
            return;
        }
        // 事件队列中最早超时到期的事件
        node = ngx_rbtree_min(root, sentinel);

        /* node->key > ngx_current_msec */
        // 任务定时器队列中最早到期的都还没超时 说明所有的任务都还没超时
        if ((ngx_msec_int_t) (node->key - ngx_current_msec) > 0) {
            return;
        }
        // 已经找到有任务超时过期了 根据事件的定时器找到事件本身
        ev = ngx_rbtree_data(node, ngx_event_t, timer);

        ngx_log_debug2(NGX_LOG_DEBUG_EVENT, ev->log, 0,
                       "event timer del: %d: %M",
                       ngx_event_ident(ev->data), ev->timer.key);
        // 从红黑树中删除过期的定时器
        ngx_rbtree_delete(&ngx_event_timer_rbtree, &ev->timer);

#if (NGX_DEBUG)
        ev->timer.left = NULL;
        ev->timer.right = NULL;
        ev->timer.parent = NULL;
#endif

        ev->timer_set = 0;

        ev->timedout = 1;
        // 回调事件
        ev->handler(ev);
    }
}
```

### 4 关于高精度定时器

可以看到在定时任务的处理中需要依赖系统当前时间来判断定时任务有没有到期，而且系统上还会有很多其他需要使用系统当前时间的地方。可想而知，对于高性能的服务端而言，如果每次需要使用系统当前时间就执行一次系统调用`gettimeofday`，这是一笔不小的开销。自然而然就想到要缓存系统时间，定时去更新就行，可以大大减少系统调用次数。

既然用到缓存就一定存在缓存不一致，谁跟谁不一致呢，当需要使用系统时间的时候，从缓存上拿到的系统时间可能跟彼时真正的系统时间存在误差，误差是多大，误差范围就是[0...缓存更新间隔]，比如，每隔t更新一次缓存系统时间，那么使用的时候拿到的值可能跟系统时间一样，也可能滞后实际时间t。

所以这个时候要解决的矛盾是: 为了系统系能和时间精度，需要设计一种机制能够支持高精度地更新缓存的系统时间---定时器事件登场。

#### 4.1 注册定时器事件
```c
    // 通过向kq注册定时器事件方式实现高精度定时器
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

        ngx_event_flags |= NGX_USE_TIMER_EVENT;
    }
```

#### 4.2 定时器事件就绪
```c
        // 就绪的事件是个定时器事件 借助这个事件更新系统时间 等会函数调用方的主线程要触发定时任务执行 依赖更新过后的系统时间来判断任务是否到期
        if (event_list[i].filter == EVFILT_TIMER) {
            // 更新系统时间
            ngx_time_update();
            continue;
        }
```

#### 4.3 更新缓存时间
```c
    // 更新缓存的系统时间 时间戳格式
    ngx_current_msec = ngx_monotonic_time(sec, msec);
    // 更新缓存的系统时间 结构化格式
    tp = &cached_time[slot];
```

关于nginx缓存系统时间可见{% post_link nginx/nginx-0x0C-系统时间 %}
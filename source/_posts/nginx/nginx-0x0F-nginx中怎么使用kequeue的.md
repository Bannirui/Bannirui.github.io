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



### 3 就绪列表
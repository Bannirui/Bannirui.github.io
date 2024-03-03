---
title: Redis-2刷-0x10-事件循环器AE
date: 2024-01-05 11:02:11
category_bar: true
categories: Redis
tags: 2刷Redis
---

多路复用器应该是整个框架中的核心，在很多网络框架中都是起着一个重要的衔接作用

- 一方面通过库函数的实现提供高效的网络服务

- 另一方面借助回调时机作为锚点整合业务任务

- 形成一个整体的EDA系统

因此框架会对多路复用器进行一次封装，借助系统多路复用器的回调时机王成

- 网络socket的业务处理

- 非socket的业务处理

通过多路复用器推进系统的循环往复的工作，因此一般这样的抽象封装成为事件循环器

1 入口

```c
    /**
     * 创建事件监听器 10_000+128
     */
    server.el = aeCreateEventLoop(server.maxclients+CONFIG_FDSET_INCR);
```

2 事件循环器
---


---
title: Redis-0x18-初始化服务端
date: 2023-04-12 10:55:44
category_bar: true
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

## 1 进程信号处理策略

```c
    /**
     * 忽略SIGHUP信号
     * redis基本上都是以守护进程方式在运行 后台执行的时候不会有控制终端 忽略掉SIGHUP信号
     */
    signal(SIGHUP, SIG_IGN);
    /**
     * 忽略SIGPIPE信号
     * SIGPIPE信号产生
     *   - 在写管道发现读进程终止时产生信号
     *   - 写已终止的SOCKET_STREAM套接字同样产生该信号
     * redis作为server 不可避免会遇到各种各样的client client意外终止导致产生的信号也要忽略掉
     */
    signal(SIGPIPE, SIG_IGN);
    // 特定信号的处理策略
    setupSignalHandlers();
```



```c
/**
 * @brief 指定要关注的几个信号 设置对应的处理器
 */
void setupSignalHandlers(void) {
    struct sigaction act;

    /* When the SA_SIGINFO flag is set in sa_flags then sa_sigaction is used.
     * Otherwise, sa_handler is used. */
    sigemptyset(&act.sa_mask);
    act.sa_flags = 0;
    act.sa_handler = sigShutdownHandler;
    /**
     * SIGTERM是kill命令发送的系统默认终止信号
     * 也就是在试图结束server时会触发的信号
     * 对这类信号 redis并不是立即终止进程 而是做完一些必要的清理工作再退出程序
     */
    sigaction(SIGTERM, &act, NULL);
    sigaction(SIGINT, &act, NULL);

    sigemptyset(&act.sa_mask);
    act.sa_flags = SA_NODEFER | SA_RESETHAND | SA_SIGINFO;
    act.sa_sigaction = sigsegvHandler;
    if(server.crashlog_enabled) {
        /**
         * 下面几个信号是严重的错误 redis通过自定义的handler记录现场 然后执行必要的清理工作 最后再退出程序
         */
        sigaction(SIGSEGV, &act, NULL); // 无效内存引用
        sigaction(SIGBUS, &act, NULL); // 硬件故障
        sigaction(SIGFPE, &act, NULL); // 算数运算错误
        sigaction(SIGILL, &act, NULL); // 执行非法硬件指令
        sigaction(SIGABRT, &act, NULL);
    }
    return;
}
```

## 2 日志设施

```c
// 日志设施
if (server.syslog_enabled) {
    openlog(server.syslog_ident, LOG_PID | LOG_NDELAY | LOG_NOWAIT,
            server.syslog_facility);
}
```

## 3 redisServer实例字段赋值

```c
    /* Initialization after setting defaults from the config system. */
    server.aof_state = server.aof_enabled ? AOF_ON : AOF_OFF;
    server.hz = server.config_hz;
    server.pid = getpid(); // 记录进程号
    server.in_fork_child = CHILD_TYPE_NONE;
    server.main_thread_id = pthread_self(); // 记录线程id
    server.current_client = NULL; // 服务端当前处理的client
    server.errors = raxNew();
    server.fixed_time_expire = 0;
    server.clients = listCreate(); // 初始化空链表
    server.clients_index = raxNew();
    server.clients_to_close = listCreate();
    server.slaves = listCreate(); // 初始化空链表
    server.monitors = listCreate(); // 初始化空链表
    server.clients_pending_write = listCreate();
    server.clients_pending_read = listCreate();
    server.clients_timeout_table = raxNew();
    server.replication_allowed = 1;
    server.slaveseldb = -1; /* Force to emit the first SELECT command. */
    server.unblocked_clients = listCreate(); // 初始化空链表
    server.ready_keys = listCreate();
    server.clients_waiting_acks = listCreate();
    server.get_ack_from_slaves = 0;
    server.client_pause_type = 0;
    server.paused_clients = listCreate();
    server.events_processed_while_blocked = 0;
    server.system_memory_size = zmalloc_get_memory_size();
    server.blocked_last_cron = 0;
    server.blocking_op_nesting = 0;
```

## 4 创建共享对象

```c
// 共享对象 相当于单例缓存池
createSharedObjects();
```


```c
// 创建事件监听器
server.el = aeCreateEventLoop(server.maxclients+CONFIG_FDSET_INCR);
```

## 6 数据库db内存分配

```c
// 数据库分配内存 默认配置16个数据库
server.db = zmalloc(sizeof(redisDb)*server.dbnum);
```

## 7 socket创建监听

```c
    /**
     * 创建监听端口的socket
     *   - 服务端口6379
     *   - ssl端口
     *   - UNIX_STREAM
     */
    /* Open the TCP listening socket for the user commands. */
    // 创建socket监听在服务端口 端口号默认为6379
    if (server.port != 0 &&
        listenToPort(server.port,&server.ipfd) == C_ERR) {
        serverLog(LL_WARNING, "Failed listening on port %u (TCP), aborting.", server.port);
        exit(1);
    }
    // 创建socket监听在tls端口 端口号默认为0
    if (server.tls_port != 0 &&
        listenToPort(server.tls_port,&server.tlsfd) == C_ERR) {
        serverLog(LL_WARNING, "Failed listening on port %u (TLS), aborting.", server.tls_port);
        exit(1);
    }

    /* Open the listening Unix domain socket. */
    if (server.unixsocket != NULL) {
        unlink(server.unixsocket); /* don't care if this fails */
        server.sofd = anetUnixServer(server.neterr,server.unixsocket,
            server.unixsocketperm, server.tcp_backlog);
        if (server.sofd == ANET_ERR) {
            serverLog(LL_WARNING, "Opening Unix socket: %s", server.neterr);
            exit(1);
        }
        anetNonBlock(NULL,server.sofd);
        anetCloexec(server.sofd);
    }

    /* Abort if there are no listening sockets at all. */
    // 校验socket的初始化是否成功
    if (server.ipfd.count == 0 && server.tlsfd.count == 0 && server.sofd < 0) {
        serverLog(LL_WARNING, "Configured to not listen anywhere, exiting.");
        exit(1);
    }
```

## 8 初始化数据库

```c
// 初始化数据库 默认16个库
for (j = 0; j < server.dbnum; j++) {
    server.db[j].dict = dictCreate(&dbDictType,NULL);
    server.db[j].expires = dictCreate(&dbExpiresDictType,NULL);
    server.db[j].expires_cursor = 0;
    server.db[j].blocking_keys = dictCreate(&keylistDictType,NULL);
    server.db[j].ready_keys = dictCreate(&objectKeyPointerValueDictType,NULL);
    server.db[j].watched_keys = dictCreate(&keylistDictType,NULL);
    server.db[j].id = j;
    server.db[j].avg_ttl = 0;
    server.db[j].defrag_later = listCreate();
    listSetFreeMethod(server.db[j].defrag_later,(void (*)(void*))sdsfree);
}
```

## 9 {% post_link Redis-0x1c-serverCron任务 注册serverCron函数 %}

```c
    /**
     * 创建一个时间事件注册到事件管理器eventLoop上
     * 由eventLoop来管理调度事件
     *   - 期待该事件在1ms后被eventLoop事件管理器调度起来
     *   - 具体的执行逻辑定义在serverCron中
     *     - 这个serverCron是周期性任务 每隔100ms执行一次
     */
    if (aeCreateTimeEvent(server.el, 1, serverCron, NULL, NULL) == AE_ERR) {
        serverPanic("Can't create event loop timers.");
        exit(1);
    }
```

## 10 {% post_link Redis-0x1d-acceptTcpHandler处理连接请求 监听在端口上的socket加到监控列表 %}

```c
    /**
     * 将监听端口的Socket的fd加入到事件监控列表
     *   - 服务端口
     *   - ssl端口
     *   - unix端口
     */
    if (createSocketAcceptHandler(&server.ipfd, acceptTcpHandler) != C_OK) {
        serverPanic("Unrecoverable error creating TCP socket accept handler.");
    }
    if (createSocketAcceptHandler(&server.tlsfd, acceptTLSHandler) != C_OK) {
        serverPanic("Unrecoverable error creating TLS socket accept handler.");
    }
    if (server.sofd > 0 && aeCreateFileEvent(server.el,server.sofd,AE_READABLE,
        acceptUnixHandler,NULL) == AE_ERR) serverPanic("Unrecoverable error creating server.sofd file event.");
```

## 11 打开aof文件

```c
if (server.aof_state == AOF_ON) { // 开启了aof
    // 打开aof文件
    server.aof_fd = open(server.aof_filename,
                         O_WRONLY|O_APPEND|O_CREAT,0644);
    if (server.aof_fd == -1) {
        serverLog(LL_WARNING, "Can't open the append-only file: %s",
                  strerror(errno));
        exit(1);
    }
}
```

## 12 慢日志初始化

```c
// 慢日志初始化
slowlogInit();
```


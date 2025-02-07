---
title: Redis-0x1D-网络通信connection
category_bar: true
date: 2024-06-17 14:10:24
categories: Redis
---

网络通信的底层是套接字的使用，根据网络类型可以分为
- 网络套接字
- 表示本地(Unix域)套接字

虽然redis已经对系统的套接字api进行了一次封装{% post_link Redis/Redis-0x10-socket编程 %}，但是直接操作socket还是偏低层，因此在此基础上，封装出connection给业务模块使用

### 1 网络连接的接口定义

```c
/**
 * 接口 定义了网络连接读写操作
 * 实现有2个
 * <ul>
 *   <li>connection.c::CT_Socket unix本地socket也被归于CT_Socket了</li>
 *   <li>tls.c::CT_TLS</li>
 * </ul>
 */
typedef struct ConnectionType {
    void (*ae_handler)(struct aeEventLoop *el, int fd, void *clientData, int mask);
    int (*connect)(struct connection *conn, const char *addr, int port, const char *source_addr, ConnectionCallbackFunc connect_handler);
    int (*write)(struct connection *conn, const void *data, size_t data_len);
    int (*read)(struct connection *conn, void *buf, size_t buf_len);
    void (*close)(struct connection *conn);
    int (*accept)(struct connection *conn, ConnectionCallbackFunc accept_handler);
    int (*set_write_handler)(struct connection *conn, ConnectionCallbackFunc handler, int barrier);
    int (*set_read_handler)(struct connection *conn, ConnectionCallbackFunc handler);
    const char *(*get_last_error)(struct connection *conn);
    int (*blocking_connect)(struct connection *conn, const char *addr, int port, long long timeout);
    ssize_t (*sync_write)(struct connection *conn, char *ptr, ssize_t size, long long timeout);
    ssize_t (*sync_read)(struct connection *conn, char *ptr, ssize_t size, long long timeout);
    ssize_t (*sync_readline)(struct connection *conn, char *ptr, ssize_t size, long long timeout);
    int (*get_type)(struct connection *conn);
} ConnectionType;
```

### 2 接口实现

根据加密需求对接口提供了两种实现
- TCP的CT_Socket 基于unix socket的连接也是归于这种
- TLS TCP的CT_TLS

#### 2.1 CT_Socket
```c
/**
 * 对应TCP连接 包括使用了TCP连接也包括使用unix本地socket的连接
 */
ConnectionType CT_Socket = {
    .ae_handler = connSocketEventHandler, // 这个是核心 将来IO多路复用器阻塞调用出来的就绪socket 被eventLoop回调函数就是这个 它起到了分派器的作用
    .close = connSocketClose,
    .write = connSocketWrite,
    .read = connSocketRead,
    .accept = connSocketAccept,
    .connect = connSocketConnect,
    .set_write_handler = connSocketSetWriteHandler,
    .set_read_handler = connSocketSetReadHandler,
    .get_last_error = connSocketGetLastError,
    .blocking_connect = connSocketBlockingConnect,
    .sync_write = connSocketSyncWrite,
    .sync_read = connSocketSyncRead,
    .sync_readline = connSocketSyncReadLine,
    .get_type = connSocketGetType
};
```

#### 2.2 CT_Socket
```c
// 对应使用了TLS的TCP
ConnectionType CT_TLS = {
    .ae_handler = tlsEventHandler,
    .accept = connTLSAccept,
    .connect = connTLSConnect,
    .blocking_connect = connTLSBlockingConnect,
    .read = connTLSRead,
    .write = connTLSWrite,
    .close = connTLSClose,
    .set_write_handler = connTLSSetWriteHandler,
    .set_read_handler = connTLSSetReadHandler,
    .get_last_error = connTLSGetLastError,
    .sync_write = connTLSSyncWrite,
    .sync_read = connTLSSyncRead,
    .sync_readline = connTLSSyncReadLine,
    .get_type = connTLSGetType
};
```

### 3 通信流程
#### 3.1 服务端等待客户端连接

服务端知名端口6379等待客户端连接请求过来，当有客户端连接请求过来到服务端时触发回调acceptTcpHandler

```c
    /**
     * 将监听端口的Socket的fd加入到事件监控列表
     *   - 服务端口6379
     *   - ssl端口
     *   - unix端口
     * 通过IO多路复用器关注服务端socket上的可读事件 也就是客户端发过来的连接请求
     * 至于服务端如何处理收到的连接请求 将来由eventLoop事件管理器负责回调此时指定的处理器
     *   - acceptTcpHandler
     *   - acceptTLSHandler
     *   - acceptUnixHandler
     */
    if (createSocketAcceptHandler(&server.ipfd, acceptTcpHandler) != C_OK) {
        serverPanic("Unrecoverable error creating TCP socket accept handler.");
    }
```

#### 3.2 客户端连接请求

当服务端收到客户端连接请求时，服务端调用`accept`系统调用fork出来新的socket，并封装成connection等待接收客户端发送的数据

```c
/**
 * @brief 定义了当服务端收到了客户度发来的连接请求后 如何处理这条连接请求
 * @param el eventLoop事件管理器 将来就是它从IO多路复用器中被唤醒 拿着就绪的fd来执行回调
 * @param fd 标识的是服务端socket 该server socket收到了连接请求
 * @param privdata 私有数据 也就是acceptTcpHandler函数执行需要的数据
 *                 redis是这样设计的
 *                   - 这个函数的执行时机是IO多路复用器发现某个服务端socket有可读事件就绪
 *                   - eventLoop判定这个可读事件就是别的客户端发来的连接请求 因为这个socket是服务端socket 是被动socket 它的可读只能是收到了连接请求
 *                   - eventLoop才是acceptTcpHandler这个函数执行者 这个函数执行的时候可能有依赖数据 eventLoop是没有这个入口数据的
 *                   - 所以在向eventLoop注册文件事件的时候就将未来执行回调需要的数据定义好 一并给eventLoop
 * @param mask fd是可读还是可写
 */
void acceptTcpHandler(aeEventLoop *el, int fd, void *privdata, int mask) {
    int cport, cfd, max = MAX_ACCEPTS_PER_CALL;
    // 客户端socket的ip
    char cip[NET_IP_STR_LEN];
    UNUSED(el);
    UNUSED(mask);
    UNUSED(privdata);

    /**
     * 为啥子上来一个for循环呢
     * 这个应该仅仅是一点微小的cpu损耗换系统性能的策略
     * 当前函数执行时机是什么呢 是fd这个服务端socket收到了来自客户端的连接请求 现在要处理连接请求
     * 但是有多少个连接请求呢
     * 这可不好说 可能很多 可能就只有1个
     * 因此直接先来个尝试性n次轮询
     *   - 即使实际上只有1个连接请求 对于系统而言 也就仅仅占用了一点点cpu时间片而已
     *   - 如果实际上收到了很多连接请求 对于系统而言 提高的吞吐是显著的
     */
    while(max--) {
        // 通过系统调用accept创建socket 将来和客户端的通信就全依赖这个socket了
        cfd = anetTcpAccept(server.neterr, fd, cip, sizeof(cip), &cport);
        if (cfd == ANET_ERR) {
            if (errno != EWOULDBLOCK)
                serverLog(LL_WARNING,
                    "Accepting client connection: %s", server.neterr);
            return;
        }
        anetCloexec(cfd);
        serverLog(LL_VERBOSE,"Accepted %s:%d", cip, cport);
        /**
         * OS层面而言 此时cfd就已经标识服务端和客户端连接已经建立完成
         * 但是对于redis而言 还不够
         *   - 还要将fork出来的socket注册到eventLoop上
         *   - 要定义这个socket读写事件的回调处理器
         */
        acceptCommonHandler(connCreateAcceptedSocket(cfd),0,cip);
    }
}
```

核心流程是acceptCommonHandler->createClient->connSetReadHandler，完成在逻辑层面的客户端/服务端连接，此时服务端就等待客户端的请求数据，进行对应的指令处理，即createClient中调用connSetReadHandler时指定的回调函数

```c
        /**
         * 这一步很重要
         *   - 完成了对eventLoop的注册
         *     - socket信息登记到eventLoop中
         *     - 向IO多路复用器注册告知对socket的读事件感兴趣
         *     - IO事件就绪后回调事件分派器connSocketEventHandler
         *   - 在connection中保存了读事件处理器readQueryFromClient
         *     - socket读事件就绪后connSocketEventHandler分派器被eventLoop回调
         *     - 分派器将读事件派发给readQueryFromClient处理器来执行
         */
        connSetReadHandler(conn, readQueryFromClient);
```

#### 3.3 服务端接收客户端请求指令进行处理

```c
/**
 * 可读时触发回调的真正处理逻辑 也就是说此时客户端有请求命令到服务端 当前函数就是命令处理器
 * @parm 服务端accept出来的socket
 */
void readQueryFromClient(connection *conn) {
    // 客户端 也就是通信双方的client和server
    client *c = connGetPrivateData(conn);
    int nread, readlen;
    size_t qblen;

    /* Check if we want to read from the client later when exiting from
     * the event loop. This is the case if threaded I/O is enabled. */
    if (postponeClientRead(c)) return;

    /* Update total number of reads on server */
    atomicIncr(server.stat_total_reads_processed, 1);

    readlen = PROTO_IOBUF_LEN;
    /* If this is a multi bulk request, and we are processing a bulk reply
     * that is large enough, try to maximize the probability that the query
     * buffer contains exactly the SDS string representing the object, even
     * at the risk of requiring more read(2) calls. This way the function
     * processMultiBulkBuffer() can avoid copying buffers to create the
     * Redis Object representing the argument. */
    if (c->reqtype == PROTO_REQ_MULTIBULK && c->multibulklen && c->bulklen != -1
        && c->bulklen >= PROTO_MBULK_BIG_ARG)
    {
        ssize_t remaining = (size_t)(c->bulklen+2)-sdslen(c->querybuf);

        /* Note that the 'remaining' variable may be zero in some edge case,
         * for example once we resume a blocked client after CLIENT PAUSE. */
        if (remaining > 0 && remaining < readlen) readlen = remaining;
    }

    qblen = sdslen(c->querybuf);
    if (c->querybuf_peak < qblen) c->querybuf_peak = qblen;
    c->querybuf = sdsMakeRoomFor(c->querybuf, readlen);
    nread = connRead(c->conn, c->querybuf+qblen, readlen);
    if (nread == -1) {
        if (connGetState(conn) == CONN_STATE_CONNECTED) {
            return;
        } else {
            serverLog(LL_VERBOSE, "Reading from client: %s",connGetLastError(c->conn));
            freeClientAsync(c);
            return;
        }
    } else if (nread == 0) {
        serverLog(LL_VERBOSE, "Client closed connection");
        freeClientAsync(c);
        return;
    } else if (c->flags & CLIENT_MASTER) {
        /* Append the query buffer to the pending (not applied) buffer
         * of the master. We'll use this buffer later in order to have a
         * copy of the string applied by the last command executed. */
        c->pending_querybuf = sdscatlen(c->pending_querybuf,
                                        c->querybuf+qblen,nread);
    }

    sdsIncrLen(c->querybuf,nread);
    c->lastinteraction = server.unixtime;
    if (c->flags & CLIENT_MASTER) c->read_reploff += nread;
    atomicIncr(server.stat_net_input_bytes, nread);
    if (sdslen(c->querybuf) > server.client_max_querybuf_len) {
        sds ci = catClientInfoString(sdsempty(),c), bytes = sdsempty();

        bytes = sdscatrepr(bytes,c->querybuf,64);
        serverLog(LL_WARNING,"Closing client that reached max query buffer length: %s (qbuf initial bytes: %s)", ci, bytes);
        sdsfree(ci);
        sdsfree(bytes);
        freeClientAsync(c);
        return;
    }

    /* There is more data in the client input buffer, continue parsing it
     * in case to check if there is a full command to execute. */
     processInputBuffer(c);
}
```
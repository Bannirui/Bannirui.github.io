---
title: Redis-0x1d-acceptTcpHandler处理连接请求
date: 2023-04-14 10:25:31
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

## 1 服务端被动socket注册eventLoop

```c
/**
 * @brief 服务端被动式socket添加到事件管理器 委托事件管理器注册到IO多路复用器上
 *        当有客户端向客户端发起连接时
 *        该服务端socket被IO复用器选中 触发的事件为可读
 *        事件管理器eventLoop回调指定的处理器 由处理器实现连接请求的处理
 * @param sfd 服务端被动socket
 * @param accept_handler 负责处理客户端发起的连接请求
 * @return 
 */
int createSocketAcceptHandler(socketFds *sfd, aeFileProc *accept_handler) {
    int j;

    for (j = 0; j < sfd->count; j++) {
        /**
         * 将服务端socket注册到事件管理器eventLoop上
         * eventLoop将socket注册到系统的IO多路复用器上
         *   - 关注该socket的可读事件 将来某个时机客户端发来的连接请求 从服务端视角来看就是serverSocket可读
         * 指定回调处理器accept_handler
         *   - 将来serverSocket可读时 eventLoop会从带超时的IO复用器系统调用上跳出阻塞点
         *   - eventLoop回调accept_handler来处理客户端的tcp连接请求
         */
        if (aeCreateFileEvent(server.el, sfd->fd[j], AE_READABLE, accept_handler,NULL) == AE_ERR) {
            /* Rollback */
            for (j = j-1; j >= 0; j--) aeDeleteFileEvent(server.el, sfd->fd[j], AE_READABLE);
            return C_ERR;
        }
    }
    return C_OK;
}
```

## 2 TCP连接请求如何处理

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

## 3 redis软件层面的建立连接

```c
/**
 * @brief 此时对于OS而言 端到端的TCP连接已经建立好 Socket完全已经可以通信了
 *        redis开始建立redis软件层面的连接
 *          - 设置socket非阻塞式编程
 *          - 完成了对eventLoop的注册
 *            - socket信息登记到eventLoop
 *            - 向IO多路复用器注册告知对socket的读事件感兴趣
 *            - IO事件就绪后回调事件分派器connSocketEventHandler
 *          - 在connection中保存了读事件处理器readQueryFromClient
 *            - socket读事件就绪后connSocketEventHandler分派器被eventLoop回调
 *            - 分派器将读事件派发给readQueryFromClient处理器来执行
 *          - 完成redis层面的连接建立状态 在connection的state中维护CONNECTED标识
 * @param conn 对于socket的封装
 *               - 对于服务端
 *                 - server socket收到连接后通过accept系统调用fork出来的socket
 *                 - state是CONN_STATE_ACCEPTING
 *                 - type是CT_Socket
 * @param flags 0
 * @param ip 客户端socket的ip
 */
static void acceptCommonHandler(connection *conn, int flags, char *ip) {
    client *c;
    char conninfo[100];
    UNUSED(ip);
    // 状态校验 服务端accept系统调用完记录的是CONN_STATE_ACCEPTING
    if (connGetState(conn) != CONN_STATE_ACCEPTING) {
        serverLog(LL_VERBOSE,
            "Accepted client connection in error state: %s (conn: %s)",
            connGetLastError(conn),
            connGetInfo(conn, conninfo, sizeof(conninfo)));
        connClose(conn);
        return;
    }

    /* Limit the number of connections we take at the same time.
     *
     * Admission control will happen before a client is created and connAccept()
     * called, because we don't want to even start transport-level negotiation
     * if rejected. */
    if (listLength(server.clients) + getClusterConnectionsCount()
        >= server.maxclients)
    { // 超过了redis预设的系统处理阈值
        char *err;
        if (server.cluster_enabled)
            err = "-ERR max number of clients + cluster "
                  "connections reached\r\n";
        else
            err = "-ERR max number of clients reached\r\n";

        /* That's a best effort error message, don't check write errors.
         * Note that for TLS connections, no handshake was done yet so nothing
         * is written and the connection will just drop. */
        if (connWrite(conn,err,strlen(err)) == -1) {
            /* Nothing to do, Just to avoid the warning... */
        }
        server.stat_rejected_conn++;
        connClose(conn);
        return;
    }

    /* Create connection and client */
    /**
     * - 设置socket非阻塞式编程
     * - 完成了对eventLoop的注册
     *   - socket信息登记到eventLoop
     *   - 向IO多路复用器注册告知对socket的读事件感兴趣
     *   - IO事件就绪后回调事件分派器connSocketEventHandler
     * - 在connection中保存了读事件处理器readQueryFromClient
     *   - socket读事件就绪后connSocketEventHandler分派器被eventLoop回调
     *   - 分派器将读事件派发给readQueryFromClient处理器来执行
     *
     * 值得注意的是此时connection的state还是ACCEPTING
     */
    if ((c = createClient(conn)) == NULL) {
        serverLog(LL_WARNING,
            "Error registering fd event for the new client: %s (conn: %s)",
            connGetLastError(conn),
            connGetInfo(conn, conninfo, sizeof(conninfo)));
        connClose(conn); /* May be already closed, just ignore errors */
        return;
    }

    /* Last chance to keep flags */
    c->flags |= flags;

    /* Initiate accept.
     *
     * Note that connAccept() is free to do two things here:
     * 1. Call clientAcceptHandler() immediately;
     * 2. Schedule a future call to clientAcceptHandler().
     *
     * Because of that, we must do nothing else afterwards.
     */
    /**
     * 该函数将connection的state从ACCEPTING更新为CONNECTED
     *
     * 这个地方就已经体现了单线程带来的收益了
     *   - 首先这个state一方面可以作为判定客户端\服务端双方通信是否建立好 这个建立是在redis层面的衡量而不是OS层面
     *   - 其次state应该作为IO读写的前提条件 也就是说实际的读写操作应该后置于连接已经完全建立好
     *     - 但是在redis中不需要考虑这个前提条件 比如派发器中connSocketSetReadHandler读取数据之前并不校验connection的state一定得是CONNECTED
     *     - 为啥呢 因为维护socket在redis里面的连接信息connection这件事情和IO读写这件事情都是main线程在做
     *     - 而这件事情一定是先建立连接 然后才有机会读取到客户端发过来的数据
     *       - 因为整体流程必须得是main线程从服务端被动socket上accept了一个socket
     *       - 然后拿着这个socket封装connection信息
     *       - 注册到eventLoop上
     *       - 封装成client信息
     *     - 在socket注册完IO复用器之后main一直在忙着其他事情 根本还没机会执行到IO多路复用器的系统调用
     *     - 也就是说即使这个时候客户端有数据发送过来 这些数据也仅仅是缓存在OS的Socket的recv queue里面
     */
    if (connAccept(conn, clientAcceptHandler) == C_ERR) {
        char conninfo[100];
        if (connGetState(conn) == CONN_STATE_ERROR)
            serverLog(LL_WARNING,
                    "Error accepting a client connection: %s (conn: %s)",
                    connGetLastError(conn), connGetInfo(conn, conninfo, sizeof(conninfo)));
        freeClient(connGetPrivateData(conn));
        return;
    }
}
```

### 3.1 connection封装redis层面的socket信息

```c
/**
 * 对socket的封装
 * 对于服务端而言
 *   - 被动socket接收到连接请求后 通过accept系统调用创建了socket
 *   - 对于OS而言accept系统调用之后就已经建立好了连接
 *   - 到那时对于redis而言还不够 因此在将connection流转处理过程中通过state标识状态
 */
struct connection {
    /**
     * 在指定注册eventLoop事件管理器之前
     * 要先指定读写事件处理器回调函数 到时候要用到这个type
     *   - 对于服务端 实例话connection时候指定type是CT_Socket
     *   - 对于客户端
     */
    ConnectionType *type;
    // redis定义的连接状态
    ConnectionState state;
    short int flags;
    short int refs;
    int last_errno;
    void *private_data;
    ConnectionCallbackFunc conn_handler;
    ConnectionCallbackFunc write_handler;
    ConnectionCallbackFunc read_handler;
    /**
     * socket的fd
     *   - 服务端是被动socket收到连接请求后通过accept系统调用fork出来的socket
     *   - 客户端是主动式socket系统调用创建的socket
     */
    int fd;
};
```



```c
/**
 * @brief 初始化连接状态为ACCEPTING 标识刚完成OS的accept系统调用而已
 * @param fd
 * @return connection实例
 */
connection *connCreateAcceptedSocket(int fd) {
    connection *conn = connCreateSocket();
    conn->fd = fd;
    conn->state = CONN_STATE_ACCEPTING;
    return conn;
}
```

### 3.2 client封装redis层面的socket信息

```c
/**
 * @brief 将connection信息封装成client实例
 *        在这中间针对socket做的重要操作
 *          - 设置socket非阻塞式编程
 *          - 完成了对eventLoop的注册
 *            - socket信息登记到eventLoop
 *            - 向IO多路复用器注册告知对socket的读事件感兴趣
 *            - IO事件就绪后回调事件分派器connSocketEventHandler
 *          - 在connection中保存了读事件处理器readQueryFromClient
 *            - socket读事件就绪后connSocketEventHandler分派器被eventLoop回调
 *            - 分派器将读事件派发给readQueryFromClient处理器来执行
 * @param conn connection实例
 *               - 对于服务端
 *                 - fd记录着socket
 *                 - type为CT_Socket
 *                 - state为ACCEPTING
 * @return client实例
 */
client *createClient(connection *conn) {
    client *c = zmalloc(sizeof(client));

    /* passing NULL as conn it is possible to create a non connected client.
     * This is useful since all the commands needs to be executed
     * in the context of a client. When commands are executed in other
     * contexts (for instance a Lua script) we need a non connected client. */
    if (conn) {
        // 设置socket非阻塞
        connNonBlock(conn);
        // 禁用Nagle算法
        connEnableTcpNoDelay(conn);
        if (server.tcpkeepalive)
            connKeepAlive(conn,server.tcpkeepalive);
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
        connSetPrivateData(conn, c);
    }

    selectDb(c,0);
    uint64_t client_id;
    atomicGetIncr(server.next_client_id, client_id, 1);
    c->id = client_id;
    c->resp = 2;
    c->conn = conn;
    c->name = NULL;
    c->bufpos = 0;
    c->qb_pos = 0;
    c->querybuf = sdsempty();
    c->pending_querybuf = sdsempty();
    c->querybuf_peak = 0;
    c->reqtype = 0;
    c->argc = 0;
    c->argv = NULL;
    c->argv_len_sum = 0;
    c->original_argc = 0;
    c->original_argv = NULL;
    c->cmd = c->lastcmd = NULL;
    c->multibulklen = 0;
    c->bulklen = -1;
    c->sentlen = 0;
    c->flags = 0;
    c->ctime = c->lastinteraction = server.unixtime;
    clientSetDefaultAuth(c);
    c->replstate = REPL_STATE_NONE;
    c->repl_put_online_on_ack = 0;
    c->reploff = 0;
    c->read_reploff = 0;
    c->repl_ack_off = 0;
    c->repl_ack_time = 0;
    c->repl_last_partial_write = 0;
    c->slave_listening_port = 0;
    c->slave_addr = NULL;
    c->slave_capa = SLAVE_CAPA_NONE;
    c->reply = listCreate();
    c->reply_bytes = 0;
    c->obuf_soft_limit_reached_time = 0;
    listSetFreeMethod(c->reply,freeClientReplyValue);
    listSetDupMethod(c->reply,dupClientReplyValue);
    c->btype = BLOCKED_NONE;
    c->bpop.timeout = 0;
    c->bpop.keys = dictCreate(&objectKeyHeapPointerValueDictType,NULL);
    c->bpop.target = NULL;
    c->bpop.xread_group = NULL;
    c->bpop.xread_consumer = NULL;
    c->bpop.xread_group_noack = 0;
    c->bpop.numreplicas = 0;
    c->bpop.reploffset = 0;
    c->woff = 0;
    c->watched_keys = listCreate();
    c->pubsub_channels = dictCreate(&objectKeyPointerValueDictType,NULL);
    c->pubsub_patterns = listCreate();
    c->peerid = NULL;
    c->sockname = NULL;
    c->client_list_node = NULL;
    c->paused_list_node = NULL;
    c->client_tracking_redirection = 0;
    c->client_tracking_prefixes = NULL;
    c->client_cron_last_memory_usage = 0;
    c->client_cron_last_memory_type = CLIENT_TYPE_NORMAL;
    c->auth_callback = NULL;
    c->auth_callback_privdata = NULL;
    c->auth_module = NULL;
    listSetFreeMethod(c->pubsub_patterns,decrRefCountVoid);
    listSetMatchMethod(c->pubsub_patterns,listMatchObjects);
    if (conn) linkClient(c);
    initClientMultiState(c);
    return c;
}
```

## 4 指定socket的IO读写事件回调和分派回调

```c
/**
 * @brief 借助CT_Socket注册读回调处理器func给分派器connSocketEventHandler
 *        connSocketEventHandler将读事件分派给func执行
 * @param conn 在初始化connection实例的时候对type赋值CT_Socket 通过它完成对回调函数的指定
 * @param func 读事件的回调
 * @return
 */
static inline int connSetReadHandler(connection *conn, ConnectionCallbackFunc func) {
    return conn->type->set_read_handler(conn, func);
}
```



```c
/**
 * @brief 借助CT_Socket
 *          - 注册分派器connSocketEventHandler给eventLoop
 *          - 注册读回调处理器func给分派器connSocketEventHandler
 *            - 将来connSocketEventHandler将读事件分派给func执行
 * @param conn 在初始化connection实例的时候对type赋值CT_Socket 通过它完成对回调函数的指定
 * @param func 读事件的回调
 * @return
 */
static inline int connSetReadHandler(connection *conn, ConnectionCallbackFunc func) {
    /**
     * connSocketSetReadHandler的执行触发了真正的socket注册eventLoop
     *   - 向eventLoop登记了要注册的socket
     *   - 向IO多路复用器注册socket
     *     - 关注socket
     *     - 关注读事件
     *   - 回调函数是分派器connSocketEventHandler
     */
    return conn->type->set_read_handler(conn, func);
}
```

### 4.1 eventLoop注册

connSocketSetReadHandler的执行。

```c
/**
 * @brief 注册eventLoop事件管理器
 *          - 注册到IO多路复用器上
 *          - 指定发生可读事件时候的回调处理器connSocketEventHandler
 *            - 它就是个分派器
 *            - 读写真正怎么处理由connSocketEventHandler进行指派
 * @param conn connection实例 里面
 * @param func 回调处理器
 * @return
 */
static int connSocketSetReadHandler(connection *conn, ConnectionCallbackFunc func) {
    if (func == conn->read_handler) return C_OK;

    /**
     * 将读事件处理器的回调放在了connection中
     * 将来socket有IO事件就绪
     *   - eventLoop回调connSocketEventHandler
     *   - connSocketEventHandler发现读事件 就分派给func这个处理器执行
     */
    conn->read_handler = func;
    if (!conn->read_handler)
        aeDeleteFileEvent(server.el,conn->fd,AE_READABLE);
    else
        if (aeCreateFileEvent(server.el,conn->fd,
                    AE_READABLE,conn->type->ae_handler,conn) == AE_ERR) return C_ERR; // 对读感兴趣 回调处理器是connSocketEventHandler
    return C_OK;
}
```

### 4.2 读请求分派给readQueryFromClient

```c
/**
 * @brief IO分派器
 *        socket就绪后 eventLoop回调的就是这个函数
 *        至于读写具体执行逻辑 由这个函数进行分派
 * @param el
 * @param fd
 * @param clientData
 * @param mask
 */
static void connSocketEventHandler(struct aeEventLoop *el, int fd, void *clientData, int mask)
{
    UNUSED(el);
    UNUSED(fd);
    connection *conn = clientData;

    if (conn->state == CONN_STATE_CONNECTING &&
            (mask & AE_WRITABLE) && conn->conn_handler) {

        int conn_error = connGetSocketError(conn);
        if (conn_error) {
            conn->last_errno = conn_error;
            conn->state = CONN_STATE_ERROR;
        } else {
            conn->state = CONN_STATE_CONNECTED;
        }

        if (!conn->write_handler) aeDeleteFileEvent(server.el,conn->fd,AE_WRITABLE);

        if (!callHandler(conn, conn->conn_handler)) return;
        conn->conn_handler = NULL;
    }

    /* Normally we execute the readable event first, and the writable
     * event later. This is useful as sometimes we may be able
     * to serve the reply of a query immediately after processing the
     * query.
     *
     * However if WRITE_BARRIER is set in the mask, our application is
     * asking us to do the reverse: never fire the writable event
     * after the readable. In such a case, we invert the calls.
     * This is useful when, for instance, we want to do things
     * in the beforeSleep() hook, like fsync'ing a file to disk,
     * before replying to a client. */
    int invert = conn->flags & CONN_FLAG_WRITE_BARRIER;

    int call_write = (mask & AE_WRITABLE) && conn->write_handler;
    int call_read = (mask & AE_READABLE) && conn->read_handler;

    /* Handle normal I/O flows */
    if (!invert && call_read) {
        if (!callHandler(conn, conn->read_handler)) return; // 回调readQueryFromClient
    }
    /* Fire the writable event. */
    if (call_write) {
        if (!callHandler(conn, conn->write_handler)) return;
    }
    /* If we have to invert the call, fire the readable event now
     * after the writable one. */
    if (invert && call_read) {
        if (!callHandler(conn, conn->read_handler)) return;
    }
}
```

### 4.3 readQueryFromClient执行

```c
void readQueryFromClient(connection *conn) {
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

## 5 CT_Socket

```c
/**
 * 初始化connection赋值给了type字段
 * 在将socket注册eventLoop时依赖的就是这个
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




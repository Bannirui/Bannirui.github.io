---
title: Netty源码-09-ServerBootstrapAcceptor
date: 2023-03-06 21:48:21
tags:
- Netty@4.1.169
categories:
- Netty源码
---

在ServerBootstrapAcceptor启用之前，此刻Reactor状态应该是：

* NioServerSocketChannel在IO多路复用器上关注着Accept(16)事件
* pipeline中有4个handler
  * head
  * bossHandler
  * ServerBootstrapAcceptor
  * tail
* NioEventLoop已经启动 阻塞在复用器的select上 等待有客户端连接进来

## 一 客户端连接唤醒IO阻塞线程

```java
// NioEventLoop.java
/**
             * 读事件和连接事件
             * 如果当前NioEventLoop是worker线程 这里就是op_read事件
             * 如果当前NioEventLoop是boss线程 这里就是op_accept事件
             *
             * 无论处理op_read事件还是op_accept事件 都走的unsafe的read()方法 这里unsafe是通过channel获取到的
             * 如果处理的是accept事件 这里的channel是NioServerSocketChannel 与之绑定的是{@link io.netty.channel.nio.AbstractNioMessageChannel.NioMessageUnsafe#unsafe}
             * 如果处理的是op_read事件 处理的线程是worker线程 这里的channel是{@link io.netty.channel.socket.nio.NioServerSocketChannel} 与之绑定的unsafe对象是{@link io.netty.channel.nio.AbstractNioByteChannel.NioByteUnsafe} 会进入{@link AbstractNioByteChannel.NioByteUnsafe#read()}方法
             *
             * NioServerSocketChannel的注册复用器和bind+listen完成后 关注的事件类型是Accept接收连接类型(16)
             *     - 此时客户端向服务端发起Connect连接请求 NioServerSocketChannel会收到就绪事件类型16
             *         - boss线程读取客户端的连接信息
             *         - NioServerSocketChannel读取连接实现在NioMessageUnsafe中
             *         - NioMessageUnsafe负责接收NioSocketChannel连接
             *         - 调用Jdk底层的accept接收客户端连接
             *         - 将accept结果封装成NioSocketChannel向pipeline传播(pipeline中有 head-bossHandler-ServerBootstrapAcceptor-tail)
             *         - 触发ServerBootstrapAcceptor回调
             */
// Also check for readOps of 0 to workaround possible JDK bug which may otherwise lead
// to a spin loop
if ((readyOps & (SelectionKey.OP_READ | SelectionKey.OP_ACCEPT)) != 0 || readyOps == 0)
    unsafe.read();
```



## 二 读取客户端连接

```java
// NioMessageUnsafe
/**
         *     - 此时客户端向服务端发起Connect连接请求 NioServerSocketChannel会收到就绪事件类型16的Accept
         *         - NioServerSocketChannel读取连接实现在NioMessageUnsafe中
         *         - NioMessageUnsafe负责接收NioSocketChannel连接
         *         - 调用Jdk底层的accept接收客户端连接
         *         - 将accept结果封装成NioSocketChannel向pipeline传播(pipeline中有 head-bossHandler-ServerBootstrapAcceptor-tail)
         *         - 触发ServerBootstrapAcceptor回调
         */
@Override
public void read() {
    assert eventLoop().inEventLoop(); // IO操作(Channel上的读写)只能由注册的复用器所在的线程 也就是绑定的唯一的NioEventLoop线程执行
    /**
             * 给Channel的配置参数 最终体现在OS的Socket上
             *     - 通过ServerBootstrap#config传递的NioServerSocketChannel的配置信息
             */
    final ChannelConfig config = config();
    /**
             * 每个Channel中都维护了一个pipeline
             *     - NioServerSocket收到客户端连接 触发自己的Accept接收连接状态 读取连接信息
             */
    final ChannelPipeline pipeline = pipeline();
    final RecvByteBufAllocator.Handle allocHandle = unsafe().recvBufAllocHandle(); // 接收对端数据时 ByteBuf的分配策略(基于历史数据动态调整大小 避免太大发生空间浪费 避免太小造成频繁扩容)
    allocHandle.reset(config);

    boolean closed = false;
    Throwable exception = null;
    try {
        try {
            do {
                /**
                         * NioServerSocketChannel接收客户端NioSocketChannel连接
                         *     - Jdk底层系统调用accept
                         *     - 将服务端fork出来的Socket封装成Jdk的SocketChannel
                         *     - Netty将Jdk的SocketChannel封装成NioSocketChannel
                         *     - 将NioServerSocketChannel和accept结果NioSocketChannel一起封装到ByteBuf中
                         */
                int localRead = AbstractNioMessageChannel.this.doReadMessages(readBuf);
                if (localRead == 0) break;
                if (localRead < 0) {
                    closed = true;
                    break;
                }
                allocHandle.incMessagesRead(localRead); // 读到的连接数计数
            } while (continueReading(allocHandle)); // 连接数是否超过最大值
        } catch (Throwable t) {
            exception = t;
        }
        // 遍历每一条客户端连接
        int size = readBuf.size();
        for (int i = 0; i < size; i++) {
            readPending = false;
            /**
                     * 向NioServerSocketChannel的pipeline传播ChannelRead事件
                     * 此时pipeline中3个handler
                     *     - head
                     *     - ServerBootstrapAcceptor
                     *     - tail
                     * ServerBootstrap将回调方法处理服务端收到的客户端连接
                     * 对于ServerBootstrap的回调方法而言 收到的参数就是这儿的readBuf.get(...)内容 也就是每一条连接信息(ServerSocket, accept后fork出来的Socket)
                     */
            pipeline.fireChannelRead(readBuf.get(i));
        }
        readBuf.clear();
        allocHandle.readComplete();
        pipeline.fireChannelReadComplete();

        if (exception != null) {
            closed = closeOnReadError(exception);

            pipeline.fireExceptionCaught(exception);
        }

        if (closed) {
            inputShutdown = true;
            if (isOpen()) {
                close(voidPromise());
            }
        }
    } finally {
        // Check if there is a readPending which was not processed yet.
        // This could be for two reasons:
        // * The user called Channel.read() or ChannelHandlerContext.read() in channelRead(...) method
        // * The user called Channel.read() or ChannelHandlerContext.read() in channelReadComplete(...) method
        //
        // See https://github.com/netty/netty/issues/2254
        if (!readPending && !config.isAutoRead()) {
            removeReadOp();
        }
    }
}
```

## 三 ServerBootstrapAcceptor回调

```java
// ServerBootstrapAcceptor.java
/**
         * NioServerSocketChannel等待客户端连接时 关注这Accept事件(16)
         * 此时pipeline上有4个handler
         *     - head
         *     - bossHandler(比如LoggingHandler)
         *     - ServerBootstrapAcceptor
         *     - tail
         * NioMessageUnsafe中读取了所有连进服务端的客户端连接 向pipeline发布了ChannelRead事件
         * 触发了该方法的回调
         *     - msg就是每一条客户端连接信息的封装
         *         - NioServerSocketChannel
         *         - NioSocketChannel(对accept结果的封装)
         */
@Override
@SuppressWarnings("unchecked")
public void channelRead(ChannelHandlerContext ctx, Object msg) {
    final Channel child = (Channel) msg; // msg就是客户端的一条连接信息 实现类型是NioSocketChannel 要注册到workerGroup中的workerChannel
    child.pipeline().addLast(this.childHandler); // 向workerChannel中添加ServerBootstrap初始化时指定的workerHandler
    setChannelOptions(child, childOptions, logger);
    setAttributes(child, childAttrs);

    try {
        // workerChannel注册到workerGroup中
        this.childGroup
            .register(child)
            .addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(ChannelFuture future) throws Exception {
                    if (!future.isSuccess()) {
                        forceClose(child, future.cause());
                    }
                }
            });
    } catch (Throwable t) {
        forceClose(child, t);
    }
}
```

注册复用器

```java
// AbstraceUnsafe
/**
         * - NioEventLoop线程执行 Jdk的Channel注册到复用器上 不关注事件(关注的事件是0 因为对于NIO而言 注册复用器是最前置的动作 后续的连接和可读对于ServerSocket而言都是收到了可读事件 所以按照职责分工 让ServerBootstrapAcceptor去更要关注的事件)
         * - 发布事件
         *     - 发布handlerAdd事件 触发ChannelInitializer方法执行
         *     - 发布ChannelRegister事件
         *     - 根据Channel状态判定事件(服务端bind或者客户端connect的Channel现在都还没有处于active打开状态)
         *         - 服务端Accept出来的NioSocketChannel 初始状态就已经是active打开状态
         *             - 首次注册到workerGroup的时候发布ChannelActive事件
         */
private void register0(ChannelPromise promise) {
    try {
        // check if the channel is still open as it could be closed in the mean time when the register
        // call was outside of the eventLoop
        if (!promise.setUncancellable() || !ensureOpen(promise)) return;
        boolean firstRegistration = neverRegistered;
        /**
                 * 实际的注册
                 * jdk底层操作 将channel注册到selector复用器上 不关注Channel发生的事件类型
                 * 注册复用器的时候监听集合是空的(也就是让复用器对Jdk的Channel感兴趣的事件是0)
                 */
        AbstractChannel.this.doRegister();
        neverRegistered = false;
        AbstractChannel.this.registered = true; // 标识Channel跟NioEventLoop绑定成功

        // Ensure we call handlerAdded(...) before we actually notify the promise. This is needed as the
        // user may already fire events through the pipeline in the ChannelFutureListener.

        /**
                 *
                 * 事件响应式编程的体现点
                 * 当前的register操作已经成功 该事件应该被pipeline上所有关心register事件的handler感知
                 * 因此需要先确保pipeline上handler已经完备 也就是ChannelInitializer这个辅助类已经完成
                 */

        /**
                 * 发布handlerAdd事件
                 * 让pipeline中handler关注handlerAdded(...)的handler执行
                 *     - 触发ChannelInitializer方法执行
                 */
        pipeline.invokeHandlerAddedIfNeeded();

        safeSetSuccess(promise); // 设置当前promise状态为success 当前register()方法是在eventLoop中的线程中执行的 需要通知提交register操作的那个线程

        /**
                 * 到此为止 Channel中pipeline中的handler已经完备了 可以对关注的事件进行关注了
                 * NioServerSocketChannel的pipeline中有head、workerHandler、SocketBootstrapAcceptor、tail
                 */

        /**
                 * 发布register事件
                 * 让pipeline中handler关注channelRegistered(...)的handler执行
                 */
        pipeline.fireChannelRegistered();
        // Only fire a channelActive if the channel has never been registered. This prevents firing
        // multiple channel actives if the channel is deregistered and re-registered.
        /**
                 * active指channel已经打开
                 *     - NioServerSocketChannel已经执行过bind操作
                 *     - NioSocketChannel...
                 *
                 * 注册复用器属于前置操作
                 *     - 先于NioServerSocketChannel的bind(bind+listen)操作
                 *     - 先于NioSocketChannel的connect操作
                 * 因此Channel注册完复用器走到这时Channel还没有active
                 *
                 * 但是如果是NioServerSocketChannel通过accept生成了一个NioSocketChannel在workerGroup中发生了注册复用器时 这时候
                 */
        if (isActive()) {
            if (firstRegistration) {
                pipeline.fireChannelActive(); // 服务端accept出来的NioSocketChannel注册到workerGroup中后发布ChannelActive事件 触发HeadHandler将复用器关注的事件增加对可读的关注 0->16
            } else if (config().isAutoRead()) {
                // This channel was registered before and autoRead() is set. This means we need to begin read
                // again so that we process inbound data.
                //
                // See https://github.com/netty/netty/issues/4805
                this.beginRead();
            }
        }
    } catch (Throwable t) {
        // Close the channel directly to avoid FD leak.
        closeForcibly();
        closeFuture.setClosed();
        safeSetFailure(promise, t);
    }
}
```

熟悉的注册复用器的环节 注册复用器发生的时机：

* 服务端NioServerSocketChannel
  * bind(bind+listen)之前复用器关注事件集合为0
  * bind(bind+listen)之后发布ChannelActive事件增加复用器事件对可读(16)的关注
* 客户端NioSocketChannel
  * connect之前复用器关注事件集合为0
  * connect之后发布ChannelActive事件增加复用器事件对可读(16)的关注
* 服务端Accept出来的NioSocketChannel
  * 属于特殊条件下的Channel 注册复用器之后立即发布ChannelActive事件 增加复用器对可读事件(16)的关注

## 四 流程图

![](Netty源码-09-ServerBootstrapAcceptor/202211151045689.png)

---
title: Netty-06-负责连接的Channel
category_bar: true
categories: Netty
date: 2026-08-08 22:47:04
---

NioServerSocketChanel

## 1 factory构造实例干了什么事情

### 1.1 unsafe和pipeline

```java
    protected AbstractChannel(Channel parent) {
        // channel是不是其他channel创建的
        this.parent = parent;
        id = this.newId(); // 给每个channel分配一个唯一id
        /**
         * 每个channel内部都需要一个Unsafe实例 执行偏底层的操作
         * {@link io.netty.channel.nio.NioEventLoop}调用的时候会走到其父类的{@link AbstractNioByteChannel#newUnsafe()}方法
         */
        unsafe = this.newUnsafe();
        pipeline = this.newChannelPipeline(); // 每个channel内部都会创建一个pipeline 默认两个节点(head和tail 都不是哑节点 是有实际作用的)
    }
```

{%post_link Netty/Netty-09-unsafe%}

{%post_link Netty/Netty-10-pipeline%}

### 1.2 socket属性设置

```java
    protected AbstractNioChannel(Channel parent, SelectableChannel ch, int readInterestOp) {
        super(parent);
        // jdk的channel 绑定jdk底层的ServerSocketChannel netty的channel跟jdk的channel关系是组合关系 在netty的channel中有个jdk的channel成员变量 这个成员变量定义在AbstractNioChannel中
        this.ch = ch;
        /**
         * channel代表的socket往多路复用器selector注册时候要关注的事件
         * NioSocketChannel用来读写数据 关注的事件类型是OP_READ可读事件
         * NioServerSocketChannel用来连接 关注的事件类型是OP_ACCEPT连接事件
         */
        this.readInterestOp = readInterestOp;
        try {
            // 将jdk的channel设置为非阻塞模式(系统调用fcntl)
            ch.configureBlocking(false);
        } catch (IOException e) {
            try {
                ch.close();
            } catch (IOException e2) {
            }
            throw new ChannelException("Failed to enter non-blocking mode.", e);
        }
    }
```
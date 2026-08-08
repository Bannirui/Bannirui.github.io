---
title: Netty-07-负责数据的Channel
category_bar: true
categories: Netty
date: 2026-08-08 22:47:16
---

## 1 factory构造出来的实例

### 1.1 unsafe和pipeline

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

{%post_link Netty/Netty-09-unsafe%}

{%post_link Netty/Netty-10-pipeline%}

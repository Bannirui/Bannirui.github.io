---
title: Netty-03-服务端实例
category_bar: true
categories: Netty
date: 2026-08-08 22:27:04
---

不管是服务端还是客户端 Netty都是先准备原材料 真正用到的时候才开辟资源

## 1 准备哪些原材料

- parent group
- child group
- channel factory
- parent handler
- child handler
- options

```java
            ServerBootstrap b = new ServerBootstrap(); // 创建服务端实例
            b
                    .group(bossGroup, workerGroup) // parent负责连接的 child负责读写的
                    .channel(NioServerSocketChannel.class) // 服务端用的channel
                    .option(ChannelOption.SO_BACKLOG, 100)
                    .handler(new LoggingHandler(LogLevel.INFO)) // 给parent 就是负责连接的用的
                    .childHandler(new ChannelInitializer<SocketChannel>() { // child就是给读写用的
                        @Override
                        public void initChannel(SocketChannel ch) throws Exception { // pipeline需要ChannelInitializer辅助类 借助辅助类可以指定多个handler组成pipeline 就是拦截器 在每个NioSocketChannel或NioServerSocketChannel实例内部都会有一个pipeline实例 并且还涉及到handler执行顺序
                            ChannelPipeline p = ch.pipeline();
                            p.addLast(new EchoServerHandler());
                        }
                    });
```

## 2 bind触发资源开辟

- {%post_link Netty/Netty-05-Channel%}
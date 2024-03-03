---
title: Netty源码-00-源码调试环境
date: 2023-03-06 20:35:31
category_bar: true
categories:
- Netty
tags:
- 1刷Netty
---

## 一 源码

笔记注释的[代码地址](https://github.com/Bannirui/netty.git)，分支为study。

## 二 环境

|       | 版本    |
| ----- | ------- |
| Netty | 4.1.169 |
| Java  | 8       |

## 三 Samples

### 1 服务端

#### 1.1 启动类

```java
/*
 * Copyright 2012 The Netty Project
 *
 * The Netty Project licenses this file to you under the Apache License,
 * version 2.0 (the "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at:
 *
 *   https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */
package io.netty.example.echo;

import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.*;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.SocketChannel;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import io.netty.handler.logging.LogLevel;
import io.netty.handler.logging.LoggingHandler;

import java.net.SocketAddress;

/**
 * Echoes back any received data from a client.
 */
public final class EchoServer {

    /**
     * <p><h3>Netty启动流程</h3></p>
     *
     * <p><h4>服务端</h4></p>
     * <ul>
     *     <li>1 {@link ServerBootstrap#ServerBootstrap()}创建启动引导实例</li>
     *     <li>2 {@link ServerBootstrap#group(EventLoopGroup, EventLoopGroup)}初始化boss和worker线程池</li>
     *     <li>3 {@link ServerBootstrap#channel(Class)}传入{@link NioServerSocketChannel}的{@link Class}对象调用{@link ReflectiveChannelFactory#ReflectiveChannelFactory(Class)}创建{@link ReflectiveChannelFactory}实例 赋值给{@link io.netty.bootstrap.AbstractBootstrap#channelFactory}
     *     而{@link ReflectiveChannelFactory}的构造方法就是将{@link ReflectiveChannelFactory#constructor}属性赋值为{@link NioServerSocketChannel}的构造器
     *     </li>
     *     <li>4 {@link ServerBootstrap#bind(int)}->{@link ServerBootstrap#doBind(SocketAddress)}</li>
     *     <ul>
     *         <li>{@link ServerBootstrap#initAndRegister()}中<pre>{@code channel=this.channelFactory.newChannel()}</pre>就是调用已经实例化了的{@link ReflectiveChannelFactory#newChannel()}对象方法 而该方法就是调用<pre>{@code return this.constructor.newInstance()}</pre> 利用反射创建{@link NioServerSocketChannel}的实例</li>
     *     </ul>
     * </ul>
     * 
     * <p><h4>客户端</h4></p>
     */
    public static void main(String[] args) throws Exception {

        // Configure the server.
        /**
         * boss线程组和worker线程组相当于2个NioEventLoop的集合 默认每个NioEventLoopGroup创建时 如果不传入线程数就会创建cpu线程数*2个NioEventLoop线程
         * boos线程通过轮询处理Server的accept事件 完成accept事件之后就会创建客户端channel 通过一定的策略 分发到worker线程进行处理
         * worker线程主要用于处理客户端的读写事件
         */
        EventLoopGroup bossGroup = new NioEventLoopGroup(1); // Netty线程模型 主从Reactor线程模型
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        try {
            ServerBootstrap b = new ServerBootstrap(); // 创建服务端实例
            b
                    .group(bossGroup, workerGroup) // 初始化boss和worker线程池
                    .channel(NioServerSocketChannel.class) // 提供NioServerSocketChannel创建ChannelFactory->在下面bind()时机->ChannelFactory创建NioServerSocketChannel实例
                    .option(ChannelOption.SO_BACKLOG, 100)
                    .handler(new LoggingHandler(LogLevel.INFO)) // 指定LoggingHandler 这个handler是给服务端收到新的请求的时候处理用的
                    .childHandler(new ChannelInitializer<SocketChannel>() { // childHandler指定的handlers是给新创建的连接用的 服务端ServerSocketChannel在accept一个连接以后需要创建SocketChannel的实例 childHandler中设置的handler就是用于处理新创建的SocketChannel的 而不是用来处理ServerSocketChannel实例的
                        @Override
                        public void initChannel(SocketChannel ch) throws Exception { // pipeline需要ChannelInitializer辅助类 借助辅助类可以指定多个handler组成pipeline 就是拦截器 在每个NioSocketChannel或NioServerSocketChannel实例内部都会有一个pipeline实例 并且还涉及到handler执行顺序
                            ChannelPipeline p = ch.pipeline();
                            p.addLast(new EchoServerHandler());
                        }
                    });

            // Start the server.
            ChannelFuture f = b.bind(8007).sync(); // Netty异步编程 main线程调用bind()方法返回一个ChannelFuture bind()方法是一个异步方法 当某个执行线程执行了真正的绑定操作后 那个执行线程会标记这个future为成功 然后main线程调用sync()方法就会返回 如果bind()失败 sync()方法会将异常抛出来 进入finally代码块

            // Wait until the server socket is closed.
            f.channel().closeFuture().sync(); // 绑定端口bind()成功后 进到当前方法 channel()方法获取到该future关联的channel channel.closeFuture()也会返回一个ChannelFuture 然后调用sync()方法 这个sync()方法的返回条件是: 有其他的线程关闭了NioServerSocketChannel 往往是因为需要停掉服务了 然后那个线程会设置future的状态 此时main线程执行sync()方法才会返回
        } finally {
            // Shut down all event loops to terminate all threads.
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
}

```

#### 1.2 IO处理器

```java
/*
 * Copyright 2012 The Netty Project
 *
 * The Netty Project licenses this file to you under the Apache License,
 * version 2.0 (the "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at:
 *
 *   https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */
package io.netty.example.echo;

import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelHandler.Sharable;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundHandlerAdapter;
import io.netty.util.CharsetUtil;

/**
 * Handler implementation for the echo server.
 */
@Sharable
public class EchoServerHandler extends ChannelInboundHandlerAdapter {

    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) {
        System.out.println("服务端收到客户端的请求 msg=" + ((ByteBuf) msg).toString(CharsetUtil.UTF_8));
        // 回写
        ctx.write(msg);
    }

    @Override
    public void channelReadComplete(ChannelHandlerContext ctx) {
        ctx.flush();
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
        // Close the connection when an exception is raised.
        System.out.println("捕获到异常 cause=" + cause.getCause());
        ctx.close();
    }
}

```

### 2 客户端

#### 2.1 启动类

```java
/*
 * Copyright 2012 The Netty Project
 *
 * The Netty Project licenses this file to you under the Apache License,
 * version 2.0 (the "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at:
 *
 *   https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */
package io.netty.example.echo;

import io.netty.bootstrap.Bootstrap;
import io.netty.channel.*;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.SocketChannel;
import io.netty.channel.socket.nio.NioSocketChannel;

/**
 * Sends one message when a connection is open and echoes back any received
 * data to the server.  Simply put, the echo client initiates the ping-pong
 * traffic between the echo client and server by sending the first message to
 * the server.
 */
public final class EchoClient {

    public static void main(String[] args) throws Exception {
        // Configure the client.
        EventLoopGroup group = new NioEventLoopGroup(); // 客户端1个group Netty中的多个线程
        try {
            Bootstrap b = new Bootstrap(); // 创建客户端实例
            b.group(group)
             .channel(NioSocketChannel.class) // 根据NioSocketChannel创建了ChannelFactory->在下面connect()时机->ChannelFactory创建NioSocketChannel实例创建
             .option(ChannelOption.TCP_NODELAY, true)
             .handler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 public void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     p.addLast(new EchoClientHandler());
                 }
             }); // 指定handler 客户端处理请求过程中使用的handlers

            // Start the client.
            ChannelFuture f = b.connect("127.0.0.1", 8007).sync(); // Netty异步编程 main线程调用connect()方法 connect()方法是个异步方法 当某个线程执行了真正的connect操作后 那个线程会调用setSuccess()方法设置future成功了 如果connect失败 那个线程会setFailure()设置future为失败 如果成功了 main线程就可以通过sync()方法拿到返回 如果失败了main线程会在sync()方法抛出异常进到finally代码块

            // Wait until the connection is closed.
            f.channel().closeFuture().sync(); // 客户端connect成功之后开到这行代码 channel()方法获取该future关联的channel channel.closeFuture()也是一个异步方法 然后main线程调用sync()拿到返回或者抛出异常 sync()拿到返回的条件是: 有某个线程关闭了SocketChannel 往往是因为需要停掉服务 然后那个线程通过setSuccess()方法设置future为成功或者通过setFailure()方法设置future为失败
        } finally {
            // Shut down the event loop to terminate all threads.
            group.shutdownGracefully();
        }
    }
}

```

#### 2.2 IO处理器

```java
/*
 * Copyright 2012 The Netty Project
 *
 * The Netty Project licenses this file to you under the Apache License,
 * version 2.0 (the "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at:
 *
 *   https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */
package io.netty.example.echo;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.Unpooled;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundHandlerAdapter;
import io.netty.util.CharsetUtil;

/**
 * Handler implementation for the echo client.  It initiates the ping-pong
 * traffic between the echo client and server by sending the first message to
 * the server.
 */
public class EchoClientHandler extends ChannelInboundHandlerAdapter {

    @Override
    public void channelActive(ChannelHandlerContext ctx) {
        System.out.println("客户端连接服务端成功");
        // 数据写到channel
        ctx.writeAndFlush(Unpooled.copiedBuffer("hello, this is client", CharsetUtil.UTF_8));
    }

    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) {
        System.out.println("客户端收到数据 msg=" + ((ByteBuf) msg).toString(CharsetUtil.UTF_8));
    }

    @Override
    public void channelReadComplete(ChannelHandlerContext ctx) {
        ctx.flush();
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
        // Close the connection when an exception is raised.
        System.out.println("客户端异常 ex=" + cause.getMessage());
        ctx.close();
    }
}
```

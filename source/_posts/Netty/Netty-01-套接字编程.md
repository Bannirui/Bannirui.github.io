---
title: Netty-01-套接字编程
category_bar: true
categories: Netty
date: 2026-08-08 21:24:42
---

{%post_link Redis/Redis-0x10-socket编程%}

看完上面socket之后，再补充一些

## 1 什么是TCP

TCP就是一对socket，五元组(协议 源ip 源端口 目的ip 目的端口)

服务端依次调用socket->bind->listen

- listen函数需要指定backlog表明的全连接队列大小
- 当客户端socket连接过来时 进行TCP的连接 经历3次握手
  - 第1次握手 client->server发送SYN包 服务端收到后创建一个request socket放到半连接队列里面
  - 第2次握手 server->client发送SYN+ACK
  - 第3次握手 client->server发送ACK 服务端内核就判定TCP连接已经建立好 把上面的request socket创建成socket放到全连接队列里面 就是listen函数指定大小的那个队列 等着accept函数来取 并且维护了从五元组到socket的映射
- 现在还没有accept 客户端当然可以开始发送数据了 不管什么时候通过TCP发送数据到服务端 服务端内核都会从TCP首部解析出五元组 映射到看看数据是属于哪个socket的 只不过现在服务端还没有accept 没有把socket指派给新的fd
- 调用accept就是从全连接队列里面取出来socket然后封装到fd表 把脚标fd告诉调用方 以后调用方就用这个新的fd操作socket

所以明确的服务端同一个端口上 会有很多socket 但是分为两类

- 负责连接的socket
- 负责数据的socket

## 2 selector

{%post_link Redis/Redis-0x0D-事件循环器AE%}

所有的高性能网络服务器都是一样的 底层最重要的都是内核提供的IO多路复用器

## 3 给Netty的源码做些前置铺垫

上面这么多都是为了给看源码做铺垫

3.1 selector是单线程实现多个事件维护 Netty围绕selector包裹成线程模型 一个线程就是一个selector 封装成的东西就叫EventLoop 

3.2 服务端要完成的工作是 事件的监听 事件的分发 事件的处理 给这种模型起个名字就叫Reactor模型 

3.3 上面说过服务端socket分了两类 负责连接的和负责数据的 Netty把这两类分开封装那么就是负责连接的EventLoop和负责读写的EventLoop

如果很多读写 那么一个EventLoop也就是一个线程处理会成为瓶颈 那么这个时候就要问了为啥Redis就是一个selector线程可以没有问题 因为数据库的数据读写是很简单的 网络框架未来人家怎么处理逻辑你是不知道的

所以自然而然会想到用一批EventLoop 那么你会想到用一个东西管理一批EventLoop 并且一个负责连接的EventLoop何尝不是一批EventLoop的特例

3.4 Netty定义了EventLoopGroup用来负责管理EventLoop

3.5 在定义服务端的时候 Netty把负责连接的那个EventLoopGroup定义为parent 把负责读写的EventLoopGroup定义了child 其他组件以此类推

  

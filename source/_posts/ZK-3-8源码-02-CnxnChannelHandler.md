---
title: ZK@3.8源码-02-CnxnChannelHandler
date: 2023-03-06 15:29:32
tags:
- ZK@3.8
categories:
- ZK源码
---

上节梳理了zk单机启动流程，`NettyServerCnxnFactory`提供了标准的Netty服务端开发模板，`ZooKeeperServer`定义了请求处理责任链。现在两个独立的线程，如何将Socket的数据映射成zk请求，`CnxnChannelHandler`成功关键的枢纽。

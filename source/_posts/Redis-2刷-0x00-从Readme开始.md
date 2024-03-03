---
title: Redis-2刷-0x00-从Readme开始
date: 2023-11-01 20:27:55
category_bar: true
categories: [ 'Redis' ]
tags: [ '2刷Redis' ]
---

我们期待从Readme中能够快速地对Redis有一个宏观的了解，也方便后续大处着眼小处着手去学习细节。

### 1 作者对Redis的定义

原文描述

```txt
Redis is often referred to as a *data structures* server. What this means is that Redis provides access to mutable data structures via a set of commands, which are sent using a *server-client* model with TCP sockets and a simple protocol. So different processes can query and modify the same data structures in a shared way.

Data structures implemented into Redis have a few special properties:

* Redis cares to store them on disk, even if they are always served and modified into the server memory. This means that Redis is fast, but that it is also non-volatile.
* The implementation of data structures emphasizes memory efficiency, so data structures inside Redis will likely use less memory compared to the same data structure modelled using a high-level programming language.
* Redis offers a number of features that are natural to find in a database, like replication, tunable levels of durability, clustering, and high availability.
```

从中能够感受到作者对自己实现的数据结构有着更大的推销热情，基于TCP的网络模型一言以蔽之，而着重笔墨在数据结构的介绍上。

在粗浅学习过Redis之后我更认同作者的观点。问为什么Redis这么快，我可能会回答两个点
- EventLoop的非阻塞多路复用网络模型
- 高效的数据结构实现

二者之间，数据结构权重更高。竞品或者其他相似产品：要么就是同样基于高速网络模型的，但是没有如此丰富高效的数据结构；要么就是可能提供了比较多的数据结构选择，但是网络传输稍逊色。

即Redis在网络通信和内存模型两个领域都是佼佼者的存在。

因为类库的丰富支持，现在想要实现高效网络通信已经不是特别难的事情，各个平台都有多路复用实现的提供，比如：
- Linux的epoll
- BSD的kqueue
- Windows的poll

而数据结构的实现难度明显更难，因此对于数据结构的学习也将是更值得关注的。

### 2 项目结构

比较重要的文件或者目录有：
- 根目录的Readme
- 根目录的Makefile
- src目录
- server.h `server`和`client`两个重要的结构体定义
- server.c 程序入口和几个重要的函数功能
- networking.c socket网络编程
- aof.c和rdb.c 数据持久化模型
- db.c 数据库实现
- object.c 比较基础的结构体
- replication.c 作者直言不讳地说该文件比较困难不建议基础较差的人直接学习，但凡跟分布式领域有关系的就没有简单的话题
- t_开头的几个c文件 是具体的数据类型实现
- ae.c EventLoop模型
- sds.c 字符串数据类型实现
- dict.c 渐进式hash表实现

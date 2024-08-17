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

因为套接字的类型有两种封装，对应的连接也有两种封装

- TCP链接

- 本地连接


---
title: c++实现http服务器
category_bar: true
date: 2026-01-22 16:01:01
categories: SideProject
tags: 网络编程
---

网络编程是个宽泛的话题，学习技能的有效方式是干中学，通过实现一个网络服务器可以触达网络编程相关的点滴。

> 项目链接

[my-web-server](https://github.com/Bannirui/my-web-server)

## 1 实现效果

- 显示文本信息 ![](./c++实现http服务器/1769069445.png)
- 显示静态html文件 ![](./c++实现http服务器/1769069304.png)
- 性能 ![](./c++实现http服务器/1769069967.png)

## 2 技术点

- 原生socket
- 线程池
- 多路复用器
  - 高性能事件监听
  - 高精度定时器实现
- http协议
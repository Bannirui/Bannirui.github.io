---
title: nginx-0x10-ngin怎么防止惊群现象的
category_bar: true
date: 2025-04-12 21:20:36
categories: nginx
---

- 多worker进程注册对连接事件监听互斥
- 当一个worker进程注册成功一个连接事件成功后别的进程不能再监听
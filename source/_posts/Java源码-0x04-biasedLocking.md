---
title: Java源码-0x04-biasedLocking
category_bar: true
date: 2024-03-09 23:53:05
categories: Java
tags: Java@15
---

偏向锁相关的实现都在文件`src/hotspot/share/runtime/biasedLocking.cpp`中

方法API

- [revoke](#1)

### <a id="1">revoke</a>
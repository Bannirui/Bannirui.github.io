---
title: Redis-0x18-库函数chmod
category_bar: true
date: 2024-05-14 20:40:52
categories: Redis
---

chmod系统调用用于更改文件的权限

在类Unix系统中 文件权限控制访问级别包括读、写和执行权限

参数说明

- path 指向文件路径的指针

- mode 用于设置文件权限的模式 由一些列标志组合而成
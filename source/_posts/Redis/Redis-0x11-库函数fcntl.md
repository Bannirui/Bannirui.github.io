---
title: Redis-0x11-库函数fcntl
category_bar: true
date: 2024-04-15 20:01:10
categories: Redis
---

```shell
SYNOPSIS
     #include <fcntl.h>

     int
     fcntl(int fildes, int cmd, ...);

DESCRIPTION
     fcntl() provides for control over descriptors.  The argument fildes is a descriptor to be operated on by cmd as follows:

```

- F_GETFL 获取描述符(socket描述符)的状态标志

- F_SETFL 设置描述符(socket描述符)的状态标志

---
title: Redis-2刷-0x13-库函数fcntl
date: 2024-01-05 12:33:48
categories: Redis
tags: 2刷Redis
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



---
title: Redis-2刷-0x0B-库函数fopen
date: 2023-12-28 14:58:32
categories: Redis
tags: 2刷Redis
---

1 查询系统手册
---

```shell
man 3 fopen
```

2 库函数
---

### 2.1 原型

```shell
#include <stdio.h>

FILE *
fopen(const char * restrict path, const char * restrict mode);
```

```shell
     The fopen() function opens the file whose name is the string pointed to by path and associates a stream with it.

     The argument mode points to a string beginning with one of the following letters:

     “r”     Open for reading.  The stream is positioned at the beginning of the file.  Fail if the file does not exist.

     “w”     Open for writing.  The stream is positioned at the beginning of the file.  Create the file if it does not exist.

     “a”     Open for writing.  The stream is positioned at the end of the file.  Subsequent writes to the file will always end up at the
             then current end of file, irrespective of any intervening fseek(3) or similar.  Create the file if it does not exist.
```

### 2.2 入参

2个参数都是必填

- path是文件的绝对路径

- mode以什么模式打开文件

  - r读

  - w写

  - a追加写

### 2.3 出参

返回值是文件描述符
---
title: Redis-0x14-库函数fgets
category_bar: true
date: 2024-04-16 13:12:08
categories: Redis
---

1 系统手册
---

```shell
man 3 fgets
```

2 库函数
---

### 2.1 原型

```shell
     #include <stdio.h>

     char *
     fgets(char * restrict str, int size, FILE * restrict stream);
```

```shell
DESCRIPTION
     The fgets() function reads at most one less than the number of characters specified by size from the given stream and stores them in
     the string str.  Reading stops when a newline character is found, at end-of-file or error.  The newline, if any, is retained.  If any
     characters are read and there is no error, a ‘\0’ character is appended to end the string.

RETURN VALUES
     Upon successful completion, fgets() and gets() return a pointer to the string.  If end-of-file occurs before any characters are read,
     they return NULL and the buffer contents remain unchanged.  If an error occurs, they return NULL and the buffer contents are
     indeterminate.  The fgets() and gets() functions do not distinguish between end-of-file and error, and callers must use feof(3) and
     ferror(3) to determine which occurred.
```

### 2.2 入参

从stream中以行为单位读取内容，将读出来的数据写到字符数组str中，限定每行长度限为size

3个参数都是必填

- str 缓存读出来的行内容

- size 单行长度上限

- stream 数据源

### 2.3 出参

- 非NULL 指向的读出来的字符串地址

- NULL 出错或者文件读完了
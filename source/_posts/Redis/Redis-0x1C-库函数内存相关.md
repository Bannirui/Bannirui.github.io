---
title: Redis-0x1C-库函数内存相关
category_bar: true
date: 2024-05-28 11:00:20
categories: Redis
---

1 memcmp
---

按byte比较两块内存内容

### 1.1 原型

```c
     #include <string.h>

     int
     memcmp(const void *s1, const void *s2, size_t n);
```

### 1.2 入参

- s1 指针 指向第一块内存

- s2 指针 指向第二块内存

- n 比较二者多长内容

### 1.3 出参

- 0 表示二者内容完全相同

- 小于0 表示s1小于s2

- 大于0 表示s1大于s2

### 1.4 源码

```c
    if (fread(sig,1,5,fp) != 5 || memcmp(sig,"REDIS",5) != 0)
```
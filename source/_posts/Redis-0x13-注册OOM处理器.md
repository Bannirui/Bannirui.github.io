---
title: Redis-0x13-注册OOM处理器
date: 2023-04-11 21:46:14
category_bar: true
tags:  [ Redis@6.2 ]
categories:  [ Redis ]
---

在全局注册一个接口，发生内存OOM时用于回调，具体实现由业务测关注。

## 1 处理器接口

```c
// 内存OOM处理器
static void (*zmalloc_oom_handler)(size_t) = zmalloc_default_oom;
```

## 2 默认处理器

```c
// 内存OOM处理器-默认处理器
static void zmalloc_default_oom(size_t size) {
    fprintf(stderr, "zmalloc: Out of memory trying to allocate %zu bytes\n",
        size);
    fflush(stderr);
    abort();
}
```

## 3 注册处理器

```c
// 内存oom的处理器 注册了一个回调函数
zmalloc_set_oom_handler(redisOutOfMemoryHandler);
```

## 4 自定义处理器

```c
/**
 * @brief 发生内存OOM时的处理器
 * @param allocation_size
 */
void redisOutOfMemoryHandler(size_t allocation_size) {
    serverLog(LL_WARNING,"Out Of Memory allocating %zu bytes!",
        allocation_size);
    serverPanic("Redis aborting for OUT OF MEMORY. Allocating %zu bytes!",
        allocation_size);
}
```


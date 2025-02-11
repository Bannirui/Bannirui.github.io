---
title: Redis-0x30-共享对象
category_bar: true
date: 2025-02-11 17:09:19
categories: Redis
---

在{% post_link Redis/Redis-0x27-数据结构redisObject %}中讲到了redisObject的refcount用处

下面是共享变量的使用地方，在`server.c`的`createSharedObjects`方法中

```c
    // 字符串的共享变量
    shared.redacted = makeObjectShared(createStringObject("(redacted)",10));
    // 小整数缓存池
    for (j = 0; j < OBJ_SHARED_INTEGERS; j++) {
        shared.integers[j] =
            makeObjectShared(createObject(OBJ_STRING,(void*)(long)j));
        shared.integers[j]->encoding = OBJ_ENCODING_INT;
    }
```

小整数缓存池是一种常用技术手段，把0到1w的整数都作为共享对象实例化出来缓存起来，这种小整数被使用概率比较高频，用空间换时间，减少以后的频繁创建对象的开销

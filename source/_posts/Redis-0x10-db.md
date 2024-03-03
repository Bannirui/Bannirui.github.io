---
title: Redis-0x10-db
date: 2023-04-10 10:33:44
category_bar: true
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

## 1 设置键

```c
/**
 * @brief 设置键
 * @param c
 * @param db 内存数据库
 * @param key 键
 * @param val 值
 * @param keepttl 标识是否对键key设置过期
 *                  - key设置过期的语义是将key加到过期字典中
 *                  - key不设置过期的语义是过期字典中不存在key
 * @param signal
 */
void genericSetKey(client *c, redisDb *db, robj *key, robj *val, int keepttl, int signal) {
    if (lookupKeyWrite(db,key) == NULL) { // 数据库不存在键
        dbAdd(db,key,val); // 全局字典 添加键
    } else {
        dbOverwrite(db,key,val); // 全局字典 更新键
    }
    incrRefCount(val);
    if (!keepttl) removeExpire(db,key); // 从过期字典中删除键
    if (signal) signalModifiedKey(c,db,key);
}
```


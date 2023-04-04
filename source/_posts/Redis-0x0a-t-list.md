---
title: Redis-0x0a-t_list
date: 2023-04-03 22:10:58
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

1 数据结构关系

| 数据类型     | 实现   | 编码方式               | 数据结构  |
| ------------ | ------ | ---------------------- | --------- |
| 列表OBJ_LIST | t_list | OBJ_ENCODING_QUICKLIST | quicklist |
|              |        | OBJ_ENCODING_ZIPLIST   | ziplist   |

2 添加元素

```c
/**
 * @brief OBJ_LIST 列表类型数据类型 添加元素
 * @param subject redisObject实例
 * @param value 要添加的元素
 * @param where 0标识头插 否则标识尾插
 */
void listTypePush(robj *subject, robj *value, int where) {
    if (subject->encoding == OBJ_ENCODING_QUICKLIST) { // 编码类型 说明列表类型只有quicklist这一种编码方式 而quicklist的节点又通过ziplist进行数据存储
        // 元素进行头插还是尾插
        int pos = (where == LIST_HEAD) ? QUICKLIST_HEAD : QUICKLIST_TAIL;
        if (value->encoding == OBJ_ENCODING_INT) { // 整数转字符串
            char buf[32];
            ll2string(buf, 32, (long)value->ptr);
            quicklistPush(subject->ptr, buf, strlen(buf), pos);
        } else {
            quicklistPush(subject->ptr, value->ptr, sdslen(value->ptr), pos);
        }
    } else {
        serverPanic("Unknown list encoding");
    }
}
```


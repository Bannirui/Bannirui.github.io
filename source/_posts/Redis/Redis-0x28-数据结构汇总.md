---
title: Redis-0x28-数据结构汇总
category_bar: true
date: 2025-02-11 16:03:29
categories: Redis
---

redis中提供了丰富的数据类型，为了高效使用内存又对每种数据类型提供了不同的编码方式，数据类型和编码的枚举在`server.h`中

```c
// 字符串
#define OBJ_STRING 0    /* String object. */
// 列表
#define OBJ_LIST 1      /* List object. */
// 集合
#define OBJ_SET 2       /* Set object. */
// 有序集合
#define OBJ_ZSET 3      /* Sorted set object. */
// 哈希表
#define OBJ_HASH 4      /* Hash object. */
#define OBJ_MODULE 5    /* Module object. */
#define OBJ_STREAM 6    /* Stream object. */
// raw编码字符串 只有字符串才会用到的编码方式
#define OBJ_ENCODING_RAW 0     /* Raw representation */

// int编码字符串
#define OBJ_ENCODING_INT 1     /* Encoded as integer */
#define OBJ_ENCODING_HT 2      /* Encoded as hash table */
#define OBJ_ENCODING_ZIPMAP 3  /* Encoded as zipmap */
#define OBJ_ENCODING_LINKEDLIST 4 /* No longer used: old list encoding. */
#define OBJ_ENCODING_ZIPLIST 5 /* Encoded as ziplist */
#define OBJ_ENCODING_INTSET 6  /* Encoded as intset */
#define OBJ_ENCODING_SKIPLIST 7  /* Encoded as skiplist */
// embed编码字符串
#define OBJ_ENCODING_EMBSTR 8  /* Embedded sds string encoding */
#define OBJ_ENCODING_QUICKLIST 9 /* Encoded as linked list of ziplists */
#define OBJ_ENCODING_STREAM 10 /* Encoded as a radix tree of listpacks */
```

| 数据类型 | 编码方式 | 链接 |
| -------- | -------- | ---- |
| string   | int embed raw      | {% post_link Redis/Redis-0x12-数据结构sds %} {% post_link Redis/Redis-0x26-数据结构string %} |
| list | quicklist | {% post_link Redis/Redis-0x23-数据结构quicklist %} |
| list     | ziplist | {% post_link Redis/Redis-0x22-数据结构ziplist %} |
| set      | ht       | {% post_link Redis/Redis-0x1E-数据结构set %} {% post_link Redis/Redis-0x25-数据结构hash %} |
| set | intset | {% post_link Redis/Redis-0x1E-数据结构set %} {% post_link Redis/Redis-0x1F-数据结构intset %} |
| zset | ziplist | {% post_link Redis/Redis-0x20-数据结构zset %} {% post_link Redis/Redis-0x22-数据结构ziplist %} |
| hash | ziplist | {% post_link Redis/Redis-0x0B-数据结构dict %} {% post_link Redis/Redis-0x22-数据结构ziplist %} |
| hash | ht | {% post_link Redis/Redis-0x0B-数据结构dict %} {% post_link Redis/Redis-0x25-数据结构hash %} |
| stream |   |      |
| module   |    |      |


---
title: Redis-0x08-redisObject
index_img: /img/Redis-0x08-redisObject.png
date: 2023-04-03 13:16:28
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

## 1 数据结构

### 1.1 数据结构图

![](Redis-0x08-redisObject/image-20230403131757153.png)

### 1.2 type字段

| 数据类型 | 宏定义     | 值   |
| -------- | ---------- | ---- |
| 字符串   | OBJ_STRING | 0    |
| 列表     | OBJ_LIST   | 1    |
| 集合     | OBJ_SET    | 2    |
| 有序集合 | OBJ_ZSET   | 3    |
| 哈希表   | OBJ_HASH   | 4    |

### 1.3 encoding字段

| 编码方式 | 宏定义                  | 值   |
| -------- | ----------------------- | ---- |
|          | OBJ_ENCODING_RAW        | 0    |
|          | OBJ_ENCODING_INT        | 1    |
|          | OBJ_ENCODING_HT         | 2    |
|          | OBJ_ENCODING_ZIPMAP     | 3    |
|          | OBJ_ENCODING_LINKEDLIST | 4    |
|          | OBJ_ENCODING_ZIPLIST    | 5    |
|          | OBJ_ENCODING_INTSET     | 6    |
|          | OBJ_ENCODING_SKIPLIST   | 7    |
|          | OBJ_ENCODING_EMBSTR     | 8    |
|          | OBJ_ENCODING_QUICKLIST  | 9    |
|          | OBJ_ENCODING_STREAM     | 10   |

### 1.4 lru字段

### 1.5 refcount字段

### 1.6 ptr字段

---
title: Redis-0x0c-t_zset
date: 2023-04-03 22:11:12
tags: [ Redis@6.2 ]
categories: [ Redis ]
---
## 1 zset有序集合 数据结构关系

| 数据类型     | 实现   | 编码方式                                                   | 数据结构  |
| ------------ | ------ | ---------------------------------------------------------- | --------- |
| 列表OBJ_ZSET | t_zset | {% post_link Redis-0x0f-zskiplist OBJ_ENCODING_SKIPLIST %} | zskiplist |
|              |        | {% post_link Redis-0x05-ziplist OBJ_ENCODING_ZIPLIST %}    | ziplist   |

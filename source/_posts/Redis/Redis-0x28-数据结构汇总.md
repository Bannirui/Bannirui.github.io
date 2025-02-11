---
title: Redis-0x28-数据结构汇总
category_bar: true
date: 2025-02-11 16:03:29
categories: Redis
---

redis中提供了丰富的数据类型，为了高效使用内存又对每种数据类型提供了不同的编码方式

| 数据类型 | 编码方式 |      |      |      |
| -------- | -------- | ---- | ---- | ---- |
| string   | raw      |      |      |      |
| list     | int      |      |      |      |
| set      | ht       |      |      |      |
| zset     | zipmap   |      |      |      |
| hash     | ziplist  |      |      |      |
| module   | intset   |      |      |      |
| stream   | skiplist |      |      |      |
|          | embstr   |      |      |      |
|          | quickest |      |      |      |
|          | stream   |      |      |      |


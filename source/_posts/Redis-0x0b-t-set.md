---
title: Redis-0x0b-t_set
date: 2023-04-03 22:11:05
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

| 数据类型    | 实现  | 编码方式            | 数据结构 |
| ----------- | ----- | ------------------- | -------- |
| 列表OBJ_SET | t_set | OBJ_ENCODING_INTSET | intset   |
|             |       | OBJ_ENCODING_HT     | dict     |

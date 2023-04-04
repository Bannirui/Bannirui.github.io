---
title: Redis-0x09-t_string
index_img: /img/Redis-0x09-t_string.png
date: 2023-04-03 22:10:44
tags:
categories:
---

| 数据类型     | 实现   | 编码方式               | 数据结构  |
| ------------ | ------ | ---------------------- | --------- |
| 列表OBJ_LIST | t_list | OBJ_ENCODING_QUICKLIST | quicklist |
|              |        | OBJ_ENCODING_ZIPLIST   | ziplist   |

---
title: Redis-0x19-AOF持久化
category_bar: true
date: 2024-05-21 14:29:03
categories: Redis
---

实现在aof.c中

aof使用的是简单的文本协议

一个完整的协议为

```text
*n
$len1
指令1
$len2
指令2
...
$lenn
指令n
```

以`set name dingrui`为例 这条redis命令写到aof中为

```text
*3
$3
set
$4
name
$7
dingrui
```
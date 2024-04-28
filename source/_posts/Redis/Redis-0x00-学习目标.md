---
title: Redis-0x00-学习目标
category_bar: true
date: 2024-04-13 15:20:01
categories: Redis
---

大概的计划是顺着启动入口从上至下，遇到数据结构看数据结构，遇到启动流程看启动流程。

### 1 main主程序

- [ ] redis-server

- [ ] redis-cli

### 2 数据类型

- [ ] string

- [ ] list

- [ ] set

- [ ] zset

- [ ] hash


### 3 编码方式

- [X] sds {% post_link Redis/Redis-0x12-数据结构sds %}

- [X] dict {% post_link Redis/Redis-0x0B-数据结构dict %}

- [ ] zipmap

- [X] list {% post_link Redis/Redis-0x16-数据结构list链表 %}

- [ ] ziplist

- [ ] intset

- [ ] zskiplist

- [ ] quicklist

### 4 数据结构

- [ ] object

### 5 net网络

- [ ] anet

- [ ] networking

### 6 event事件

- [X] ae {% post_link Redis/Redis-0x0D-事件循环器AE %}

### 7 data数据操作

- [ ] aof

- [ ] config

- [ ] db

- [ ] multi

- [ ] rdb

- [ ] replication

### 8 tool工具

- [ ] bitops

- [ ] debug

- [ ] endianconv

- [ ] help

- [ ] lzf_c

- [ ] lzf_d

- [ ] rand

- [ ] release

- [ ] sha1

- [ ] util

- [ ] crc64

### 9 baseinfo基本信息

- [ ] asciilogo

- [ ] version

### 10 compatible兼容

- [ ] fmacros

- [ ] solarisfixes

### 11 wrapper封装类

- [ ] bio

- [ ] hyperloglog

- [ ] intset

- [ ] latency

- [ ] migrate

- [ ] notify

- [ ] object

- [ ] pqsort

- [ ] pubsub

- [ ] rio

- [ ] slowlog

- [ ] sort

- [ ] syncio

- [X] zmalloc {% post_link Redis/Redis-0x06-zmalloc的实现 %}
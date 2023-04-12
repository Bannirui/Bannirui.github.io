---
title: Redis-0x01-学习目标
date: 2023-03-23 23:40:55
index_img: /img/Redis-default.png
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

Redis主要源码都在src目录下，没有分更多的模块。结合一份网上的文件结构说明，对文件进行分类。

## 1 编码方式

| status | 文件        | 说明                                                         |
| :----: | :---------- | :----------------------------------------------------------- |
|   1    |             | OBJ_ENCODING_RAW                                             |
|   1    |             | OBJ_ENCODING_INT                                             |
|   1    | dict.c      | {% post_link Redis-0x03-dict OBJ_ENCODING_HT %}              |
|   1    | zipmap.c    | {% post_link Redis-0x06-zipmap OBJ_ENCODING_ZIPMAP %} 可能已经弃用了。 |
|   1    | adlist.c    | {% post_link Redis-0x02-list OBJ_ENCODING_LINKEDLIST %} 双链表，作为数据类型编码已经切换成quicklist，现在主要用在redisServer实例里面的双链表数据结构。 |
|   1    | ziplist.c   | {% post_link Redis-0x05-ziplist OBJ_ENCODING_ZIPLIST %}      |
|   1    | intset.c    | {% post_link Redis-0x0e-intset OBJ_ENCODING_INTSET %}        |
|   1    | t_zset.c    | {% post_link Redis-0x0f-zskiplist OBJ_ENCODING_SKIPLIST %}   |
|   1    |             | OBJ_ENCODING_EMBSTR                                          |
|   1    | quicklist.c | {% post_link Redis-0x0d-quicklist OBJ_ENCODING_QUICKLIST %} 使用ziplist存储数据的双端链表。 |
|        |             | OBJ_ENCODING_STREAM                                          |
|   1    | sds.c       | {% post_link Redis-0x04-sds 字符串。 %}                      |

## 2 数据类型

| status | 文件       | 说明                                                    |
| :----: | :--------- | :------------------------------------------------------ |
|   1    | t_string.c | {% post_link Redis-0x09-t-string OBJ_STRING 字符串。 %} |
|   1    | t_list.c   | {% post_link Redis-0x0a-t-list OBJ_LIST 列表。 %}       |
|   1    | t_set.c    | {% post_link Redis-0x0b-t-set OBJ_SET 集合。 %}         |
|   1    | t_zset.c   | {% post_link Redis-0x0c-t-zset OBJ_ZSET 有序集合。 %}   |
|   1    | t_hash.c   | {% post_link Redis-0x07-t-hash OBJ_HASH 哈希。 %}       |

## 3 数据结构

| status | struct      | 文件              | mark                    |
| ------ | ----------- | ----------------- | ----------------------- |
| 1      | redisObject | server.h\object.c | redis中数据的统一封装。 |

## 1 main主程序

| status | 文件          | 说明        |
|:------:|:------------|:----------|
|   1   | server.c     | {% post_link Redis-0x12-服务端启动流程 redis服务端。 %} |
|   0    | redis_cli.c | redis客户端。 |

## 2 net网络

| status | 文件           | 说明                    |
|:------:|:-------------|:----------------------|
|   0    | anet.c       | Server/Client通信的基础封装。 |
|   0    | networking.c | 网络协议传输方法定义。           |

## 4 event事件

| status | 文件          | 说明                      |
|:------:|:------------|:------------------------|
|   0    | ae.c        | 用于Redis的事件处理，包括句柄和超时事件。 |
|   0    | ae_epoll.c  | 实现了epoll系统调用的接口。        |
|   0    | ae_evport.c | 实现了evport系统调用的接口。       |
|   0    | ae_kqueue.c | 实现了kqueue系统调用的接口。       |
|   0    | ae_select.c | 实现了select系统调用的接口。       |

## 5 data数据操作

| status | 文件            | 说明                         |
|:------:|:--------------|:---------------------------|
|   0    | aof.c         | AOF的实现。                    |
|   0    | config.c      | 将配置文件redis.conf文件中的配置读取出来。 |
|   0    | db.c          | 对于Redis内存数据库的相关操作。         |
|   0    | multi.c       | 事务处理操作。                    |
|   0    | rdb.c         | 对于Redis本地数据库相关操作。          |
|   0    | replication.c | 主从复制操作的实现。                 |

## 6 tool工具

| status | 文件           | 说明                  |
|:------:|:-------------|:--------------------|
|   0    | bitops.c     | 位操作。                |
|   0    | debug.c      | 调试使用。               |
|   0    | endianconv.c | 高低位转换，不通系统，高低位顺序不同。 |
|   0    | help.h       | 辅助命令行的提示。           |
|   0    | lzf_c.c      | 压缩算法。               |
|   0    | lzf_d.c      | 压缩算法。               |
|   0    | rand.c       | 随机数。                |
|   0    | release.c    | 发布时使用。              |
|   0    | sha1.c       | sha加密算法。            |
|   0    | util.c       | 通用工具方法。             |
|   0    | crc64.c      | 循环冗余校验。             |

## 7 baseinfo基本信息

| status | 文件          | 说明            |
|:------:|:------------|:--------------|
|   0    | asciilogo.c | Redis的logo显示。 |
|   0    | version.h   | Redis的版本号。    |

## 8 compatible兼容

| status | 文件             | 说明        |
|:------:|:---------------|:----------|
|   0    | fmacros.h      | 兼容Mac系统。  |
|   0    | solarisfixes.h | 兼容solary。 |

## 9 wrapper封装类

| status | 文件            | 说明                       |
|:------:|:--------------|:-------------------------|
|   0    | bio.c         | background I/O，开启后台线程使用。 |
|   0    | hyperloglog.c | 高级数据结构。                  |
|   0    | intset.c      | 整数范围内的使用set。             |
|   0    | latency.c     | 延迟类。                     |
|   0    | migrate.c     | 命令迁移。                    |
|   0    | notify.c      | 通知。                      |
|   0    | object.c      | 创建和释放redisObject对象。      |
|   0    | pqsort.c      | 排序算法。                    |
|   0    | pubsub.c      | 订阅模式实现。                  |
|   0    | rio.c         | Redis定义的一个I/O类。          |
|   0    | slowlog.c     | 日志类型。                    |
|   0    | sort.c        | 排序算法                     |
|   0    | syncio.c      | 同步Socket和I/O操作。          |
|   0    | zmalloc.c     | 关于Redis的内存分配的封装实现。       |


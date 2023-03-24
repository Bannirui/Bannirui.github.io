---
title: Redis-0x01-学习目标
date: 2023-03-23 23:40:55
tags:
- Redis@6.2
categories:
- Redis
---

Redis主要源码都在src目录下，没有分更多的模块。根据一份网上的文件结构说明，跟着分类学习。

## 1 main主程序

| status | 文件    | 说明        |
| :----: | :------ | :---------- |
| 0 | redis.c | redis服务端。 |
| 0 | redis_cli.c | redis客户端。 |

## 2 net网络

| status | 文件         | 说明                          |
| :----: | :----------- | :---------------------------- |
|   0    | anet.c       | Server/Client通信的基础封装。 |
|   0    | networking.c | 网络协议传输方法定义。        |

## 3 struct结构体

| status | 文件        | 说明                                                         |
| :----: | :---------- | :----------------------------------------------------------- |
|   0    | adlist.c    | 链表。                                                       |
|   0    | dict.c      | 内存中的hash进行管理。                                       |
|   0    | sds.c       | 用于对字符串的定义。                                         |
|   0    | sparkline.c | 拥有sample列表的序列。                                       |
|   0    | t_hash.c    | hash在Server/Client中的应答操作，主要通过redisObject进行类型转换。 |
|   0    | t_list.c    | list在Server/Client中的应答操作，主要通过redisObject进行类型转换。 |
|   0    | t_set.c     | set在Server/Client中的应答操作，主要通过redisObject进行类型转换。 |
|   0    | t_string.c  | string在Server/Client中的应答操作，主要通过redisObject进行类型转换。 |
|   0    | t_zset.c    | zset在Server/Client中的应答操作，主要通过redisObject进行类型转换。 |
|   0    | ziplist.c   | ziplist是类似于list的存储对象，原理类似zipmap。              |
|   0    | zipmap.c    | zipmap是一个类似于hash的存储对象。                           |

## 4 event事件

| status | 文件        | 说明                                      |
| :----: | :---------- | :---------------------------------------- |
|   0    | ae.c        | 用于Redis的事件处理，包括句柄和超时事件。 |
|   0    | ae_epoll.c  | 实现了epoll系统调用的接口。               |
|   0    | ae_evport.c | 实现了evport系统调用的接口。              |
|   0    | ae_kqueue.c | 实现了kqueue系统调用的接口。              |
|   0    | ae_select.c | 实现了select系统调用的接口。              |

## 5 data数据操作

| status | 文件          | 说明                                       |
| :----: | :------------ | :----------------------------------------- |
|   0    | aof.c         | AOF的实现。                                |
|   0    | config.c      | 将配置文件redis.conf文件中的配置读取出来。 |
|   0    | db.c          | 对于Redis内存数据库的相关操作。            |
|   0    | multi.c       | 事务处理操作。                             |
|   0    | rdb.c         | 对于Redis本地数据库相关操作。              |
|   0    | replication.c | 主从复制操作的实现。                       |

## 6 tool工具

| status | 文件         | 说明                                   |
| :----: | :----------- | :------------------------------------- |
|   0    | bitops.c     | 位操作。                               |
|   0    | debug.c      | 调试使用。                             |
|   0    | endianconv.c | 高低位转换，不通系统，高低位顺序不同。 |
|   0    | help.h       | 辅助命令行的提示。                     |
|   0    | lzf_c.c      | 压缩算法。                             |
|   0    | lzf_d.c      | 压缩算法。                             |
|   0    | rand.c       | 随机数。                               |
|   0    | release.c    | 发布时使用。                           |
|   0    | sha1.c       | sha加密算法。                          |
|   0    | util.c       | 通用工具方法。                         |
|   0    | crc64.c      | 循环冗余校验。                         |

## 7 baseinfo基本信息

| status | 文件        | 说明              |
| :----: | :---------- | :---------------- |
|   0    | asciilogo.c | Redis的logo显示。 |
|   0    | version.h   | Redis的版本号。   |

## 8 compatible兼容

| status | 文件           | 说明          |
| :----: | :------------- | :------------ |
|   0    | fmacros.h      | 兼容Mac系统。 |
|   0    | solarisfixes.h | 兼容solary。  |

## 9 wrapper封装类

| status | 文件          | 说明                               |
| :----: | :------------ | :--------------------------------- |
|   0    | bio.c         | background I/O，开启后台线程使用。 |
|   0    | hyperloglog.c | 高级数据结构。                     |
|   0    | intset.c      | 整数范围内的使用set。              |
|   0    | latency.c     | 延迟类。                           |
|   0    | migrate.c     | 命令迁移。                         |
|   0    | notify.c      | 通知。                             |
|   0    | object.c      | 创建和释放redisObject对象。        |
|   0    | pqsort.c      | 排序算法。                         |
|   0    | pubsub.c      | 订阅模式实现。                     |
|   0    | rio.c         | Redis定义的一个I/O类。             |
|   0    | slowlog.c     | 日志类型。                         |
|   0    | sort.c        | 排序算法                           |
|   0    | syncio.c      | 同步Socket和I/O操作。              |
|   0    | zmalloc.c     | 关于Redis的内存分配的封装实现。    |


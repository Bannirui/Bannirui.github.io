---
title: RocksDB源码-0x05-WAL
category_bar: true
date: 2026-01-30 14:28:19
categories: RocksDB源码
---

wal机制的作用是防crash，在crash发生后可以进行恢复

```txt
➜  rocksdb_ctest_put tree
.
├── CURRENT
├── IDENTITY
├── LOCK
├── LOG
├── MANIFEST-000005
├── OPTIONS-000007
├── sst
│   ├── flash_path
│   │   └── 000009.sst
│   └── hard_drive
└── wal
    └── 000008.log
```

wal目录下放的是当前正在使用或者刚切换下来的wal

指定了wal目录就用指定的，没有指定就用db顶层目录放wal日志文件

wal下archive目录里面放着的是已经不再写但是暂时还不能删除的wal

`rocksdb_ldb dump_wal --walfile=wal/000004.log --header --print_value`命令dump文件


```sh
➜  rocksdb_ctest_wal rocksdb_ldb dump_wal --walfile=wal/000004.log --header --print_value
Sequence,Count,ByteSize,Physical Offset,Key(s) : value
1,1,27,0,PUT(0) : 0x68656C6C6F30 : 0x776F726C6430
2,1,27,34,PUT(0) : 0x68656C6C6F31 : 0x776F726C6431
3,1,27,68,PUT(0) : 0x68656C6C6F32 : 0x776F726C6432
4,1,27,102,PUT(0) : 0x68656C6C6F33 : 0x776F726C6433
5,1,27,136,PUT(0) : 0x68656C6C6F34 : 0x776F726C6434
6,1,27,170,PUT(0) : 0x68656C6C6F35 : 0x776F726C6435
7,1,27,204,PUT(0) : 0x68656C6C6F36 : 0x776F726C6436
8,1,27,238,PUT(0) : 0x68656C6C6F37 : 0x776F726C6437
9,1,27,272,PUT(0) : 0x68656C6C6F38 : 0x776F726C6438
10,1,27,306,PUT(0) : 0x68656C6C6F39 : 0x776F726C6439
(Column family id: [0] contained in WAL are not opened in DB. Applied default hex formatting for user key. Specify --db=<db_path> to open DB for better user key formatting if it contains timestamp.)
```

这几列内容分别表示

- 第1列 1 Sequence Number: 这是该记录的全局序列号。RocksDB里的每一条数据修改都有一个唯一的递增的序列号。它是实现快照读Snapshot Read和数据版本控制MVCC的核心。
- 第2列 1 Count: 这个记录里包含的操作数量。因为是一次Put一个Key，所以这里是1。如果用了WriteBatch批量写入，这里会显示批次内操作的总数。
- 第3列 27 Type: RocksDB内部的操作类型枚举值。27对应kTypeValue是普通的Put操作。
- 第4列 0 Offset: 该记录在WAL文件中的字节偏移量。第一条在0，第二条在34，说明每条记录含头部占用了34字节。
- 第5列 PUT(0): PUT是操作动作，括号里的0表示Column Family ID。没有创建多列族，数据默认都写在ID为0的default列族里。
- 第6列 key的16进制
- 第7列 value的16进制
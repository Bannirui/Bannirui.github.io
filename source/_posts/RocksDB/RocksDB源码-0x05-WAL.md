---
title: RocksDB源码-0x05-WAL
category_bar: true
date: 2026-01-30 14:28:19
categories: RocksDB源码
---

## 1 wal机制的作用

wal机制的作用是防crash，在crash发生后可以进行恢复。这个机制几乎在各个数据库都能见到。

## 2 wal文件目录和文件

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

## 3 wal文件格式

`rocksdb_ldb dump_wal --walfile=wal/000004.log --header --print_value`命令dump文件

```sh
➜  rocksdb_ctest_wal rocksdb_ldb dump_wal --walfile=wal/000004.log --header --print_value
Sequence,Count,ByteSize,Physical Offset,Key(s) : value
1,       1,    27,      0,     PUT(0) : 0x68656C6C6F30 : 0x776F726C6430
2,       1,    27,      34,    PUT(0) : 0x68656C6C6F31 : 0x776F726C6431
3,       1,    27,      68,    PUT(0) : 0x68656C6C6F32 : 0x776F726C6432
4,       1,    27,      102,   PUT(0) : 0x68656C6C6F33 : 0x776F726C6433
5,       1,    27,      136,   PUT(0) : 0x68656C6C6F34 : 0x776F726C6434
6,       1,    27,      170,   PUT(0) : 0x68656C6C6F35 : 0x776F726C6435
7,       1,    27,      204,   PUT(0) : 0x68656C6C6F36 : 0x776F726C6436
8,       1,    27,      238,   PUT(0) : 0x68656C6C6F37 : 0x776F726C6437
9,       1,    27,      272,   PUT(0) : 0x68656C6C6F38 : 0x776F726C6438
10,      1,    27,      306,   PUT(0) : 0x68656C6C6F39 : 0x776F726C6439
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

## 4 wal的过程

### 4.1 wal回放前置准备

#### 4.1.1 准备全量CF的VersionEdit容器

```cpp
  for (auto cfd : *versions_->GetColumnFamilySet()) {
    // 给每个CF都准备一个VersionEdit壳子 如果在wal过程中发生了sst变更就更新这个VersionEdit 最终wal结束 这个VersionEdit就是wal过程中的增量
    VersionEdit edit;
    edit.SetColumnFamily(cfd->GetID());
    version_edits->insert({cfd->GetID(), edit});
  }
```

#### 4.1.2 wal日志最小的文件编号要求

##### 4.1.2.1 系统级的wal要求下限

```cpp
/**
 * 这是系统级的wal要求下限 保证memory table恢复一致+事务完整
 * wal的编号要求分系统级要求和数据安全级要求两个
 * 1 系统级要求比数据安全级的高 也就是系统级的wal编号小于数据安全级别的wal编号
 * 2 数据安全级的wal编号只能用来做memory table恢复一致性
 * 3 系统级别的wal编号还可以用不保证事务语义保证
 *
 * 1 如果wal日志删除早了 会导致数据永久丢失
 * 2 如果wal日志删除晚了 会导致数据冗余在磁盘上浪费磁盘空间
 * 本质是支撑着未flush数据的最早wal
 * 只要一个wal对应的数据已经flush成sst并且被Version管理了那么这个wal就不用再参与到恢复
 * @return 系统crash后 为了恢复到一致状态+事务状态完整 必须保留的最早的wal日志
 */
uint64_t DBImpl::MinLogNumberToKeep() {
  return versions_->min_log_number_to_keep();
}
```

##### 4.1.2.2 数据安全级的wal要求下限

```cpp
  /**
   * wal恢复memory table的要求下限 这是数据安全级别的要求 能保证的是恢复memory table的一致性 这个要求是宽泛的
   * 如果是事务的两阶段提交 那么就要更严格的系统级的要求下限 保证memory table恢复一致+事务完整
   * 
   * 为什么这个地方要讨论两阶段提交
   * wal的唯一用途就是恢复memory table 也就意味着一旦memory table里面的数据flush到了sst文件 wal文件的使命就完成了可以删除了
   * 两阶段提交的时候
   * 1 prepare阶段写入了wal
   * 2 此时还没完成commit所以数据对外是不可见的
   * 3 commit可能在未来的wal中
   * 所以如果只从memory table有没有flush到sst来判定wal可不可以删除 会导致prepare了还没commit的数据丢失 导致事务语义被破坏
   * 所以在两阶段提交模式下 wal的用途不单单是保证memory table能恢复一致 还用于事务状态机的恢复
   * 所以在两阶段下wal日志要更严格
   */
  uint64_t MinLogNumberWithUnflushedData() const {
    return PreComputeMinLogNumberWithUnflushedData(nullptr);
  }
```

### 4.2 WriteBatch逻辑协议

一旦从wal文件里面读到内容，就涉及到两层协议的解析

- 1 物理层协议 这个就是{%post_link RocksDB/RocksDB源码-0x0F-日志记录%}
- 2 逻辑层协议 {%post_link RocksDB/RocksDB源码-0x10-wal的WriteBatch协议%}
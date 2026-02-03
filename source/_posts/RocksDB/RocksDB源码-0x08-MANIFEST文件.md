---
title: RocksDB源码-0x08-MANIFEST文件
category_bar: true
date: 2026-01-30 14:32:42
categories: RocksDB源码
---

## 1 manifest是什么

核心元数据，它的内容是二进制的，本质是VersionEdit的顺序日志，而每个VersionEdit是描述一次元数据的变更，比如

- 新建sst文件
- 删除sst文件
- flush
- compaction
- 新建cf

manifest文件记录的本质是在某个时刻

- 当前数据库结构中，哪些sst文件是被认为是有效的
- 以及这些sst文件是在什么样的wal边界条件下生成的 换言之 当前version生效时需要回放的wal是log number之后的wal日志

## 2 dump出来的manifest内容

用`rocksdb_ldb manifest_dump --db=/tmp/rocksdb_ctest_put`或者`rocksdb_ldb manifest_dump --path=MANIFEST-000005`命令dump某个文件

```sh
➜  rocksdb_ctest_put rocksdb_ldb manifest_dump --path=MANIFEST-000005
--------------- Column family "default"  (ID 0) --------------
log number: 8
comparator: leveldb.BytewiseComparator
--- level 0 --- version# 1 ---
 9:1374[1 .. 10]['hello0' seq:1, type:1 .. 'hello9' seq:10, type:1]
--- level 1 --- version# 1 ---
--- level 2 --- version# 1 ---
--- level 3 --- version# 1 ---
--- level 4 --- version# 1 ---
--- level 5 --- version# 1 ---
--- level 6 --- version# 1 ---
--- level 7 --- version# 1 ---
--- level 8 --- version# 1 ---
--- level 9 --- version# 1 ---
--- level 10 --- version# 1 ---
--- level 11 --- version# 1 ---
--- level 12 --- version# 1 ---
--- level 13 --- version# 1 ---
--- level 14 --- version# 1 ---
--- level 15 --- version# 1 ---
--- level 16 --- version# 1 ---
--- level 17 --- version# 1 ---
--- level 18 --- version# 1 ---
--- level 19 --- version# 1 ---
--- level 20 --- version# 1 ---
--- level 21 --- version# 1 ---
--- level 22 --- version# 1 ---
--- level 23 --- version# 1 ---
--- level 24 --- version# 1 ---
--- level 25 --- version# 1 ---
--- level 26 --- version# 1 ---
--- level 27 --- version# 1 ---
--- level 28 --- version# 1 ---
--- level 29 --- version# 1 ---
--- level 30 --- version# 1 ---
--- level 31 --- version# 1 ---
--- level 32 --- version# 1 ---
--- level 33 --- version# 1 ---
--- level 34 --- version# 1 ---
--- level 35 --- version# 1 ---
--- level 36 --- version# 1 ---
--- level 37 --- version# 1 ---
--- level 38 --- version# 1 ---
--- level 39 --- version# 1 ---
--- level 40 --- version# 1 ---
--- level 41 --- version# 1 ---
--- level 42 --- version# 1 ---
--- level 43 --- version# 1 ---
--- level 44 --- version# 1 ---
--- level 45 --- version# 1 ---
--- level 46 --- version# 1 ---
--- level 47 --- version# 1 ---
--- level 48 --- version# 1 ---
--- level 49 --- version# 1 ---
--- level 50 --- version# 1 ---
--- level 51 --- version# 1 ---
--- level 52 --- version# 1 ---
--- level 53 --- version# 1 ---
--- level 54 --- version# 1 ---
--- level 55 --- version# 1 ---
--- level 56 --- version# 1 ---
--- level 57 --- version# 1 ---
--- level 58 --- version# 1 ---
--- level 59 --- version# 1 ---
--- level 60 --- version# 1 ---
--- level 61 --- version# 1 ---
--- level 62 --- version# 1 ---
--- level 63 --- version# 1 ---
By default, manifest file dump prints LSM trees as if 64 levels were configured, which is not necessarily true for the column family (CF) this manifest is associated with. Please consult other DB files, such as the OPTIONS file, to confirm.
next_file_number 11 last_sequence 10  prev_log_number 0 max_column_family 0 min_log_number_to_keep 8
```

上面dump出来的内容有哪些信息

- 1 列簇名叫default，对应的id是0，系统内部引用的都是id
- 2 log number=最近的一个被持久化的wal编号，等于8，意味着小于等于8的wal都已经持久化了，大于8的在crush时还没flush，需要replay
- 3 comparator 是在建库的时候就定下的，不能更改，表示key的排序规则
- 4 version#是内部递增的版本号，每次flush和compaction都会生成新的version版本号
- 5 level 0 表示sst在第几层
- 6 sst文件行
  - 9 文件编号 表示sst文件的编号 也就是sst文件名和后缀
  - 1374 文件大小 sst文件有多少个字节
  - [1..10] sst覆盖的自增区间
  - ['hello0' seq:1, type:1 .. 'hello9' seq:10, type:1] key的范围
  - type:1 表示value的类型 1表示Put
  
简而言之，manifest告诉我们每个cf在每一层有哪些sst文件，每个sst文件key range状态

## 3 manifest的用途

manifest的目的就是为了有能力重建VersionSet {%post_link RocksDB/RocksDB源码-0x0C-Version%}，而VersionSet保证了RocksDB索引key分布在具体哪个SST文件的能力 {%post_link RocksDB/RocksDB源码-0x0B-数据存在什么地方%}
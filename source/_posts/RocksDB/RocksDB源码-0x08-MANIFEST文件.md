---
title: RocksDB源码-0x08-MANIFEST文件
category_bar: true
date: 2026-01-30 14:32:42
categories: RocksDB源码
---

核心元数据，它的内容是二进制的

作用有两个

- 1 VersionEdit的WAL
- 2 SST元信息的真相来源

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
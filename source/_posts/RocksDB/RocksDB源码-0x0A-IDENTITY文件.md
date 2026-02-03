---
title: RocksDB源码-0x10-IDENTITY文件
category_bar: true
date: 2026-01-30 15:00:13
categories: RocksDB源码
---

```sh
➜  rocksdb_ctest_put cat IDENTITY
df88aee2-5088-4b2b-9b56-be71f7b8cdc4%
```

记录的内容是DB的唯一UUID

作用是

- 1 备份
- 2 replication
- 3 防止误挂载
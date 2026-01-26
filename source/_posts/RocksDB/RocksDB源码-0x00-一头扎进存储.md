---
title: RocksDB源码-0x00-一头扎进存储
category_bar: true
date: 2026-01-26 11:11:10
categories: RocksDB源码
---

## 1 源码

```sh
git clone git@github.com:Bannirui/rocksdb.git
cd rocksdb
git remote add upstream git@github.com:facebook/rocksdb.git
git remote set-url --push upstream no_push
git remote -v
git checkout -b my_study
```

## 2 编译

用cmake管理项目，默认情况下报错找不到`gflags`

在Cmake的Options中添加`-DWITH_GFLAGS=OFF`

## 3 学习规划

- [ ] 入口API
- [ ] 核心调度
- [ ] Write Path
- [ ] Flush
- [ ] Read Path
- [ ] LSM的核心Compaction
- [ ] Version
---
title: RocksDB源码-0x07-CURRENT文件
category_bar: true
date: 2026-01-30 14:31:21
categories: RocksDB源码
---

于RocksDB而言，这个文件至关重要，在进行深入这个文件的作用之前需要先了解{%post_link RocksDB/RocksDB源码-0x08-MANIFEST文件%}

它的作用是指向当前正在生效的MANIFEST文件

看一下这个文件的内容是啥

```sh
➜  rocksdb_ctest_put cat CURRENT
MANIFEST-000005
```

它只干一件事情，就是记录当前有效的MANIFEST文件名

提供一个crash-safe的原子指针
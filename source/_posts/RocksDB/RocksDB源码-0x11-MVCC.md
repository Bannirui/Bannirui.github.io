---
title: RocksDB源码-0x11-MVCC
category_bar: true
date: 2026-02-11 13:50:05
categories: RocksDB源码
---

在{%post_link RocksDB/RocksDB源码-0x05-WAL%}里面有put record的批量处理，当时提出过如果中间过程出现异常，怎么保证原子性的。



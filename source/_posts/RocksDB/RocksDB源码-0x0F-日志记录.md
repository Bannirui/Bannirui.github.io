---
title: RocksDB源码-0x0F-日志记录
category_bar: true
date: 2026-02-04 13:29:05
categories: RocksDB源码
---

在RocksDB世界，两个重要的文件

- wal {%post_link RocksDB/RocksDB源码-0x05-WAL%}
- manifest {%post_link RocksDB/RocksDB源码-0x08-MANIFEST文件%}

本质都是日志文件，因此抽象成统一的日志进行读写

## 1 wal
### 1.1 读
### 1.2 写

## 2 manifest

### 2.1 读

在{%post_link RocksDB/RocksDB源码-0x0C-Version%}读manifest重建VersionSet的时候读一个一个日志记录内容

```cpp
  /**
   * manifest的回放主循环
   * 3个条件
   * 1 防止manifest文件损坏导致的无限读下去
   * 2 任何一步有问题都停止读
   * 3 是按record为单位读的 不是按照行 因为manifest不是普通的文本文件 是有格式的文件
   * 4 防止Reader内部有错误
   */
  while (reader.LastRecordEnd() < max_manifest_read_size_ && s.ok() &&
         reader.ReadRecord(&record, &scratch) && log_read_status->ok())
```

### 2.2 写


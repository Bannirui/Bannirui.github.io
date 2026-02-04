---
title: RocksDB源码-0x0C-Version
category_bar: true
date: 2026-02-03 13:22:14
categories: RocksDB源码
---

## 1 什么是Version

{%post_link RocksDB/RocksDB源码-0x08-MANIFEST文件%} 配合manifest中的内容看更直观

RocksDB两手抓，一手抓没持久化的数据在内存，一手抓持久化的数据在SST，回放内存数据靠wal，溯源数据在SST的分布情况也需要一个机制，一类比wal就唤出了VersionSet。

从某个具体的CF视角看，它的每次SST变更就会产生一个VersionEdit，一群VersionEdit组成的概念就是这个CF的Version。再把视角扩大到所有CF，就形成了VersionSet。

通过VersionSet，RocksDB就能拿着key定位到这个key在哪个sst文件里面。

## 2 盘点VersionSet

![](./RocksDB源码-0x0C-Version/1770100102.png)

## 3 VersionSet的代码结构

### 3.1 构造DB的时候构建默认的VersionDB对象

```cpp
  versions_.reset(new VersionSet(
      dbname_, &immutable_db_options_, mutable_db_options_, file_options_,
      table_cache_.get(), write_buffer_manager_, &write_controller_,
      &block_cache_tracer_, io_tracer_, db_id_, db_session_id_,
      options.daily_offpeak_time_utc, &error_handler_, read_only));
```

### 3.2 ColumnFamilySet

在VersionSet的构造函数中也会构造个默认的column_family_set

```cpp
    : column_family_set_(new ColumnFamilySet(
          dbname, _db_options, storage_options, table_cache,
          write_buffer_manager, write_controller, block_cache_tracer, io_tracer,
          db_id, db_session_id)),
```

### 3.3 CF的映射

在ColumnFamilySet通过map映射CF的信息

```cpp
  // 列簇名字映射到列簇编号
  UnorderedMap<std::string, uint32_t> column_families_;
  // 列簇编号映射到列簇 在列簇的信息里面有个current指针 这个指针指向当前列最新的Version链表结点
  UnorderedMap<uint32_t, ColumnFamilyData*> column_family_data_;
```

### 3.4 CF怎么找到自己的Version

在上面ColumnFamilySet里面根据CF的编号索引到ColumnFamilyData后，在Data里面用current指针指向自己的Version

```cpp
  // 列簇的Version链表 这个current指针指向的是在链表中最新的 也就是链表尾的结点 每个Version链表结点就是真实的每次的VersionEdit
  Version* current_;         // == dummy_versions->prev_
```

### 3.5 Version的结构

Version的数据结构是双链表

```cpp
  // 对SST的变更生成了一次VersionEdit 在时间序上形成双链表结构 每次有新生成一个VersionEdit就串到链表尾 然后把CF里面的current指针指过来
  Version* next_;     // Next version in linked list
  Version* prev_;     // Previous version in linked list
```

## 4 启动的时候从manifest构建恢复VersionSet

VersionSet中有个函数Recover负责从manifest文件中重建VersionSet

### 4.1 从CURRENT里面看看MANIFEST是哪个

```cpp
  // 从CURRENT文件中拿到当前的manifest文件名
  std::string manifest_path;
  Status s = GetCurrentManifestPath(dbname_, fs_.get(), is_retry,
                                    &manifest_path, &manifest_file_number_);
```

{%post_link RocksDB/RocksDB源码-0x07-CURRENT文件%}
{%post_link RocksDB/RocksDB源码-0x08-MANIFEST文件%}

### 4.2
### 4.3
### 4.4

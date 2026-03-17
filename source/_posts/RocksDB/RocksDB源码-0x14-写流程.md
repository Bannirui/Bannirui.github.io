---
title: RocksDB源码-0x14-写流程
category_bar: true
categories: RocksDB源码
date: 2026-02-13 13:26:42
---

## 1 测试代码

```cpp
int main() {
  rocksdb::Options options;
  options.create_if_missing = true;

  // 不在options中显式制定wal的目录就会用db_path
  std::string dbName = "/tmp/rocksdb_ctest_put";
  std::string walDir = dbName + "/wal";
  std::string sstDir = dbName + "/sst";
  options.wal_dir = walDir;
  std::vector<rocksdb::DbPath> sstPaths = {{sstDir + "/flash_path", 512},
                                           {sstDir + "/hard_drive", 1024}};
  options.db_paths = sstPaths;

  // sst目录属于资源目录 RocksDB不会帮我创建 要自己创建好
  auto* env = rocksdb::Env::Default();
  env->CreateDirIfMissing(dbName);
  env->CreateDirIfMissing(walDir);
  env->CreateDirIfMissing(sstDir);
  env->CreateDirIfMissing(sstDir + "/flash_path");
  env->CreateDirIfMissing(sstDir + "/hard_drive");

  std::unique_ptr<rocksdb::DB> db;
  auto s = rocksdb::DB::Open(options, dbName, &db);
  assert(s.ok());

  db->Put(rocksdb::WriteOptions(), "hello", "world");
  return 0;
}
```

## 2 WriteBatch协议编码

首先把键值对编码，见{%post_link RocksDB/RocksDB源码-0x10-WriteBatch协议%}

## 3 RocksDB的写并发控制

见{%post_link RocksDB/RocksDB源码-0x16-WriteThread串行执行器%}
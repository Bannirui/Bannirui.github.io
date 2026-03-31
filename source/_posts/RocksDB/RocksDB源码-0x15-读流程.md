---
title: RocksDB源码-0x15-读流程
category_bar: true
categories: RocksDB源码
date: 2026-02-13 13:26:55
---

## 1 测试代码

```cpp
int main() {
  rocksdb::Options options;
  options.create_if_missing = true;

  // 不在options中显式制定wal的目录就会用db_path
  std::string dbName = "/tmp/rocksdb_ctest_read";
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
  // 写
  s = db->Put(rocksdb::WriteOptions(), "hello", "world");
  assert(s.ok());
  // 读
  std::string val;
  s = db->Get(rocksdb::ReadOptions(), "hello", &val);
  assert(s.ok());
  std::cout<<"key=hello, value="<<val<<std::endl;
  return 0;
}
```

## 2 关于字符串

```cpp
  virtual inline Status Get(const ReadOptions& options,
                            ColumnFamilyHandle* column_family, const Slice& key,
                            std::string* value) final {
    assert(value != nullptr);
    // 构造字符串的安全视图
    PinnableSlice pinnable_val(value);
    assert(!pinnable_val.IsPinned());
    auto s = Get(options, column_family, key, &pinnable_val);
    if (s.ok() && pinnable_val.IsPinned()) {
      // 把内容从安全视图拷贝出来 为什么要在这个地方显式复制 因为不确定字符串有没有发生pin
      // 1 发生了pin 也就是发生了zero-copy 那么实际的数据写到的位置并不是value的内存 需要拷贝出来
      // 2 没有发生pin 也就是没有发生zero-copy 那么实际的数据写到的位置就是value的内存 不需要拷贝
      // 所以综合起来 用一次显式的拷贝是最妥当的
      value->assign(pinnable_val.data(), pinnable_val.size());
    }  // else value is already assigned
    return s;
  }
```

虽然用的是std::string，名称叫string，但是不能只是狭隘地理解成字符串，而是字节序列。针对string，RocksDB有两个自己的场景优化

- 一是性能优化{%post_link RocksDB/RocksDB源码-0x17-字符串性能优化Slice%}
- 二是安全性的优化{%post_link RocksDB/RocksDB源码-0x18-字符串安全性优化PinnableSlice%}

## 3

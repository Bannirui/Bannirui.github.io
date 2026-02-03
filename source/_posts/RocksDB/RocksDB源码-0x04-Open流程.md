---
title: RocksDB源码-0x04-Open流程
category_bar: true
date: 2026-01-29 13:45:30
categories: RocksDB源码
---

## 1 调试代码

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

  for (int i = 0; i < 10; ++i) {
    s = db->Put(rocksdb::WriteOptions(), "hello" + std::to_string(i),
                "world" + std::to_string(i));
  }
  std::string value;
  // get value
  s = db->Get(rocksdb::ReadOptions(), "hello", &value);

  db->Flush(rocksdb::FlushOptions());

  return 0;
}
```

## 2 安装必要的工具用来解析文件

直接在主机上安装rocksdb，在解析文件的时候要用到这些自带的工具

```sh
brew install rocksdb

ls $(brew --prefix rocksdb)/bin
```

## 3 启动前准备重要的目录文件

上面代码运行完会生成下面的这些文件

```txt
➜  rocksdb_ctest_put tree
.
├── CURRENT
├── IDENTITY
├── LOCK
├── LOG
├── MANIFEST-000005
├── OPTIONS-000007
├── sst
│   ├── flash_path
│   │   └── 000009.sst
│   └── hard_drive
└── wal
    └── 000008.log
```

![](./RocksDB源码-0x04-Open流程/1769755175.png)

- wal日志 {%post_link RocksDB/RocksDB源码-0x05-WAL%}
- sst {%post_link RocksDB/RocksDB源码-0x06-SST%}
- current文件 {%post_link RocksDB/RocksDB源码-0x07-CURRENT文件%}
- manifest文件 {%post_link RocksDB/RocksDB源码-0x08-MANIFEST文件%}
- options文件 {%post_link RocksDB/RocksDB源码-0x09-OPTIONS文件%}
- IDENTITY文件 {%post_link RocksDB/RocksDB源码-0x0A-IDENTITY文件%}
- LOG文件是RocksDB自己的运行日志
- LOCK 这是一个空文件，作用是当作一个互斥锁，防止两个RocksDB实例同时打开同一个db

## 4 用磁盘上的文件恢复内存结构状态

上面的这些目录和文件中，都会多多少少存在着数据，RocksDB需要用这些数据来恢复态，本质上恢复的不仅仅是数据本身，而是恢复如何解释数据

### 4.1 manifest重建VersionSet

{%post_link RocksDB/RocksDB源码-0x08-MANIFEST文件%}

### 4.2 wal重建内存数据库

{%post_link RocksDB/RocksDB源码-0x05-WAL%}
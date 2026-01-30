---
title: RocksDB源码-0x06-SST
category_bar: true
date: 2026-01-30 14:28:37
categories: RocksDB源码
---

sst目录如果指定了就用指定的，没有指定的话就把sst文件放在db顶层目录里面

存储KV数据，存放的是真正的数据

```cpp
  std::vector<rocksdb::DbPath> sstPaths = {{sstDir + "/flash_path", 512},
                                           {sstDir + "/hard_drive", 1024}};
```

sst文件放在哪个目录不是随机的，比如上面我设置了两个路径可以放sst文件，RocksDB就会按照这个顺序来放，能放下就放，放不下就放到下一个里面，要是都满了就会写失败

用`rocksdb_sst_dump --file=sst/flash_path/000009.sst --command=scan`命令查询sst文件

```sh
➜  rocksdb_ctest_put rocksdb_sst_dump --file=sst/flash_path/000009.sst --command=scan
options.env is 0x600000256300
Process sst/flash_path/000009.sst
Sst file format: block-based
from [] to []
'hello0' seq:1, type:1 => world0
'hello1' seq:2, type:1 => world1
'hello2' seq:3, type:1 => world2
'hello3' seq:4, type:1 => world3
'hello4' seq:5, type:1 => world4
'hello5' seq:6, type:1 => world5
'hello6' seq:7, type:1 => world6
'hello7' seq:8, type:1 => world7
'hello8' seq:9, type:1 => world8
'hello9' seq:10, type:1 => world9
```
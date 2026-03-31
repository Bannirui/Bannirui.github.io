---
title: RocksDB源码-0x17-字符串性能优化Slice
category_bar: true
categories: RocksDB源码
date: 2026-03-31 10:20:39
---

string从本质上讲就是一个字节序列，为了避免拷贝开销，就封装了一个结构-字节序列的视图

Slice的成员非常简单

- 字节序列的内存地址
- 字节序列的大小

```cpp
  // 我认为Slice要持有字符串指针而不是引用或值有两个原因
  // 1 指针占内存小 避免拷贝开销
  // 2 可以直接操作 也是主要原因 因为在编解码层面操作的就是Slice 需要有能力编解码完一个字节就丢掉一个字节 达到流式效果
  // 本质是为了zero-copy的性能
  const char* data_; // 字节序列的内存地址
  size_t size_; // 字节序列多大 有几个字节
```
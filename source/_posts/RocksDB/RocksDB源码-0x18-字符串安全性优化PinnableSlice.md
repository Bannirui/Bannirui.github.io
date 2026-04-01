---
title: RocksDB源码-0x18-字符串安全性优化PinnableSlice
category_bar: true
categories: RocksDB源码
date: 2026-03-31 10:23:39
---

有了{%post_link RocksDB/RocksDB源码-0x17-字符串性能优化Slice%}解决性能问题后，现在面临着的是资源所有权的问题，Slice没有能力对内存生命周期管理，所以PinnableSlice相较于Slice是多了内存资源的管理权。

## 1 状态模型

```cpp
  std::string self_space_;
  std::string* buf_;
  /**
   * PinnableSlice有别于{@link Slice}的主要点是所有权
   * 两个所有权模型
   * 1 pinned=true 我不拥有数据但是我锁住它 外部托管生命周期 数据在RocksDB内部但通过pin引用计数把它锁住 也就是说数据不是我的但是我控制什么时候释放它
   * 2 pinned=false buf=&self_space 我拥有数据 数据被memcpy到self_space 生命周期完全由自己控制 也就是说数据是我的 别人管不着
   * 3 buf=nullptr 没有数据 我现在啥也没有
   */
  bool pinned_ = false;
```
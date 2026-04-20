---
title: RocksDB源码-0x19-列簇的快照
category_bar: true
categories: RocksDB源码
date: 2026-04-20 10:23:11
---

## 1 结构和布局

![](./RocksDB源码-0x19-列簇的快照/1776652517.png)

这个类重要的成员有4个

```cpp
/**
 * 这个组件的作用 拿到某个时刻DB的读视图的原子打包
 * 拿到了3大组件的快照版本
 * 因为3个组件是分别独立进行数据更新的
 *   1 写入会替换mem
 *   2 flush会改变冻结mem
 *   3 compaction会改变version
 * 如果没有SuperVersion的话 分别去拿这3个组件的指针 很容易拿到状态不一致的数据
 * 所以要把3个组件的数据绑定成一个不可以改变的快照
 * SuperVersion的重要性
 *   1 无锁读
 *   2 一致性保证不会读到一半数据结构发生变化
 *   3 生命周期安全 引用计数保证内存资源不会在读的过程中被回收
 */
struct SuperVersion {
  ReadOnlyMemTable* mem; // 当前写入表 正在写的内存表
  MemTableListVersion* imm; // 冻结的MemTable 已经停止写入等待flush到SST
  Version* current; // SST文件视图 levels+files

  // 引用计数 保证在使用过程中 不至于发生内存被回收的情况
  std::atomic<uint32_t> refs;
}
```

## 2
## 3

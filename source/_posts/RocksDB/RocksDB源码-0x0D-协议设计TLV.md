---
title: RocksDB源码-0x0D-协议设计TLV
category_bar: true
date: 2026-02-04 10:45:06
categories: RocksDB源码
---

说起协议设计，这个话题我以前没有过深的思考。协议的方案选择很多，选哪个从来不是简单的喜好，一般是多个维度比较取舍的结果。

## 1 考虑的维度

比如说我现在要设计协议，就要先问上自己几个问题

- 是不是需要跨语言
- 是不是需要长期存储
- 是不是需要前向/后向兼容
- 是不是需要高频访问的对性能敏感的
- 是不是需要schema
- 是不是需要人类可读的

## 2 不同的方案

- 2.1 TLV 纯二进制+自定义编码
  - 代表
    - RocksDB VersionEdit
    - LevelDB
    - SQLite
    - MySQL redo log
    - Kafka log
  - 特点
    - 自定义write format
    - TLV或者TVL的变体
  - 优点
    - 极致性能
    - 极致空间效率
    - 完全可控
    - 最强前向兼容
  - 缺点
    - 人肉维护
    - 开发成本高
    - 容易出bug
    - 几乎没有工具链
  - 场景
    - 底层系统
    - 内部协议
    - 长期存储
    - 热路径
- 2.2 接口定义语言IDL驱动的二进制协议
  - 代表
    - Protobuf
    - Thrift
    - Avro
    - FlatBuffers
  - 特点
    - 有Schema
    - 自动生成代码
    - 多语言支持
  - 优点
    - 开发效率高
    - 跨语言
    - 工具丰富
  - 缺点
    - write format不完全可控
    - 兼容性有规则限制
    - 依赖runtime
    - 热路径性能不如手写TLV
  - 场景
    - RPC
    - 服务通信
    - 中间层存储
    - 团队协作
- 2.3 自描述数据格式
  - 代表
    - JSON
    - XML
    - YAML
  - 特点
    - 文本
    - 自描述
    - 人类可读
  - 优点
    - 调试友好
    - 灵活
    - 无schema也能用
  - 缺点
    - 慢
    - 大
    - 类型弱
    - 歧义多
  - 场景
    - 配置
    - 控制面
    - 低频交互
- 2.4 列式/批量格式
  - 代表
    - Parquet
    - ORC
    - Arrow
  - 特点
    - 面向列
    - schema强
    - 批处理
  - 场景
    - 分析
    - OLAP
    - 离线

## 3 TLV

RocksDB这种底层的存储引擎，从空间/性能/兼容性/数据长期存储，这几个方面，协议设计肯定选择TLV。什么是TLV

![](./RocksDB源码-0x0D-协议设计TLV/1770174616.png)

```cpp
  /**
   * manifest的VersionEdit 一个日志记录里面会有很多的tag-value 必须保证所有的tag-value都能成功解析
   * 用msg记录解析失败的tag-value是谁 但凡有一个解析失败就返回失败
   */
  while (msg == nullptr && GetVarint32(&input, &tag)) {
#ifndef NDEBUG
    if (ignore_ignorable_tags && tag > kTagSafeIgnoreMask) {
      tag = kTagSafeIgnoreMask;
    }
#endif
    // 拿到tag这个整数 tag不同value的解析也不同
    switch (tag) {
      case kDbId:
        if (GetLengthPrefixedSlice(&input, &str)) {
          /**
           * 这个就是标准的显式的TLV
           * 1 tag是整数 先拿到tag
           * 2 紧随的也是一个整数表示length
           * 3 知道了value的长度就顺着拿出value
           */
          db_id_ = str.ToString();
          has_db_id_ = true;
        } else {
          msg = "db id";
        }
        break;
```

短短几行代码就是一个tag的处理，每添加或者扩展一个tag，无非就是多一个switch分支的事情

上面代码最重要的两个函数

- GetVarint32
- GetLengthPrefixedSlice

这里面体现的就是RocksDB的编解码 {%post_link RocksDB/RocksDB源码-0x0E-编解码%}

## 4 怎么做的前向兼容

### 4.1 不认识的tag预处理

```cpp
    if (ignore_ignorable_tags && tag > kTagSafeIgnoreMask) {
      // 这个地方是前向兼容的技巧 设置个分水岭 看到不认识的tag就打成固定标识 留给下面default分支处理
      tag = kTagSafeIgnoreMask;
    }
```

### 4.2 配合主循环的default分支专门处理不认识的tag

前提是必须显式有L(length)的TVL，处理方式就是跳过不要

```cpp
      default:
        // 很巧妙的前向兼容处理方式 如果是老代码 前面拿到了tag判断超出了分水岭就会被赋值kTagSafeIgnoreMask 此时第13位被打上1保证进if分支
        if (tag & kTagSafeIgnoreMask) {
          // Tag from future which can be safely ignored.
          // The next field must be the length of the entry.
          // 能被兼容的一定是显式TLV的格式 也就是L不能少的范式
          // 拿到了不认识的tag 顺着tag拿出整数就认为是它的length 然后丢掉length对应的value 这么操作就等于是跳过了不认识的tag 做到了前向兼容
          uint32_t field_len;
          if (!GetVarint32(&input, &field_len) ||
              static_cast<size_t>(field_len) > input.size()) {
            if (!msg) {
              msg = "safely ignoreable tag length error";
            }
          } else {
            input.remove_prefix(static_cast<size_t>(field_len));
          }
        } else {
          msg = "unknown tag";
        }
        break;
```
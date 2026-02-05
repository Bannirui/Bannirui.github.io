---
title: RocksDB源码-0x0E-编解码
category_bar: true
date: 2026-02-04 13:10:50
categories: RocksDB源码
---

{%post_link RocksDB/RocksDB源码-0x0D-协议设计TLV%}说过TLV的协议设计，编解码也是一种协议设计，它是字节层面的而已。

在TLV协议设计的时候最多的就两个场景

- 1 只有tag，隐式length，在RocksDB里面tag就是枚举`enum Tag : uint32_t`
- 2 有tag/length/value，这个length约定的是32位数字

所以可以看得出来，高频使用的就是数字和字符串，而数字的使用又有特点

- 1 32位长度的数字覆盖面最广
- 2 会有特定场景对64位长度数字有需要
- 3 数字大部分是小数字，但上限高，比如wal日志文件编号或者sst文件编号

以32位数字为例，声明为int占4字节，这样不管数字大小都占4字节。但是因为实际使用大部分都是小数字，所以并不需要占满4字节就可以表达出来，另一方面上限高，得满足数字上限的要求。所以综合来看，自定义编码用变长数字替代定长数字可以省下来很大的空间。

## 1 32位数字的编解码

### 1.1 编码

```cpp
/**
 * 32位定长数字编码变长数字
 * @param dst 放编码结果
 * @param v 要编码的数字
 */
inline void PutVarint32(std::string* dst, uint32_t v) {
  // 对于32位长度的数字 每7位占1字节 最多编码占5字节
  char buf[5];
  // 数字v编码放到buf里面 编完后ptr指向的是编码结果的下一个位置 目的是要知道编码结果的长度是几个字节
  char* ptr = EncodeVarint32(buf, v);
  // ptr-buf拿到编码结果是几个字节 放到dst里面
  dst->append(buf, static_cast<size_t>(ptr - buf));
}
```

处理方式很简单，就是把定长数字每7位编到变长数字的8位里面

```cpp
/**
 * 底层的编码方式 是序列化/反序列化的基石
 * 定长32位的整数编成变长
 * 对于每个字节 低7位放数据 最高位放标识 1标识后面还有字节
 * 0标识这个最后一个字节后面没有了 小端序的方式
 * 编成一个整数最多会用5个字节
 * @return 编完后的一下位置
 */
char* EncodeVarint32(char* dst, uint32_t v) {
  // Operate on characters as unsigneds
  unsigned char* ptr = reinterpret_cast<unsigned char*>(dst);
  // 二进制1000 0000 就是高第7位的标识1 表示后面还有字节
  static const int B = 128;
  if (v < (1 << 7)) {
    // 7bit能放下 就把数据放在抵7位上 最高位0
    // 先解引用把数据写进去再移动指针
    *(ptr++) = v;
  } else if (v < (1 << 14)) {
    // 2字节能放下
    // 第1个字节放下数据的低7位 第1个字节的最高位放1 表示还有后续
    // 第2个字节放数据刨去7位的高位 第2字节最高位放0
    *(ptr++) = v | B;
    *(ptr++) = v >> 7;
  } else if (v < (1 << 21)) {
    // 3个字节能放下
    // 第1个字节低7位放数据的低7位 第1个字节最高位放1表示还有后续
    *(ptr++) = v | B;
    // 第2个字节低7位放数据刨去7位后的低7位 第2个字节最高位放1表示还有后续
    *(ptr++) = (v >> 7) | B;
    // 第3个字节低7位放数据刨去14位后的低7位 第3个字节最高位放0表示没有后续了
    *(ptr++) = v >> 14;
  } else if (v < (1 << 28)) {
    // 4个字节能放下
    *(ptr++) = v | B;
    *(ptr++) = (v >> 7) | B;
    *(ptr++) = (v >> 14) | B;
    *(ptr++) = v >> 21;
  } else {
    // 用5个字节编码
    *(ptr++) = v | B;
    *(ptr++) = (v >> 7) | B;
    *(ptr++) = (v >> 14) | B;
    *(ptr++) = (v >> 21) | B;
    *(ptr++) = v >> 28;
  }
  return reinterpret_cast<char*>(ptr);
}
```

### 1.2 解码

```cpp
/**
 * 解码
 * @param input 要解码的对象 二进制 边解码边把解完的丢掉 最后拿到的是剩下还没解的二进制
 * @param value 解码结果 数字
 */
inline bool GetVarint32(Slice* input, uint32_t* value) {
  const char* p = input->data();
  const char* limit = p + input->size();
  // 解完的二进制会被丢掉 拿到的指针q是新的位置 可以直接顺着继续解码的位置
  const char* q = GetVarint32Ptr(p, limit, value);
  if (q == nullptr) {
    return false;
  } else {
    // 解完的丢掉 更新要解码的对象
    *input = Slice(q, static_cast<size_t>(limit - q));
    return true;
  }
}
```

本质就是编码的逆向，编的时候7位编，解的时候就每7位一解

```cpp
/**
 * 解码 [p...limit)
 * @param p 要解的低地址
 * @param limit 要解的高地址 右开
 * @param value 解码结果 数字
 * @return 指针指向的是解码数字后的那个地址
 * 也就是说调用方解码到数字后可以继续解码 比如TLV 现在T拿到了 继续就是L
 */
const char* GetVarint32PtrFallback(const char* p, const char* limit,
                                   uint32_t* value) {
  uint32_t result = 0;
  // 编码的时候是小端序编的 解的时候也是小端序
  // 分批拿 拿8位 低7位是数据 高8位是标识
  for (uint32_t shift = 0; shift <= 28 && p < limit; shift += 7) {
    uint32_t byte = *(reinterpret_cast<const unsigned char*>(p));
    p++;
    if (byte & 128) {
      // 高8位标识是1 表示还有 继续在下一轮for循环拿下一个8位 拿出现在这8位里面的低7位拼到结果里面
      // More bytes are present
      result |= ((byte & 127) << shift);
    } else {
      // 高8位标识是0 标识数字解码结束了
      result |= (byte << shift);
      *value = result;
      // 数字解完了 现在p指向的是数字后面的那个字节 也就是说解码是一边解一边移动指针
      return reinterpret_cast<const char*>(p);
    }
  }
  return nullptr;
}
```

## 2 显式length的编解码

### 2.1 编码

### 2.2 解码

```cpp
/**
 * 约定了显式的LV并且length是32位整数
 * 先解出整数看看多长
 * 再解也具体的value
 * @param input 编码
 * @param result 解码结果
 */
inline bool GetLengthPrefixedSlice(Slice* input, Slice* result) {
  // value的length
  uint32_t len = 0;
  if (GetVarint32(input, &len) && input->size() >= len) {
    /**
     * 这个if里面有两个代码
     * 1 首先解出来32位数字length 拿到后input就被更新了 也就是说拿到了length后input里面顶在最前面的就是value
     * 2 所以要校验保证剩下来还没解码的部分一定是足够length的 防御性校验二进制数据有损坏
     */
    // 拿出length长度的value
    *result = Slice(input->data(), len);
    // 解完的value要丢掉
    input->remove_prefix(len);
    return true;
  } else {
    return false;
  }
}
```
---
title: RocksDB源码-0x0F-日志记录
category_bar: true
date: 2026-02-04 13:29:05
categories: RocksDB源码
---

在RocksDB世界，两个重要的文件

- wal {%post_link RocksDB/RocksDB源码-0x05-WAL%}
- manifest {%post_link RocksDB/RocksDB源码-0x08-MANIFEST文件%}

本质都是日志文件，因此抽象成统一的日志进行读写，和普通文本文件的区别在于，文本文件按行读取，RocksDB里面的日志文件按照record为单位读取。

## 1 几个概念

有几个概念是要先弄明白的

- chunk
- block
- record
- fragment

首先，block是硬件决定的读写单位，也就是操作系统每次跟磁盘交互的大小。其次磁盘存储的单位是扇区，这个不需要理解也不影响下文。

其次在操作系统层面chunk是包含多个block大小的软件概念。

RocksDB每次读文件的Block大小是32KB，RocksDB划分成多个fragment，每个fragment就是一个读写协议，包含协议头和协议体。每个record由1个或多个fragment组成。

![](./RocksDB源码-0x0F-日志记录/1770280025.png)

## 2 读

### 2.1 按Block从操作系统读

```cpp
/**
 * 尝试从文件上读1个block 32kb大小 实际读到多少看文件系统的文件实际情况
 * @param drop_size 比如文件明明已经被读完了 理论上已经没有东西了 但是当前buffer里面可能还残留了数据 会被丢掉
 * @param error 没读到的原因 比如文件已经被读完了
 * @return 没读成功
 */
bool Reader::ReadMore(size_t* drop_size, uint8_t* error) {
  if (!eof_ && !read_error_) {
    // Last read was a full read, so this is a trailer to skip
    buffer_.clear();
    // TODO: rate limit log reader with approriate priority.
    // TODO: avoid overcharging rate limiter:
    // Note that the Read here might overcharge SequentialFileReader's internal
    // rate limiter if priority is not IO_TOTAL, e.g., when there is not enough
    // content left until EOF to read.
    // 从文件中最读32KB 实际读到了多少数据看buffer里面被填了多少
    Status status = file_->Read(kBlockSize, &buffer_, backing_store_,
                                Env::IO_TOTAL /* rate_limiter_priority */);
    TEST_SYNC_POINT_CALLBACK("LogReader::ReadMore:AfterReadFile", &status);
    end_of_buffer_offset_ += buffer_.size();
    if (!status.ok()) {
      buffer_.clear();
      ReportDrop(kBlockSize, status);
      read_error_ = true;
      *error = kEof;
      return false;
    } else if (buffer_.size() < static_cast<size_t>(kBlockSize)) {
      // 想读32KB 实际读到的不到32KB 说明物理层的文件已经被读完了
      eof_ = true;
      eof_offset_ = buffer_.size();
    }
    return true;
  } else {
    // Note that if buffer_ is non-empty, we have a truncated header at the
    //  end of the file, which can be caused by the writer crashing in the
    //  middle of writing the header. Unless explicitly requested we don't
    //  considering this an error, just report EOF.
    if (buffer_.size()) {
      *drop_size = buffer_.size();
      buffer_.clear();
      *error = kBadHeader;
      return false;
    }
    buffer_.clear();
    *error = kEof;
    return false;
  }
}
```

### 2.2 从Block里面处理fragment

```cpp
/**
 * 这个函数是的RocksDB到操作系统中间的一层 并不是每次都直接读文件 它是流的概念 从文件里面一次读到一个Block 32KB
 * 里面可能会包含很多个fragment 每次拿到一个fragment
 * 拿到的chunk可能刚好就是一个record 也可能是一个record的其中一个chunk
 * @param result 读文件读到的chunk里面的body
 * @return chunk的type 这个标识在chunk的header里面
 */
uint8_t Reader::ReadPhysicalRecord(Slice* result, size_t* drop_size,
                                   uint64_t* fragment_checksum)
```

### 2.3 record

#### 2.3.1 record就是一个fragment

```cpp
      // 当前fragment就是一个record 这种情况最简单
        *record = fragment;
```

#### 2.3.2 record由多个fragment组成

调用方给一个入参scratch用来当拼接fragment的缓冲区，最终拼好的record再丢到出参里面。

##### 2.3.2.1 fragment是record头

```cpp
      // fragment是record头 fragment丢到缓冲区 等着后续的fragment拼接进来 打上标识让后面的fragment知道record正在收集fragment
        scratch->assign(fragment.data(), fragment.size());
        in_fragmented_record = true;
```

##### 2.3.2.2 fragment是record中间部分

```cpp
          // 当前fragment是record中间的某个fragment 拼接到record里面
          scratch->append(fragment.data(), fragment.size());
```

##### 2.3.2.3 fragment是record尾

```cpp
          // 当前fragment是record的尾 拼接上去就收集全了record
          scratch->append(fragment.data(), fragment.size());
          *record = Slice(*scratch);
```

## 3 写
---
title: Redis-0x05-ziplist
index_img: /img/Reids-0x05-ziplist.png
date: 2023-03-30 20:50:22
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

## 1 ziplist是什么

### 1.1 结构

从注释上可以看出ziplist结构如下。

![](Reids-0x05-ziplist/image-20230330223845470.png)

### 1.2 字段解释

| 字段    | 长度     | 语义                                                         |
| ------- | -------- | ------------------------------------------------------------ |
| zlbytes | uint32_t | 表示ziplist占用内存大小。                                    |
| zltail  | uint32_t | 表示最后一个entry相对ziplist的地址偏移量。                   |
| zllen   | uint16_t | entry节点数量，16bit上限是2^16-1。<br>数量<上限，代表的就是实际节点数量。<br>数量>=上限，节点的实际数量需要遍历计数。 |
| entry   | -        | 保存有限长度的字符串或者整数。                               |
| zlend   | byte     | 0xFF，特殊的节点，ziplist的结束标识。                        |

## 2 entry是什么

### 2.1 结构

从注释上可以看出entry的结构如下。

![](Reids-0x05-ziplist/image-20230330225305188.png)

### 2.2 字段解释

| 字段       | 语义                                                         |
| ---------- | ------------------------------------------------------------ |
| prevlen    | 前驱节点entry占用多少bytes。                                 |
| encoding   | 主要作用区分存储的内容是整数还是字符串。<br>存储字符串的时候，还承担着表示字符串长度的职责。<br>存储整数的时候，可能还用来直接存储内容。 |
| entry-data | 节点实际存储的内容。<br>以字符数组形式存储的字符串，不需要\0结束标识符。<br>整数。 |

### 2.3 详解

#### 2.3.1 prevlen字段

为什么要在entry上冗余着前一个entry的内存大小，其实作用就跟双链表的指针差不多，这儿不用指针关联，只要记录上一个节点多少个字节就可以移动指针，往前寻址了。

前驱entry地址=当前entry地址-前驱entry大小

![](Reids-0x05-ziplist/image-20230330230319123.png)

#### 2.3.2 encoding字段

encoding二进制表示形式的高2位作为标识位，决定entry中数据内容是字符数组还是整数。

##### 2.3.2.1 存储字符串

![](Reids-0x05-ziplist/image-20230330231108397.png)

##### 2.3.2.2 存储整数

![](Reids-0x05-ziplist/image-20230330230815003.png)

## 3 初始化ziplist

![](Reids-0x05-ziplist/image-20230330232221382.png)

![](Reids-0x05-ziplist/image-20230330232312936.png)

## 4 entry字段prevlen

### 4.1 prevlen前驱长度编码

![](Reids-0x05-ziplist/image-20230331084824509.png)

### 4.2 prevlen前驱长度

![](Reids-0x05-ziplist/image-20230331085858894.png)

![](Reids-0x05-ziplist/image-20230331090437381.png)

### 4.3 prevlen需要多大内存 && prevlen字段写入

```c
// 这个函数有两个场景
//                1 不传entry时 不需要对entry中prevlen字段写入
//                2 传entry时 对entry中prevlen字段写入
// @param p 指向entry节点
// @pram len 前驱entry的长度大小
// @return p是null的时候 entry中需要给prevlen这个字段开辟多大内存(多少个byte)
unsigned int zipStorePrevEntryLength(unsigned char *p, unsigned int len) {
    if (p == NULL) {
        // 前驱节点大小的表示 要么用1个字节 要么用5个字节
        return (len < ZIP_BIG_PREVLEN) ? 1 : sizeof(uint32_t) + 1;
    } else {
        if (len < ZIP_BIG_PREVLEN) { // prevlen用1个字节表示 填充len的实际大小
            p[0] = len;
            return 1;
        } else { // prevlen用5个字节表示 第1个字节填充0xfe 后4个字节使用len的实际值
            return zipStorePrevEntryLengthLarge(p,len);
        }
    }


```



```c
// prevlen需要5个字节时 entry节点写入prevlen字段
// 这个函数有两个场景
//                1 不传entry时 不需要对entry中prevlen字段写入
//                2 传entry时 对entry中prevlen字段写入
// @param p entry节点
// @param len 写给prevlen字段表示的长度
// @return prevlen的大小 5个字节
int zipStorePrevEntryLengthLarge(unsigned char *p, unsigned int len) {
    uint32_t u32;
    if (p != NULL) {
        // prevlen共5bytes
        // 第1个byte填充标识位0xfe
        // 后4个byte写入len
        p[0] = ZIP_BIG_PREVLEN;
        u32 = len;
        memcpy(p+1,&u32,sizeof(u32));
        memrev32ifbe(p+1);
    }
    return 1 + sizeof(uint32_t);
}
```

![](Reids-0x05-ziplist/image-20230331105456800.png)

## 5 entry字段encoding

### 5.1 编码类型

```c
// 字符串是否压缩成整型
// @param entry 内容
// @param entrylen 内容长度
// @param v 字符串转成的整数
// @param encoding entry种encoding字段
// @return 0-标识可以将字符串压缩成整型 1-标识可以将字符串压缩成整型
int zipTryEncoding(unsigned char *entry, unsigned int entrylen, long long *v, unsigned char *encoding) {
    // 字符串转换成的整数(long long)
    long long value;

    if (entrylen >= 32 || entrylen == 0) return 0; // 整型32bit边界
    if (string2ll((char*)entry,entrylen,&value)) { // 将entry字符串转换成整数value
        /* Great, the string can be encoded. Check what's the smallest
         * of our encoding types that can hold this value. */
        // entry的整数编码提供了6种 根据具体的数字大小选择合适的编码方式
        if (value >= 0 && value <= 12) { // 4bit无符号整数[0...12]
            *encoding = ZIP_INT_IMM_MIN+value; // 这种编码方式直接把内容也压缩到了encoding中了 1个字节搞定
        } else if (value >= INT8_MIN && value <= INT8_MAX) { // 8bit有符号
            *encoding = ZIP_INT_8B;
        } else if (value >= INT16_MIN && value <= INT16_MAX) { // 16bit有符号
            *encoding = ZIP_INT_16B;
        } else if (value >= INT24_MIN && value <= INT24_MAX) { // 24bit有符号
            *encoding = ZIP_INT_24B;
        } else if (value >= INT32_MIN && value <= INT32_MAX) { // 32bit有符号
            *encoding = ZIP_INT_32B;
        } else { // 64bit有符号
            *encoding = ZIP_INT_64B;
        }
        *v = value;
        return 1;
    }
    return 0;
}
```

![](Reids-0x05-ziplist/image-20230331101514463.png)

### 5.2 encoding需要多大内存 && encoding字段写入

```c
// 该函数2个使用场景
//                p为null 只返回encoding需要几个字节即可
//                p不为null 不仅需要返回encoding需要几个字节 还需要为entry写入encoding这字段内容
// @param p 指向entry节点
// @param encoding entry中encoding字段
// @param rawlen entry中entry-data实际内容的长度
// @return entry需要为encoding这个字段开辟多大内存
//         不同的编码类型开辟的字节数不同
//         字符串 可能需要1byte或者2bytes或者5bytes
//         整数 需要1byte
unsigned int zipStoreEntryEncoding(unsigned char *p, unsigned char encoding, unsigned int rawlen) {
    unsigned char len = 1, buf[5];

    if (ZIP_IS_STR(encoding)) { // 字符串编码方式需要给encoding分配大小可能是1byte\2bytes\5bytes 根据字符串长度决定
        /* Although encoding is given it may not be set for strings,
         * so we determine it here using the raw length. */
        if (rawlen <= 0x3f) { // encoding需要1byte 高2位放1 后6位表示字符串长度 长度上限就是0x3f
            if (!p) return len;
            buf[0] = ZIP_STR_06B | rawlen;
        } else if (rawlen <= 0x3fff) { // encoding需要2bytes 高2位放1 后14位表示字符串长度 长度上限就是0x3fff
            len += 1;
            if (!p) return len;
            buf[0] = ZIP_STR_14B | ((rawlen >> 8) & 0x3f);
            buf[1] = rawlen & 0xff;
        } else { // encoding需要5bytes 高2位放1 后40位表示字符串长度 长度上限就是0x3fffffffff
            len += 4;
            if (!p) return len;
            buf[0] = ZIP_STR_32B;
            buf[1] = (rawlen >> 24) & 0xff;
            buf[2] = (rawlen >> 16) & 0xff;
            buf[3] = (rawlen >> 8) & 0xff;
            buf[4] = rawlen & 0xff;
        }
    } else { // 整数编码需要给encoding这个字段分配1byte
        /* Implies integer encoding, so length is always 1. */
        if (!p) return len;
        buf[0] = encoding;
    }

    /* Store this length at p. */
    memcpy(p,buf,len);
    return len;
}
```

![](Reids-0x05-ziplist/image-20230331110748619.png)

## 6 entry字段entry-data

### 6.1 entry-data需要大多内存

#### 6.1.1 字符串

entry-data中存储字符串，不需要给字符数组申请结束标识\0。

```c
reqlen = slen; // 字符串编码 有多少个字符就需要申请多少个byte
```

#### 6.1.2 整数

```c
// 根据整数编码计算表示内容需要的大小 也就是entry中的entry-data字段
// @param encoding 整数编码方式
static inline unsigned int zipIntSize(unsigned char encoding) {
    switch(encoding) {
    case ZIP_INT_8B:  return 1; // 1字节
    case ZIP_INT_16B: return 2; // 2字节
    case ZIP_INT_24B: return 3; // 3字节
    case ZIP_INT_32B: return 4; // 4字节
    case ZIP_INT_64B: return 8; // 5字节
    }
    // [0...12]的数字会编码到encoding中 不需要额外的内存
    if (encoding >= ZIP_INT_IMM_MIN && encoding <= ZIP_INT_IMM_MAX)
        return 0; /* 4 bit immediate */
    /* bad encoding, covered by a previous call to ZIP_ASSERT_ENCODING */
    redis_unreachable();
    return 0;
}
```

### 6.2 entry-data字段写入

### 6.2.1 字符串

```c
memcpy(p,s,slen);
```

### 6.2.2 整数

```c
// 向entry中写入整数的entry-data
// @param p entry节点
// @param value 整数的值
// @param encoding 编码
void zipSaveInteger(unsigned char *p, int64_t value, unsigned char encoding) {
    int16_t i16;
    int32_t i32;
    int64_t i64;
    if (encoding == ZIP_INT_8B) { // 1字节
        ((int8_t*)p)[0] = (int8_t)value;
    } else if (encoding == ZIP_INT_16B) { // 2字节
        i16 = value;
        memcpy(p,&i16,sizeof(i16));
        memrev16ifbe(p);
    } else if (encoding == ZIP_INT_24B) { // 3字节
        i32 = value<<8;
        memrev32ifbe(&i32);
        memcpy(p,((uint8_t*)&i32)+1,sizeof(i32)-sizeof(uint8_t));
    } else if (encoding == ZIP_INT_32B) { // 4字节
        i32 = value;
        memcpy(p,&i32,sizeof(i32));
        memrev32ifbe(p);
    } else if (encoding == ZIP_INT_64B) { // 8字节
        i64 = value;
        memcpy(p,&i64,sizeof(i64));
        memrev64ifbe(p);
    } else if (encoding >= ZIP_INT_IMM_MIN && encoding <= ZIP_INT_IMM_MAX) { // 直接写在encoding的后6bit上了
        /* Nothing to do, the value is stored in the encoding itself. */
    } else {
        assert(NULL);
    }
}
```

## 7 ziplist大小重置

```c
// ziplist重置大小
// @param zl ziplist实例
// @param len 新ziplist的大小
unsigned char *ziplistResize(unsigned char *zl, size_t len) {
    assert(len < UINT32_MAX);
    // 内存分批
    zl = zrealloc(zl,len);
    // ziplist中zlbytes字段记录新的大小
    ZIPLIST_BYTES(zl) = intrev32ifbe(len);
    // ziplist结束标识
    zl[len-1] = ZIP_END;
    return zl;
}
```

## 8 添加节点

```c
// 添加内容 以entry节点形式挂到ziplist上
// @param zl ziplist
// @param p entry节点 挂到哪个节点之后
// @param s 内容
// @param slen 内容长度
unsigned char *__ziplistInsert(unsigned char *zl, unsigned char *p, unsigned char *s, unsigned int slen) {
    // 取出ziplist的zlbytes值
    // curlen ziplist的大小
    // reqlen 需要向系统申请多大内容给当前entry节点 reqlen=prevlen需要的内存+encoding需要的内存+entry-data需要的内存
    size_t curlen = intrev32ifbe(ZIPLIST_BYTES(zl)), reqlen, newlen;
    unsigned int prevlensize, prevlen = 0;
    size_t offset;
    int nextdiff = 0;
    // encoding 0000 0000
    // 字符串编码下高2位0 剩下6位表示字符串长度
    // 也就是说如果是字符串编码方式 那么默认支持的字符串长度是2^6-1
    // 如果实际字符串长度比2^6-1要长 那么就要更新encoding编码方式
    unsigned char encoding = 0;
    long long value = 123456789; /* initialized to avoid warning. Using a value
                                    that is easy to see if for some reason
                                    we use it uninitialized. */
    zlentry tail;

    /* Find out prevlen for the entry that is inserted. */
    if (p[0] != ZIP_END) { // p指向的是end
        ZIP_DECODE_PREVLEN(p, prevlensize, prevlen);
    } else {
        unsigned char *ptail = ZIPLIST_ENTRY_TAIL(zl); // tail节点
        if (ptail[0] != ZIP_END) { // 往中间某个节点后挂载
            prevlen = zipRawEntryLengthSafe(zl, curlen, ptail);
        }
    }

    /* See if the entry can be encoded */
    // s 字符串
    // slen 字符串长度
    // value 字符串转换成的整数
    // encoding 整数的编码 也就是entry中的encoding字段
    if (zipTryEncoding(s,slen,&value,&encoding)) { // 字符串是否可以压缩成整型
        /* 'encoding' is set to the appropriate integer encoding */
        reqlen = zipIntSize(encoding); // 整数内容还需要多大内存 也就是entry节点中的entry-data需要多少字节
    } else {
        /* 'encoding' is untouched, however zipStoreEntryEncoding will use the
         * string length to figure out how to encode it. */
        reqlen = slen; // 字符串编码 有多少个字符就需要申请多少个byte
    }
    // 此时reqlen只记录了entry中需要开辟多大内存给entry-data这个字段
    /* We need space for both the length of the previous entry and
     * the length of the payload. */
    // entry中需要开辟多大内存给prevlen这个字段
    reqlen += zipStorePrevEntryLength(NULL,prevlen);
    // entry中需要开辟多大内存给encoding这个字段
    reqlen += zipStoreEntryEncoding(NULL,encoding,slen);

    /* When the insert position is not equal to the tail, we need to
     * make sure that the next entry can hold this entry's length in
     * its prevlen field. */
    int forcelarge = 0;
    nextdiff = (p[0] != ZIP_END) ? zipPrevLenByteDiff(p,reqlen) : 0;
    if (nextdiff == -4 && reqlen < 4) {
        nextdiff = 0;
        forcelarge = 1;
    }

    /* Store offset because a realloc may change the address of zl. */
    offset = p-zl;
    // 新添加entry节点了 ziplist要扩容 ziplist要扩到多大=老ziplist大小+新entry节点大小+节点不是挂在末节点可能导致的额外内存
    newlen = curlen+reqlen+nextdiff;
    // ziplist重置大小
    zl = ziplistResize(zl,newlen);
    p = zl+offset; // 保证p在ziplist中的相对位置

    /* Apply memory move when necessary and update tail offset. */
    if (p[0] != ZIP_END) {
        /* Subtract one because of the ZIP_END bytes */
        memmove(p+reqlen,p-nextdiff,curlen-offset-1+nextdiff);

        /* Encode this entry's raw length in the next entry. */
        if (forcelarge)
            zipStorePrevEntryLengthLarge(p+reqlen,reqlen);
        else
            zipStorePrevEntryLength(p+reqlen,reqlen);

        /* Update offset for tail */
        ZIPLIST_TAIL_OFFSET(zl) =
            intrev32ifbe(intrev32ifbe(ZIPLIST_TAIL_OFFSET(zl))+reqlen);

        /* When the tail contains more than one entry, we need to take
         * "nextdiff" in account as well. Otherwise, a change in the
         * size of prevlen doesn't have an effect on the *tail* offset. */
        assert(zipEntrySafe(zl, newlen, p+reqlen, &tail, 1));
        if (p[reqlen+tail.headersize+tail.len] != ZIP_END) {
            ZIPLIST_TAIL_OFFSET(zl) =
                intrev32ifbe(intrev32ifbe(ZIPLIST_TAIL_OFFSET(zl))+nextdiff);
        }
    } else {
        /* This element will be the new tail. */
        ZIPLIST_TAIL_OFFSET(zl) = intrev32ifbe(p-zl);
    }

    /* When nextdiff != 0, the raw length of the next entry has changed, so
     * we need to cascade the update throughout the ziplist */
    if (nextdiff != 0) {
        offset = p-zl;
        zl = __ziplistCascadeUpdate(zl,p+reqlen);
        p = zl+offset;
    }

    /* Write the entry */
    // entry写入prevlen字段
    p += zipStorePrevEntryLength(p,prevlen);
    // entry写入encoding字段
    // 此时的encoding状态
    //                  如果是字符串编码  encoding默认赋值为了1个byte(0000 0000) 现在还要根据字符串的实际长度再次确认encoding是1 byte\2 bytes\5 bytes
    //                  如果是整数编码   encoding就1个byte 前面已经根据整数大小填充好了encoding的各个bit
    p += zipStoreEntryEncoding(p,encoding,slen);
    // entry写入entry-data
    if (ZIP_IS_STR(encoding)) { // 写入字符串
        memcpy(p,s,slen);
    } else { // 写入整数 [0...12]的内容直接写在encoding空置的后6bit上
        zipSaveInteger(p,value,encoding);
    }
    ZIPLIST_INCR_LENGTH(zl,1);
    return zl;
}
```

### 8.1 节点挂在最后

### 8.2 节点挂在中间




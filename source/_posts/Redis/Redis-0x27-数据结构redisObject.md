---
title: Redis-0x27-数据结构redisObject
category_bar: true
date: 2025-02-10 17:13:53
categories: Redis
---

数据类型和编码

![](./image-20230412203454429.png)

### 1 数据结构

```c
// 16byte
typedef struct redisObject {

	/**
	 * unsigned int一共32bit
	 * <ul>
	 *   <li>数据结构类型 4bit 最多15种枚举</li>
	 *   <li>编码方式 4bit 最多15种枚举</li>
	 *   <li>lru时间戳 24bit</li>
	 * </ul>
	 */
	/**
	 * 数据结构类型
	 * <ul>
	 *   <li>0 字符串</li>
	 *   <li>1 链表</li>
	 *   <li>2 set</li>
	 *   <li>3 zset</li>
	 *   <li>4 hash</li>
	 *   <li>5 module</li>
	 *   <li>6 stream</li>
	 * </ul>
	 */
    unsigned type:4;

	/**
	 * 编码方式
	 * <ul>
	 *   <li>0 raw</li>
	 *   <li>1 int</li>
	 *   <li>2 ht</li>
	 *   <li>3 zipmap</li>
	 *   <li>4 linkedlist</li>
	 *   <li>5 ziplist</li>
	 *   <li>6 intset</li>
	 *   <li>7 skiplist</li>
	 *   <li>8 embstr</li>
	 *   <li>9 quicklist</li>
	 *   <li>10 stream</li>
	 * </ul>
	 */
    unsigned encoding:4;

    /**
     * <p>配合内存淘汰策略使用的</p>
     * <ul>
     *   <li>LFU
     *     <ul>
     *       <li>高16位 记录访问数据的时间戳 单位分钟</li>
     *       <li>低8位 记录访问数据频率</li>
     *     </ul>
     *   </li>
     *   <li>LRU
     *     <ul>
     *       <li>记录访问数据的时间戳 单位秒 24位</li>
     *     </ul>
     *   </li>
     * </ul>
     */
    unsigned lru:LRU_BITS; /* LRU time (relative to global lru_clock) or
                            * LFU data (least significant 8 bits frequency
                            * and most significant 16 bits access time). */
	/**
	 * 数据的引用计数 这个对象被引用的次数 用于对象的生命周期管理
	 * <ul>
	 *  <li>引用时增加计数</li>
	 *  <li>解绑时减少计数</li>
	 * </ul>
	 * 通过计数管理对象的生命周期 但是约定了常量对象 也就是不会回收内存 一般用于小整数缓存
	 * 因此约定了将INT_MAX作为特殊标识
	 * <ul>
	 *  <li>一旦某个对象的引用计数是INT_MAX 那么这个对象就是作为常量对象来使用的</li>
	 *  <li>引用这个对象时不会再增加这个计数</li>
	 *  <li>释放对为个对象的引用时也不会减少这个计数</li>
	 * </ul>
	 * 那么正常情况下这个值的区间就是是[1...INT_MAX-1]
	 * <ul>
	 *  <li>引用对象时就增加引用计数 增加到INT_MAX时就是抛异常</li>
	 *  <li>解绑对象时就减少引用计数 减少到0时就是销毁对象进行内存回收</li>
	 * </ul>
	 */
	int refcount;
    /**
     * <p>指向数据类型的编码方式的实现上<p>
     * <ul>
     *   <li>sds字符串而言 指向的是sds 而sds指针指向的又是sds的buf数组</li>
     *   <li>其他编码方式 指向的就是数据结构实例 比如
     *     <ul>
     *       <li>quicklist</li>
     *       <li>dict</li>
     *       <li>ziplist</li>
     *     </ul>
     *   </li>
     * </ul>
     */
    void *ptr;
} robj;
```

#### 1.1 数据结构图

![](./image-20230403131757153.png)

#### 1.2 type字段

| 数据类型 | 宏定义     | 值   |
| -------- | ---------- | ---- |
| 字符串   | OBJ_STRING | 0    |
| 列表     | OBJ_LIST   | 1    |
| 集合     | OBJ_SET    | 2    |
| 有序集合 | OBJ_ZSET   | 3    |
| 哈希表   | OBJ_HASH   | 4    |

#### 1.3 encoding字段

| 编码方式 | 宏定义                  | 值   |
| -------- | ----------------------- | ---- |
|          | OBJ_ENCODING_RAW        | 0    |
|          | OBJ_ENCODING_INT        | 1    |
|          | OBJ_ENCODING_HT         | 2    |
|          | OBJ_ENCODING_ZIPMAP     | 3    |
|          | OBJ_ENCODING_LINKEDLIST | 4    |
|          | OBJ_ENCODING_ZIPLIST    | 5    |
|          | OBJ_ENCODING_INTSET     | 6    |
|          | OBJ_ENCODING_SKIPLIST   | 7    |
|          | OBJ_ENCODING_EMBSTR     | 8    |
|          | OBJ_ENCODING_QUICKLIST  | 9    |
|          | OBJ_ENCODING_STREAM     | 10   |

#### 1.4 lru字段

配合内存淘汰策略使用的

* LRU策略
  * 记录访问数据的时间戳 单位秒 24位
* LFU策略
  * 高16位 记录访问数据的时间戳 单位分钟
  * 低8位 记录访问数据频率

#### 1.5 refcount字段
数据的引用计数，用途主要有2个
- INT_MAX作为特殊标识常量
- 用于对象生命周期管理和内存回收
##### 1.5.1 常量标识
```c
/**
 * 把对象标识为常量 引用计数置为INT_MAX这个特殊标识
 */
robj *makeObjectShared(robj *o) {
    serverAssert(o->refcount == 1);
    // 引用计数INT_MAX特殊标识 标识对象是全局常量
    o->refcount = OBJ_SHARED_REFCOUNT;
    return o;
}
```

##### 1.5.2 对象生命周期异常
```c
/**
 * 有其他对象引用当前对象 增加当前对象的引用计数
 * INT_MAX边界需要处理
 * @param o 被引用的对象
 */
void incrRefCount(robj *o) {
    // 引用计数在[1...INT_MAX)区间内的都是普通对象 增加计数
    if (o->refcount < OBJ_FIRST_SPECIAL_REFCOUNT) {
        o->refcount++;
    } else {
        if (o->refcount == OBJ_SHARED_REFCOUNT) {
            // 常量对象的引用计数用INT_MAX特殊标识 这个标识不能动
            /* Nothing to do: this refcount is immutable. */
        } else if (o->refcount == OBJ_STATIC_REFCOUNT) {
            // 普通对象能被引用INT_MAX次作为异常上抛
            serverPanic("You tried to retain an object allocated in the stack");
        }
    }
}
```

##### 1.5.3 垃圾回收
```c
/**
 * 其他对象解绑当前对象时 把当前对象的引用计数减少
 * <ul>需要处理的边界有2个
 *   <li>0 当某个对象不再被引用时就说明对象内存需要释放</li>
 *   <li>INT_MAX 常量不用回收 不要改变这个特殊引用计数</li>
 * </ul>
 * @param o 当前对象
 */
void decrRefCount(robj *o) {
    if (o->refcount == 1) {
        // 进行垃圾回收
        switch(o->type) {
        case OBJ_STRING: freeStringObject(o); break;
        case OBJ_LIST: freeListObject(o); break;
        case OBJ_SET: freeSetObject(o); break;
        case OBJ_ZSET: freeZsetObject(o); break;
        case OBJ_HASH: freeHashObject(o); break;
        case OBJ_MODULE: freeModuleObject(o); break;
        case OBJ_STREAM: freeStreamObject(o); break;
        default: serverPanic("Unknown object type"); break;
        }
        zfree(o);
    } else {
        // 理论上不存在的边界 上抛异常
        if (o->refcount <= 0) serverPanic("decrRefCount against refcount <= 0");
        // 正常对象被解绑减少引用计数
        if (o->refcount != OBJ_SHARED_REFCOUNT) o->refcount--;
    }
}
```

#### 1.6 ptr字段

数据

### 2 String字符串对象

```c
/**
 * @brief 字符串对象
 *        对于字符串而言共3中编码方式
 *           - 编码成整数 整数的字节上限是64bit 反推字符串长度上限就是20
 *           - 编码成sds 根据长度进行选择具体的编码方式 长度临界是44
 *             - 编码成EMBSTR
 *             - 编码成RAW
 * @param ptr 字符串的字符数组形式
 * @param len 字符串长度
 * @return
 */
robj *createStringObject(const char *ptr, size_t len) {
    if (len <= OBJ_ENCODING_EMBSTR_SIZE_LIMIT)
        return createEmbeddedStringObject(ptr,len); // 字符串长度<=44 编码成EMBSTR
    else
        return createRawStringObject(ptr,len); // 编码成RAW
}
```

#### 2.1 INT编码

```c
/**
 * @brief 字符串可以转换成整数 最终也将执行到这个方法
 *        体现的就是字符串的编发方式INT
 * @param value 整数
 * @param valueobj 标识是否可以使用共享对象
 *                 0标识可以使用共享对象
 *                 1标识不能用共享对象 相当于要用原型模式创建新对象
 * @return
 */
robj *createStringObjectFromLongLongWithOptions(long long value, int valueobj) {
    robj *o;

    if (server.maxmemory == 0 ||
        !(server.maxmemory_policy & MAXMEMORY_FLAG_NO_SHARED_INTEGERS))
    {
        /* If the maxmemory policy permits, we can still return shared integers
         * even if valueobj is true. */
        valueobj = 0;
    }

    if (value >= 0 && value < OBJ_SHARED_INTEGERS && valueobj == 0) { // 使用共享对象
        incrRefCount(shared.integers[value]);
        o = shared.integers[value];
    } else { // 原型
        if (value >= LONG_MIN && value <= LONG_MAX) { // 整数占用字节64bit 校验极值
            o = createObject(OBJ_STRING, NULL); // 数据类型是String
            o->encoding = OBJ_ENCODING_INT; // 编码方式是INT
            o->ptr = (void*)((long)value); // ptr指向的就是整数
        } else {
            o = createObject(OBJ_STRING,sdsfromlonglong(value));
        }
    }
    return o;
}
```

#### 2.2 EMBSTR编码

```c
/**
 * @brief 字符串的编码是MEBSTR
 * @param ptr 字符串的字符数组形式
 * @param len 字符串长度
 * @return redisObject实例
 */
robj *createEmbeddedStringObject(const char *ptr, size_t len) {
    /**
     * @brief 申请一整片内存
     *        所谓的EMBSTR是针对长度<=44的字符串 将sds的内存和redisObject的内存连在一起
     *        因此 整体的内存布局如下
     *          - redisObject的内存大小
     *          - sds的内存大小
     *          - 字符串长度
     *          - 字符串结束符\0
     *        sdshdr5存储的字符串长度上限为2^5-1 即31
     *        而EMBSTR定义的存储字符串长度上限为44
     *        所以这个地方采用sdshdr8进行编码
     */
    robj *o = zmalloc(sizeof(robj)+sizeof(struct sdshdr8)+len+1); // 当前o指针指向的是用来存储redisObject的
    struct sdshdr8 *sh = (void*)(o+1); // sh指针指向的是sds数据结构 该数据结构现在柔性数组buf为空 不占空间 那么sdshdr8就是3byte大小

    o->type = OBJ_STRING; // 数据类型String
    o->encoding = OBJ_ENCODING_EMBSTR; // 编码方式EMBSTR
    o->ptr = sh+1; // 相当于sh指针后移3byte 此时指向的是sds的buf数组
    o->refcount = 1;
    if (server.maxmemory_policy & MAXMEMORY_FLAG_LFU) { // 数据访问时间记录
        o->lru = (LFUGetTimeInMinutes()<<8) | LFU_INIT_VAL;
    } else {
        o->lru = LRU_CLOCK();
    }

    sh->len = len; // 字符串长度
    sh->alloc = len; // 申请的buf数组长度
    sh->flags = SDS_TYPE_8; // sds类型
    if (ptr == SDS_NOINIT)
        sh->buf[len] = '\0';
    else if (ptr) {
        memcpy(sh->buf,ptr,len); // 字符串内容放到sds的buf数组里面
        sh->buf[len] = '\0'; // 结束符
    } else {
        memset(sh->buf,0,len+1);
    }
    return o;
}
```

![](./image-20230412232945476.png)

#### 2.3 RAW编码

```c
/**
 * @brief 字符串的编码方式是RAW
 *          - 字符串编码方式是sds
 *          - redisObject的内存布局并不一定跟sds连在一起
 * @param ptr 字符串的字符数组形式
 * @param len 字符串长度
 * @return
 */
robj *createRawStringObject(const char *ptr, size_t len) {
    // 将字符串以sds进行编码
    return createObject(OBJ_STRING, sdsnewlen(ptr,len));
}
```

```c
/**
 * @brief
 * @param type 数据类型 String List Hash Set ZSet
 * @param ptr redisObject的ptr指向的就是这个数据的实现
 *              - 对于字符串的编码sds而言 本身sds暴露的指针就是指向自己的buf数组 所以redisObject中的ptr指向的也就是buf数组
 * @return
 */
robj *createObject(int type, void *ptr) {
    robj *o = zmalloc(sizeof(*o));
    o->type = type; // 数据类型
    o->encoding = OBJ_ENCODING_RAW; // 编码方式
    o->ptr = ptr;
    o->refcount = 1;

    /* Set the LRU to the current lruclock (minutes resolution), or
     * alternatively the LFU counter. */
    // 内存淘汰策略是MAXMEMORY_NO_EVICTION
    if (server.maxmemory_policy & MAXMEMORY_FLAG_LFU) {
        /**
         * @brief
         *   - 高16位 记录访问数据的时间戳 分钟
         *   - 低8位 应该记录访问数据次数 但是这个地方初始化是5 啥意思
         */
         // TODO: 2023/4/12
        o->lru = (LFUGetTimeInMinutes()<<8) | LFU_INIT_VAL;
    } else {
        // 记录访问数据的时间戳 秒
        o->lru = LRU_CLOCK();
    }
    return o;
}
```

![](./image-20230412234114968.png)

### 3 List列表对象

#### 3.1 quicklist编码

```c
/**
 * @brief List列表对象
 *        编码方式为quicklist
 * @return
 */
robj *createQuicklistObject(void) {
    quicklist *l = quicklistCreate(); // 数据类型实现是quicklist
    robj *o = createObject(OBJ_LIST,l); // 数据类型是List列表
    o->encoding = OBJ_ENCODING_QUICKLIST; // 编码类型为quicklist
    return o;
}
```

#### 3.2 ziplist编码

```c
/**
 * @brief List列表对象
 *        编码方式为ziplist
 * @return
 */
robj *createZiplistObject(void) {
    unsigned char *zl = ziplistNew();
    robj *o = createObject(OBJ_LIST,zl); // 数据类型为List列表
    o->encoding = OBJ_ENCODING_ZIPLIST; // 编码方式为ziplist
    return o;
}
```

###  4 Set集合对象

#### 4.1 dict编码

```c
/**
 * @brief Set集合对象
 *        数据类型是set集合 数据结构实现是dict
 *        编码类型是dict
 * @return 
 */
robj *createSetObject(void) {
    dict *d = dictCreate(&setDictType,NULL);
    robj *o = createObject(OBJ_SET,d);
    o->encoding = OBJ_ENCODING_HT;
    return o;
}
```

#### 4.2 intset编码

```c
/**
 * @brief Set集合对象
 *        数据类型是set集合 数据结构实现是intset
 *        编码类型是intset
 * @return
 */
robj *createIntsetObject(void) {
    intset *is = intsetNew();
    robj *o = createObject(OBJ_SET,is);
    o->encoding = OBJ_ENCODING_INTSET;
    return o;
}
```

### 5 ZSet有序集合对象

#### 5.1 zskiplist编码

```c
/**
 * @brief ZSet有序集合对象
 *        数据类型是zset 数据结构实现是zset
 *        编码实现是zskiplist
 * @return
 */
robj *createZsetObject(void) {
    zset *zs = zmalloc(sizeof(*zs));
    robj *o;

    zs->dict = dictCreate(&zsetDictType,NULL);
    zs->zsl = zslCreate();
    o = createObject(OBJ_ZSET,zs);
    o->encoding = OBJ_ENCODING_SKIPLIST;
    return o;
}
```

#### 5.2 ziplist编码

```c
/**
 * @brief ZSet有序集合对象
 *        数据类型是zet 数据结构实现是ziplist
 *        编码方式是ziplist
 * @return
 */
robj *createZsetZiplistObject(void) {
    unsigned char *zl = ziplistNew();
    robj *o = createObject(OBJ_ZSET,zl);
    o->encoding = OBJ_ENCODING_ZIPLIST;
    return o;
}
```

### 6 Hash哈希对象

#### 6.1 ziplist编码

```c
/**
 * @brief Hash哈希对象
 *        数据类型是hash
 *        数据结构是ziplist
 *        编码方式是ziplist
 * @return
 */
robj *createHashObject(void) {
    unsigned char *zl = ziplistNew();
    robj *o = createObject(OBJ_HASH, zl);
    o->encoding = OBJ_ENCODING_ZIPLIST;
    return o;
}
```
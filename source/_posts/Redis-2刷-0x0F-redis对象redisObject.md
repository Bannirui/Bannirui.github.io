---
title: Redis-2刷-0x0F-redis对象redisObject
date: 2024-01-05 00:05:27
category_bar: true
categories: Redis
tags: 2刷Redis
---

给一片内存，用户层是没办法进行解引用的，因为不知道数据的类型。因此redis定义了对象类型，万物皆可定义成对象，将来再逆向读出来。

因此，对象就要至少知道内存布局，以及数据的地址，对象关注3个方面信息

- 数据结构，或者说数据类型，数据结构偏侧与内存布局，数据怎么放的，一般由使用场景引发的存取方式来决定的

- 编码方式，关注的是用什么样的方式花最少的内存空间，表达更丰富的信息

- 数据，真实存放数据的地方

很简单的一个比方，比如我要找一个地方存放`123456789`这个东西，怎么放？

- 可以把它看成一个长度是9的字符串，那么需要9个byte的空间来表达

- 也可以把它看成一个整数，32bit的整数，那么需要4byte的空间来表达

另一个场景，比如我要存放`123`

- 可以把它看作一个长度3的字符串，需要3byte空间

- 可以看作整数，需要4byte空间

因此redisObject整合了一个总的入口，它仅仅是一个redis跟外界进行数据存储方式的信息传达，不专注底层的布局、编码实现，仅仅相当于一个门卫

- 你放数据到redis的时候告诉redisObject这个数据是什么数据类型(用的什么数据结构)、怎么编码的、数据的地址

- 将来有人来取的时候，门卫再把上述信息告诉读者，那么读者自然知道怎么逆向读出真实的数据内容

1 UDT
---

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
    // 数据的引用计数
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

2 创建对象
---

```c
/**
 * @param type 数据类型
 *             <ul>
 *               <li>String</li>
 *               <li>List</li>
 *               <li>Hash</li>
 *               <li>Set</li>
 *               <li>ZSet</li>
 *             </ul>
 *
 * @param ptr redisObject的ptr指向的就是这个数据的实现
 *            <ul>
 *              <li>对于字符串的编码sds而言 本身sds暴露的指针就是指向自己的buf数组 所以redisObject中的ptr指向的也就是buf数组</li>
 *            </ul>
 * @return raw编码的字符串
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

3 数据类型
---

数据类型，常用的无非就是那么几种，语言无关性

- 字符串

- 链表

- 集合

- 有序集合

- 哈希表

### 3.1 字符串

#### 3.1.1 raw型编码

```c
/**
 * 字符串的编码方式是RAW
 * <ul>
 *   <li>字符串的数据结构是sds</li>
 *   <li>字符串的编码方式是raw 意味着redisObject和sds字符串内存布局上不一定连在一起</li>
 * </ul>
 * @param ptr 字符串的字符数组形式
 * @param len 字符串长度
 */
robj *createRawStringObject(const char *ptr, size_t len) {
    // raw型编码的字符串
    return createObject(OBJ_STRING, sdsnewlen(ptr,len));
}
```

#### 3.1.2 emb型编码

```c
/**
 * @brief 字符串的编码是MEBSTR
 * @param ptr 字符串的字符数组形式
 * @param len 字符串长度
 * @return redisObject实例
 */
robj *createEmbeddedStringObject(const char *ptr, size_t len) {
    /**
     * 申请一整片内存
     * 所谓的EMBSTR是针对长度<=44的字符串 将sds的内存和redisObject的内存连在一起
     * 因此 整体的内存布局如下
     * <ul>
     *   <li>redisObject的内存大小</li>
     *   <li>sds的内存大小</li>
     *   <li>字符串长度</li>
     *   <li>字符串结束符\0</li>
     * </ul>
     * sdshdr5存储的字符串长度上限为2^5-1 即31
     * 而EMBSTR定义的存储字符串长度上限为44
     * 所以这个地方采用sdshdr8进行编码
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

#### 3.1.3 int型编码

```c
/**
 * 整数编码成字符串
 * <ul>
 *   <li>要么是int型字符串</li>
 *   <li>要么是raw型字符串</li>
 * </ul>
 * @param value 整数
 * @param valueobj 标识对象是否可以共享
 *                 <ul>
 *                   <li>0 单例对象</li>
 *                   <li>1 原型对象</li>
 *                 </ul>
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

	/**
	 * 整数对象优先从缓存池中拿
	 */
    if (value >= 0 && value < OBJ_SHARED_INTEGERS && valueobj == 0) { // 单例模式
        incrRefCount(shared.integers[value]);
        o = shared.integers[value];
    } else { // 原型模式
	    /**
	     * int64 bit都不能表达这个整数 那么这个整数长度已经超过了64位
	     * 字符串有3种编码
	     * <ul>
	     *   <li>整数</li>
	     *   <li>emb</li>
	     *   <li>raw</li>
	     * </ul>
	     * emb的表达长度上限是44 连64位的long整型都表达不了这个数字 就更别提emb了
	     * 所以整数编码成字符串实质就2种
	     * <ul>
	     *   <li>整数</li>
	     *   <li>raw</li>
	     * </ul>
	     */
        if (value >= LONG_MIN && value <= LONG_MAX) { // 整数占用字节64bit 校验极值
            o = createObject(OBJ_STRING, NULL); // 数据类型是String
            o->encoding = OBJ_ENCODING_INT; // 编码方式是INT
            o->ptr = (void*)((long)value); // ptr指向的就是整数
        } else {
		    // 整数编码成raw字符串
            o = createObject(OBJ_STRING,sdsfromlonglong(value));
        }
    }
    return o;
}
```

### 3.2 链表
### 3.3 集合
### 3.4 有序集合
### 3.5 哈希表
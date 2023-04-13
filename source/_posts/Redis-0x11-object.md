---
title: Redis-0x11-object
date: 2023-04-10 10:44:59
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

源码中redis对象redisObject相关的实现都在object.c文件中，该篇内容跟{% post_link Redis-0x08-redisObject redisObject那篇 %}内容都出自object.c。

## 1 字符串内存压缩

```c
/**
 * @brief 对字符串sds进行内存压缩
 *          - 字符串sds压缩成int类型
 *          - RAW编码的string压缩成EMBSTR编码
 *        从函数的实现上也可以看出sds的编码方式和优先级选择
 *          - 字符串长度区间 [1...20] 可以转换成整数的 用int编码
 *          - 字符串长度区间 [1...44] 使用EMBSTR编码
 *          - 字符串长度区间 [45...] 使用RAW编码
 * @param o
 * @return 如果可以进行类型压缩 就返回新编码的数据
 */
robj *tryObjectEncoding(robj *o) {
    long value;
    sds s = o->ptr;
    size_t len;

    /* Make sure this is a string object, the only type we encode
     * in this function. Other types use encoded memory efficient
     * representations but are handled by the commands implementing
     * the type. */
    // 只对字符串类型的数据尝试压缩
    serverAssertWithInfo(NULL,o,o->type == OBJ_STRING);

    /* We try some specialized encoding only for objects that are
     * RAW or EMBSTR encoded, in other words objects that are still
     * in represented by an actually array of chars. */
    /**
     * 尝试压缩压缩内存
     *   - string压缩成int
     *   - RAW的string压缩成EMBSTR
     */
    if (!sdsEncodedObject(o)) return o;

    /* It's not safe to encode shared objects: shared objects can be shared
     * everywhere in the "object space" of Redis and may end in places where
     * they are not handled. We handle them only as values in the keyspace. */
     if (o->refcount > 1) return o;

    /* Check if we can represent this string as a long integer.
     * Note that we are sure that a string larger than 20 chars is not
     * representable as a 32 nor 64 bit integer. */
    len = sdslen(s);
    /**
     * 整数类型是通过64bit的long来表现的
     * 那么能够表现的最大值就是2^64-1=1.74*10^19
     * 也就是说整数最多也就20位
     */
    if (len <= 20 && string2l(s,len,&value)) {
        /* This object is encodable as a long. Try to use a shared object.
         * Note that we avoid using shared integers when maxmemory is used
         * because every object needs to have a private LRU field for the LRU
         * algorithm to work well. */
        if ((server.maxmemory == 0 ||
            !(server.maxmemory_policy & MAXMEMORY_FLAG_NO_SHARED_INTEGERS)) &&
            value >= 0 &&
            value < OBJ_SHARED_INTEGERS)
        {
            decrRefCount(o);
            incrRefCount(shared.integers[value]);
            return shared.integers[value];
        } else {
            if (o->encoding == OBJ_ENCODING_RAW) {
                sdsfree(o->ptr);
                o->encoding = OBJ_ENCODING_INT;
                o->ptr = (void*) value;
                return o;
            } else if (o->encoding == OBJ_ENCODING_EMBSTR) {
                decrRefCount(o);
                return createStringObjectFromLongLongForValue(value);
            }
        }
    }

    /* If the string is small and is still RAW encoded,
     * try the EMBSTR encoding which is more efficient.
     * In this representation the object and the SDS string are allocated
     * in the same chunk of memory to save space and cache misses. */
    if (len <= OBJ_ENCODING_EMBSTR_SIZE_LIMIT) { // 字符串长度<=44的尝试用EMBSTR编码
        robj *emb;

        if (o->encoding == OBJ_ENCODING_EMBSTR) return o;
        emb = createEmbeddedStringObject(s,sdslen(s));
        decrRefCount(o);
        return emb;
    }

    /* We can't encode the object...
     *
     * Do the last try, and at least optimize the SDS string inside
     * the string object to require little space, in case there
     * is more than 10% of free space at the end of the SDS string.
     *
     * We do that only for relatively large strings as this branch
     * is only entered if the length of the string is greater than
     * OBJ_ENCODING_EMBSTR_SIZE_LIMIT. */
    trimStringObjectIfNeeded(o);

    /* Return the original object. */
    return o;
}
```


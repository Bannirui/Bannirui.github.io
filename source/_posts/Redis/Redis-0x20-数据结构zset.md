---
title: Redis-0x20-数据结构zset
category_bar: true
date: 2025-02-10 15:12:09
categories: Redis
---

数据类型zset有序集合。

### 1 数据结构关系

| 数据类型     | 实现   | 编码方式                                                   | 数据结构  |
| ------------ | ------ | ---------------------------------------------------------- | --------- |
| 列表OBJ_ZSET | t_zset | {% post_link Redis/Redis-0x21-数据结构zskiplist %} | zskiplist |
|              |        | {% post_link Redis/Redis-0x22-数据结构ziplist %}    | ziplist   |

在使用ziplist进行编码时，ziplist中两两挨着的entry用来表达zset中的一个元素，entry1用来存储zset元素的值，entry2用来存储set元素的score排序字段，ziplist中按照升序方式编排节点。

### 2 集合中元素计数

```c
/**
 * @brief 从代码实现上也可以看出zset的编码方式只有2种
 *          - ziplist
 *            - 在使用ziplist进行编码时
 *            - 内存布局是ziplist中两两紧挨着的entry节点表达一个zset的元素
 *            - 第一个ziplist的entry存放的是元素值
 *            - 第二个ziplist的entry存放的是排序字段的值
 *            - 按照升序方式编排zset的元素
 *          - skiplist
 * @param zobj
 * @return 有序集合zset中的元素数量
 */
unsigned long zsetLength(const robj *zobj) {
    unsigned long length = 0;
    if (zobj->encoding == OBJ_ENCODING_ZIPLIST) { // 编码方式为ziplist
        length = zzlLength(zobj->ptr); // ziplist中entry数量除以2
    } else if (zobj->encoding == OBJ_ENCODING_SKIPLIST) { // 编码方式为zskiplist
        length = ((const zset*)zobj->ptr)->zsl->length;
    } else {
        serverPanic("Unknown sorted set encoding");
    }
    return length;
}
```



```c
/**
 * @brief zset使用ziplist进行编码时 计算zset中存储的元素数量
 *        ziplist中两两连续的entry用来表达zset中一个元素
 *        [entry1, entry2]
 *          - entry1是元素的值
 *          - entry2是排序的score值
 *        因此zset的元素数量是ziplist中entry数量的一半
 * @param zl ziplist实例
 * @return set中元素的数量
 */
unsigned int zzlLength(unsigned char *zl) {
    return ziplistLen(zl)/2;
}
```

### 3 编码方式转换

```c
/**
 * @brief zset的编码方式转换
 *          - ziplist->zskiplist
 *          - zskiplist->ziplist
 * @param zobj
 * @param encoding 要转换成哪种编码方式
 */
void zsetConvert(robj *zobj, int encoding) {
    zset *zs;
    zskiplistNode *node, *next;
    sds ele;
    double score;

    if (zobj->encoding == encoding) return;
    if (zobj->encoding == OBJ_ENCODING_ZIPLIST) { // ziplist->zskiplist
        unsigned char *zl = zobj->ptr;
        unsigned char *eptr, *sptr;
        unsigned char *vstr;
        unsigned int vlen;
        long long vlong;

        if (encoding != OBJ_ENCODING_SKIPLIST)
            serverPanic("Unknown target encoding");

        zs = zmalloc(sizeof(*zs));
        zs->dict = dictCreate(&zsetDictType,NULL);
        zs->zsl = zslCreate();

        eptr = ziplistIndex(zl,0); // 第一个entry存储的是元素的值
        serverAssertWithInfo(NULL,zobj,eptr != NULL);
        sptr = ziplistNext(zl,eptr); // 第二个entry存储的score值
        serverAssertWithInfo(NULL,zobj,sptr != NULL);

        while (eptr != NULL) { // 迭代整个ziplist 找到所有的[元素, score]对
            score = zzlGetScore(sptr); // 将ziplist上entry中存储的score值读出来
            serverAssertWithInfo(NULL,zobj,ziplistGet(eptr,&vstr,&vlen,&vlong)); // 将ziplist上entry中存储的元素读取出来
            if (vstr == NULL) // ziplist中entry存储的是整数
                ele = sdsfromlonglong(vlong); // 整数转字符串
            else // ziplist中entry存储的是字符串
                ele = sdsnewlen((char*)vstr,vlen); // 字符串编码方式为sds

            node = zslInsert(zs->zsl,score,ele); // 写入zskiplist
            serverAssert(dictAdd(zs->dict,ele,&node->score) == DICT_OK); // 写入字典
            zzlNext(zl,&eptr,&sptr);
        }

        zfree(zobj->ptr);
        zobj->ptr = zs;
        zobj->encoding = OBJ_ENCODING_SKIPLIST;
    } else if (zobj->encoding == OBJ_ENCODING_SKIPLIST) { // zskiplist->ziplist
        unsigned char *zl = ziplistNew();

        if (encoding != OBJ_ENCODING_ZIPLIST)
            serverPanic("Unknown target encoding");

        /* Approach similar to zslFree(), since we want to free the skiplist at
         * the same time as creating the ziplist. */
        zs = zobj->ptr;
        dictRelease(zs->dict);
        node = zs->zsl->header->level[0].forward; // zskiplist的第一层就是一条双链表 node此时指向的是第一个数据节点
        zfree(zs->zsl->header);
        zfree(zs->zsl);

        while (node) {
            zl = zzlInsertAt(zl,NULL,node->ele,node->score); // 1个跳表节点拆成2个entry写到ziplist 取的时候是从跳表头->跳表尾 已经有序了 所以写ziplist的时候直接尾插就行
            next = node->level[0].forward;
            zslFreeNode(node);
            node = next;
        }

        zfree(zs);
        zobj->ptr = zl;
        zobj->encoding = OBJ_ENCODING_ZIPLIST;
    } else {
        serverPanic("Unknown sorted set encoding");
    }
}
```
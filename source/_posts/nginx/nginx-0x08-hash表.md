---
title: nginx-0x08-hash表
category_bar: true
date: 2025-03-13 10:40:22
categories: nginx
---

### 1 结构
![](./nginx-0x08-hash表/1741859580.png)
### 2 存元素
```c
/*
 * 把所有键值对names都放到hash表中
 * @param hinit hash表
 * @param names 键值对列表
 * @param nelts 有多少个键值对要存到hash表
 */
ngx_int_t
ngx_hash_init(ngx_hash_init_t *hinit, ngx_hash_key_t *names, ngx_uint_t nelts)
{
    u_char          *elts;
    size_t           len;
    u_short         *test;
    ngx_uint_t       i, n, key, size, start, bucket_size;
    ngx_hash_elt_t  *elt, **buckets;

    if (hinit->max_size == 0) {
        ngx_log_error(NGX_LOG_EMERG, hinit->pool->log, 0,
                      "could not build %s, you should "
                      "increase %s_max_size: %i",
                      hinit->name, hinit->name, hinit->max_size);
        return NGX_ERROR;
    }

    if (hinit->bucket_size > 65536 - ngx_cacheline_size) {
        // hash桶过大会导致将来查询效率低下
        ngx_log_error(NGX_LOG_EMERG, hinit->pool->log, 0,
                      "could not build %s, too large "
                      "%s_bucket_size: %i",
                      hinit->name, hinit->name, hinit->bucket_size);
        return NGX_ERROR;
    }
    // 遍历键值对 防御性校验 防止桶连一个键值对都放不下
    for (n = 0; n < nelts; n++) {
        if (names[n].key.data == NULL) {
            continue;
        }
        // 防御性校验 防止桶连一个键值对都放不下
        if (hinit->bucket_size < NGX_HASH_ELT_SIZE(&names[n]) + sizeof(void *))
        {
            /*
             * 什么情况会这样呢
             * <ul>
             *   <li>1是桶大小指定太小</li>
             *   <li>2是键值对的键过长</li>
             * </ul>
             */
            ngx_log_error(NGX_LOG_EMERG, hinit->pool->log, 0,
                          "could not build %s, you should "
                          "increase %s_bucket_size: %i",
                          hinit->name, hinit->name, hinit->bucket_size);
            return NGX_ERROR;
        }
    }
    /*
     * test用来记录hash桶填充状态避免冲突 记录的是hash桶中已经存放了多大空间 放置超过桶空间上限
     * 为啥用系统调用alloc而不用内存池palloc
     * 因为仅仅是辅助使用 在hash表初始化好就释放了 不需要长期存储
     * max_size是hash桶数量的上限 实际上不一定用这么多 下面会去计算出真正需要的hash桶数量
     * 这个辅助数组就按照max_size分配就行 反正这个初始化方法结束完就释放内存了
     */
    test = ngx_alloc(hinit->max_size * sizeof(u_short), hinit->pool->log);
    if (test == NULL) {
        return NGX_ERROR;
    }
    // 抠除桶底的NULL分隔符 剩下来的就是实际可以存放键值对的空间
    bucket_size = hinit->bucket_size - sizeof(void *);
    /*
     * 牛逼
     * 首先明确hash桶中1个键值对占用空间
     * <ul>
     *   <li>指向值的指针->占sizeof(void*)大小 8byte</li>
     *   <li>键的长度->short类型 2byte</li>
     *   <li>键->不到实际存储的时候都是未知的</li>
     * </ul>
     * 那么上面这一坨经过对齐 至少就是16byte 也就是2个sizeof(void*)
     * 再者 为什么不根据实际键值对计算出来真正需要的桶数据量
     * 没必要 因为已经定了hash数组长度上限 只要定好下限 然后轮询尝试就行
     * 那么这个下限是不是可以极限一下到0 当然可以
     * 下面这个公式的目的就是为了初步定下来最小的桶数量
     * 一个键对最少占sz=2*sizeof(void*)
     * 那么一个桶最多盛放的元素数量n=bucket_size/sz
     * 整个hash表最少需要的桶数量=nelts/n
     */
    start = nelts / (bucket_size / (2 * sizeof(void *)));
    start = start ? start : 1;

    if (hinit->max_size > 10000 && nelts && hinit->max_size / nelts < 100) {
        start = hinit->max_size - 1000;
    }
    /*
     * 经过初步计算需要start个hash桶比较合适 从[start....max_size]开始尝试找到真正合适的hash桶数量
     * 为什么需要尝试
     * <ul>
     *   <li>hash桶太少 hash碰撞的概率就大 从而单个hash桶空间的使用可能达到上限</li>
     *   <li>hash桶太多 占用空间大而且查询效率低</li>
     * </ul>
     * 因此在尝试定桶数量过程中发现桶大小超限就增加桶数量
     */
    for (size = start; size <= hinit->max_size; size++) {
        // 辅助数组初始化0
        ngx_memzero(test, size * sizeof(u_short));
        // 计算将所有键值对放到hash表中会不会导致桶过大 用辅助表test记录每个桶大小
        for (n = 0; n < nelts; n++) {
            if (names[n].key.data == NULL) {
                continue;
            }
            // 键值对应该放在哪个hash桶 数组的脚标
            key = names[n].key_hash % size;
            // 要是继续把当前键值对放在这个桶里面 之后桶空间的大小达到多大
            len = test[key] + NGX_HASH_ELT_SIZE(&names[n]);

#if 0
            ngx_log_error(NGX_LOG_ALERT, hinit->pool->log, 0,
                          "%ui: %ui %uz \"%V\"",
                          size, key, len, &names[n].key);
#endif
            // 选定桶数量是size后 存放nelts个键值对过程中发现有桶的大小超限了 因此要尝试使用更多桶数量
            if (len > bucket_size) {
                goto next;
            }
            // 更新辅助表记录桶大小
            test[key] = (u_short) len;
        }
        // 找到了合适的桶数量size个 可以保证桶数量金可能少并且桶不过大
        goto found;

    next:

        continue;
    }

    size = hinit->max_size;

    ngx_log_error(NGX_LOG_WARN, hinit->pool->log, 0,
                  "could not build optimal %s, you should increase "
                  "either %s_max_size: %i or %s_bucket_size: %i; "
                  "ignoring %s_bucket_size",
                  hinit->name, hinit->name, hinit->max_size,
                  hinit->name, hinit->bucket_size, hinit->name);

found:
    /*
     * 此时定下来桶的数量size个 也就是hash表数组长度是size对应脚标是[0...size-1]
     * test辅助数组的作用依然是记录每个桶被占用的空间
     * 在上面test已经被使用过一轮了 已经不干净了因此要初始化一下[0...size]脚标
     * 初始化的时候先把每个桶的桶底指针占用的空间统计上
     */
    for (i = 0; i < size; i++) {
        test[i] = sizeof(void *);
    }
    // 如果把所有元素放到hash表 在辅助表上记录每个hash桶的大小
    for (n = 0; n < nelts; n++) {
        if (names[n].key.data == NULL) {
            continue;
        }
        // 根据hash定位到键值对放到哪个hash桶
        key = names[n].key_hash % size;
        len = test[key] + NGX_HASH_ELT_SIZE(&names[n]);

        if (len > 65536 - ngx_cacheline_size) {
            ngx_log_error(NGX_LOG_EMERG, hinit->pool->log, 0,
                          "could not build %s, you should "
                          "increase %s_max_size: %i",
                          hinit->name, hinit->name, hinit->max_size);
            ngx_free(test);
            return NGX_ERROR;
        }

        test[key] = (u_short) len;
    }
    // 统计所有hash桶占用多大空间
    len = 0;
    // 遍历hash桶 找到不是空桶 统计所有桶占用的大小
    for (i = 0; i < size; i++) {
        if (test[i] == sizeof(void *)) {
            // 辅助数组记录了桶占用空间就一个指针 说明是空桶
            continue;
        }

        test[i] = (u_short) (ngx_align(test[i], ngx_cacheline_size));

        len += test[i];
    }

    if (hinit->hash == NULL) {
        hinit->hash = ngx_pcalloc(hinit->pool, sizeof(ngx_hash_wildcard_t)
                                             + size * sizeof(ngx_hash_elt_t *));
        if (hinit->hash == NULL) {
            ngx_free(test);
            return NGX_ERROR;
        }

        buckets = (ngx_hash_elt_t **)
                      ((u_char *) hinit->hash + sizeof(ngx_hash_wildcard_t));

    } else {
        // hash数组
        buckets = ngx_pcalloc(hinit->pool, size * sizeof(ngx_hash_elt_t *));
        if (buckets == NULL) {
            ngx_free(test);
            return NGX_ERROR;
        }
    }
    // hash表盛满键值对 hash桶要多大内存
    elts = ngx_palloc(hinit->pool, len + ngx_cacheline_size);
    if (elts == NULL) {
        ngx_free(test);
        return NGX_ERROR;
    }

    elts = ngx_align_ptr(elts, ngx_cacheline_size);
    /*
     * 已经给hash桶的内存已经分配好 起始地址是elts 每个hash桶要占用多大空间这个信息在test辅助数组中记录着
     * 很容易就可以把整个内存瓜分给每个hash桶
     * 此时test辅助数组中存放[0...size-1]每个桶需要的分配空间 空桶只有一个NULL指针占位 自然不用实际分配内存
     */
    for (i = 0; i < size; i++) {
        if (test[i] == sizeof(void *)) {
            // 空桶不用管
            continue;
        }
        /*
         * 每个hash桶分配的内存空间 起始地址 等真正存放元素的时候就后移指针就行
         * 分配给桶的空间已经包含了一个占位指针
         * 等键值对根据key的hash值定位到桶依次放完之后 桶里面就会在桶底剩下一个指针空间
         */
        buckets[i] = (ngx_hash_elt_t *) elts;
        elts += test[i];
    }
    // 下面要开始真正放键值对 键值对从桶顶开始放 放元素过程中用test辅助数组统计hash桶使用的空间 因此要在这个地方初始化0
    for (i = 0; i < size; i++) {
        test[i] = 0;
    }
    // 遍历键值对 逐个放到对应hash桶里面
    for (n = 0; n < nelts; n++) {
        if (names[n].key.data == NULL) {
            continue;
        }
        // hash桶数组脚标
        key = names[n].key_hash % size;
        // test数组中已经缓存好了每个桶的使用大小了 buckets[key]就是桶顶地址 键值对应该存放在桶里面位置
        elt = (ngx_hash_elt_t *) ((u_char *) buckets[key] + test[key]);
        // 存放键值对
        // 值
        elt->value = names[n].value;
        // 键的长度
        elt->len = (u_short) names[n].key.len;
        // 键
        ngx_strlow(elt->name, names[n].key.data, names[n].key.len);
        // 新的键值对已经存到了hash桶 此时hash桶的实际使用空间也要更新 加上新增键值对的占用空间
        test[key] = (u_short) (test[key] + NGX_HASH_ELT_SIZE(&names[n]));
    }
    /*
     * 这个时候已经实际上把所有键值对放到了hash桶
     * 但是在分配hash桶空间的时候是多分配了个sizeof(void*)的 这个指针的用处就是作为桶与桶之间分割符的
     * 遍历hash桶 在每个桶的底部插上NULL 也就是让每个桶底的指针都指向NULL
     */
    for (i = 0; i < size; i++) {
        if (buckets[i] == NULL) {
            // 空桶
            continue;
        }
        // 找到桶底插上NULL标识桶分界
        elt = (ngx_hash_elt_t *) ((u_char *) buckets[i] + test[i]);

        elt->value = NULL;
    }
    // 回收辅助数组
    ngx_free(test);

    hinit->hash->buckets = buckets;
    hinit->hash->size = size;

#if 0

    for (i = 0; i < size; i++) {
        ngx_str_t   val;
        ngx_uint_t  key;

        elt = buckets[i];

        if (elt == NULL) {
            ngx_log_error(NGX_LOG_ALERT, hinit->pool->log, 0,
                          "%ui: NULL", i);
            continue;
        }

        while (elt->value) {
            val.len = elt->len;
            val.data = &elt->name[0];

            key = hinit->key(val.data, val.len);

            ngx_log_error(NGX_LOG_ALERT, hinit->pool->log, 0,
                          "%ui: %p \"%V\" %ui", i, elt, &val, key);

            elt = (ngx_hash_elt_t *) ngx_align_ptr(&elt->name[0] + elt->len,
                                                   sizeof(void *));
        }
    }

#endif

    return NGX_OK;
}
```
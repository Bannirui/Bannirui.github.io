---
title: Redis-0x09-t_string
date: 2023-04-03 22:10:44
tags: [ Redis@6.2 ]
categories: [ Redis ]
---
数据类型String字符串。

## 1 string字符串 数据结构关系

| 数据类型         | 实现     | 编码方式                                           | 数据结构 |
| ---------------- | -------- | -------------------------------------------------- | -------- |
| 字符串OBJ_STRING | t_string | {% post_link Redis-0x04-sds OBJ_ENCODING_INT %}    | sds      |
|                  |          | {% post_link Redis-0x04-sds OBJ_ENCODING_EMBSTR %} | sds      |
|                  |          | {% post_link Redis-0x04-sds OBJ_ENCODING_RAW %}    | sds      |

## 2 增

### 2.1 set

```c
/**
 * @brief set命令入口 比如<t>set name dingrui</t>
 * @param c
 */
void setCommand(client *c) {
    robj *expire = NULL;
    int unit = UNIT_SECONDS;
    int flags = OBJ_NO_FLAGS;

    /**
     * 把set命令的可选项解析出来
     *   - 可选项命令掩码求和体现在flags上
     *   - 设置的过期时间值设置在expire上
     *   - 设置的过期时间单位设置在unit上
     */
    if (parseExtendedStringArgumentsOrReply(c,&flags,&unit,&expire,COMMAND_SET) != C_OK) {
        return;
    }

    /**
     * 尝试对字符串进行编码转换 目的是为了压缩内存
     *   - 字符串长度[1...20] 尝试用int编码
     *   - 字符串长度[1...4] 用EMBSTR编码
     *   - 字符串过长 用RAW编码
     */
    c->argv[2] = tryObjectEncoding(c->argv[2]);
    // 调用set命令
    setGenericCommand(c,flags,c->argv[1],c->argv[2],expire,unit,NULL,NULL);
}
```

### 2.2 解析set命令的可选项

```c
/**
 * @brief 解析命令的可选项内容
 *        get命令
 *          - GET key
 *          - get命令不存在可选参数
 *        set命令
 *          - SET key value [EX seconds] [PX milliseconds] [NX|XX]
 *          - set命令的可选参数设置是从脚标2开始
 * @param c
 * @param flags 命令可选项的掩码通过或计算体现在flags上
 * @param unit 命令设置了过期时间的时候时间单位 秒或者毫秒
 * @param expire 命令设置了过期时间的时候时间值
 * @param command_type 标识要解析的命令是get还是set
 * @return 操作状态码
 *         0标识成功
 *         -1标识失败
 */
int parseExtendedStringArgumentsOrReply(client *c, int *flags, int *unit, robj **expire, int command_type) {
    /**
     * 可选参数解析的脚标
     *   - get命令没有可选参数 不会进for循环
     *   - set命令从脚标2开始解析
     */
    int j = command_type == COMMAND_GET ? 2 : 3;
    for (; j < c->argc; j++) {
        //  可选参数的配置项
        char *opt = c->argv[j]->ptr;
        // 可选参数的配置值
        robj *next = (j == c->argc-1) ? NULL : c->argv[j+1];

        if ((opt[0] == 'n' || opt[0] == 'N') &&
            (opt[1] == 'x' || opt[1] == 'X') && opt[2] == '\0' &&
            !(*flags & OBJ_SET_XX) && !(*flags & OBJ_SET_GET) && (command_type == COMMAND_SET))
        { // NX
            *flags |= OBJ_SET_NX;
        } else if ((opt[0] == 'x' || opt[0] == 'X') &&
                   (opt[1] == 'x' || opt[1] == 'X') && opt[2] == '\0' &&
                   !(*flags & OBJ_SET_NX) && (command_type == COMMAND_SET))
        { // XX命令
            *flags |= OBJ_SET_XX;
        } else if ((opt[0] == 'g' || opt[0] == 'G') &&
                   (opt[1] == 'e' || opt[1] == 'E') &&
                   (opt[2] == 't' || opt[2] == 'T') && opt[3] == '\0' &&
                   !(*flags & OBJ_SET_NX) && (command_type == COMMAND_SET))
        {
            *flags |= OBJ_SET_GET;
        } else if (!strcasecmp(opt, "KEEPTTL") && !(*flags & OBJ_PERSIST) &&
            !(*flags & OBJ_EX) && !(*flags & OBJ_EXAT) &&
            !(*flags & OBJ_PX) && !(*flags & OBJ_PXAT) && (command_type == COMMAND_SET))
        {
            *flags |= OBJ_KEEPTTL;
        } else if (!strcasecmp(opt,"PERSIST") && (command_type == COMMAND_GET) &&
               !(*flags & OBJ_EX) && !(*flags & OBJ_EXAT) &&
               !(*flags & OBJ_PX) && !(*flags & OBJ_PXAT) &&
               !(*flags & OBJ_KEEPTTL))
        {
            *flags |= OBJ_PERSIST;
        } else if ((opt[0] == 'e' || opt[0] == 'E') &&
                   (opt[1] == 'x' || opt[1] == 'X') && opt[2] == '\0' &&
                   !(*flags & OBJ_KEEPTTL) && !(*flags & OBJ_PERSIST) &&
                   !(*flags & OBJ_EXAT) && !(*flags & OBJ_PX) &&
                   !(*flags & OBJ_PXAT) && next)
        { // EX命令
            *flags |= OBJ_EX;
            *expire = next;
            j++;
        } else if ((opt[0] == 'p' || opt[0] == 'P') &&
                   (opt[1] == 'x' || opt[1] == 'X') && opt[2] == '\0' &&
                   !(*flags & OBJ_KEEPTTL) && !(*flags & OBJ_PERSIST) &&
                   !(*flags & OBJ_EX) && !(*flags & OBJ_EXAT) &&
                   !(*flags & OBJ_PXAT) && next)
        { // PX命令
            *flags |= OBJ_PX;
            *unit = UNIT_MILLISECONDS;
            *expire = next;
            j++;
        } else if ((opt[0] == 'e' || opt[0] == 'E') &&
                   (opt[1] == 'x' || opt[1] == 'X') &&
                   (opt[2] == 'a' || opt[2] == 'A') &&
                   (opt[3] == 't' || opt[3] == 'T') && opt[4] == '\0' &&
                   !(*flags & OBJ_KEEPTTL) && !(*flags & OBJ_PERSIST) &&
                   !(*flags & OBJ_EX) && !(*flags & OBJ_PX) &&
                   !(*flags & OBJ_PXAT) && next)
        {
            *flags |= OBJ_EXAT;
            *expire = next;
            j++;
        } else if ((opt[0] == 'p' || opt[0] == 'P') &&
                   (opt[1] == 'x' || opt[1] == 'X') &&
                   (opt[2] == 'a' || opt[2] == 'A') &&
                   (opt[3] == 't' || opt[3] == 'T') && opt[4] == '\0' &&
                   !(*flags & OBJ_KEEPTTL) && !(*flags & OBJ_PERSIST) &&
                   !(*flags & OBJ_EX) && !(*flags & OBJ_EXAT) &&
                   !(*flags & OBJ_PX) && next)
        {
            *flags |= OBJ_PXAT;
            *unit = UNIT_MILLISECONDS;
            *expire = next;
            j++;
        } else {
            addReplyErrorObject(c,shared.syntaxerr);
            return C_ERR;
        }
    }
    return C_OK;
}
```

### 2.3 set全参

```c
/**
 * @brief set命令的全参调用
 * @param c
 * @param flags 体现了set命令的可选项命令 NX XX EX PX等可选项的或运算
 * @param key 键
 * @param val 值
 * @param expire 设置了过期 过期的值
 * @param unit 设置了过期 过期的时间单位
 * @param ok_reply
 * @param abort_reply
 */
void setGenericCommand(client *c, int flags, robj *key, robj *val, robj *expire, int unit, robj *ok_reply, robj *abort_reply) {
    long long milliseconds = 0, when = 0; /* initialized to avoid any harmness warning */

    if (expire) { // 设置了过期
        if (getLongLongFromObjectOrReply(c, expire, &milliseconds, NULL) != C_OK)
            return;
        if (milliseconds <= 0 || (unit == UNIT_SECONDS && milliseconds > LLONG_MAX / 1000)) {
            /* Negative value provided or multiplication is gonna overflow. */
            addReplyErrorFormat(c, "invalid expire time in %s", c->cmd->name);
            return;
        }
        if (unit == UNIT_SECONDS) milliseconds *= 1000;
        when = milliseconds;
        if ((flags & OBJ_PX) || (flags & OBJ_EX))
            when += mstime();
        if (when <= 0) {
            /* Overflow detected. */
            addReplyErrorFormat(c, "invalid expire time in %s", c->cmd->name);
            return;
        }
    }

    if ((flags & OBJ_SET_NX && lookupKeyWrite(c->db,key) != NULL) ||
        (flags & OBJ_SET_XX && lookupKeyWrite(c->db,key) == NULL))
    {
        /**
         * NX语义是键不存在时才执行set命令
         *   - 已经存在了键 那就不执行set命令
         * XX语义是键存在时才执行set命令
         *   - 不存在键 那就不执行set命令
         */
        addReply(c, abort_reply ? abort_reply : shared.null[c->resp]);
        return;
    }

    if (flags & OBJ_SET_GET) { // set之前先执行GET命令
        if (getGenericCommand(c) == C_ERR) return;
    }

    // 存到内存数据库中
    genericSetKey(c,c->db,key, val,flags & OBJ_KEEPTTL,1);
    server.dirty++;
    notifyKeyspaceEvent(NOTIFY_STRING,"set",key,c->db->id);
    if (expire) {
        /**
         * 对key设置了过期时间
         *   - 要么在过期时间dict中新增key的过期时间
         *   - 要么在过期时间dict中覆盖key的过期时间
         */
        setExpire(c,c->db,key,when);
        notifyKeyspaceEvent(NOTIFY_GENERIC,"expire",key,c->db->id);

        /* Propagate as SET Key Value PXAT millisecond-timestamp if there is EXAT/PXAT or
         * propagate as SET Key Value PX millisecond if there is EX/PX flag.
         *
         * Additionally when we propagate the SET with PX (relative millisecond) we translate
         * it again to SET with PXAT for the AOF.
         *
         * Additional care is required while modifying the argument order. AOF relies on the
         * exp argument being at index 3. (see feedAppendOnlyFile)
         * */
        robj *exp = (flags & OBJ_PXAT) || (flags & OBJ_EXAT) ? shared.pxat : shared.px;
        robj *millisecondObj = createStringObjectFromLongLong(milliseconds);
        rewriteClientCommandVector(c,5,shared.set,key,val,exp,millisecondObj);
        decrRefCount(millisecondObj);
    }
    if (!(flags & OBJ_SET_GET)) {
        addReply(c, ok_reply ? ok_reply : shared.ok);
    }

    /* Propagate without the GET argument (Isn't needed if we had expire since in that case we completely re-written the command argv) */
    if ((flags & OBJ_SET_GET) && !expire) {
        int argc = 0;
        int j;
        robj **argv = zmalloc((c->argc-1)*sizeof(robj*));
        for (j=0; j < c->argc; j++) {
            char *a = c->argv[j]->ptr;
            /* Skip GET which may be repeated multiple times. */
            if (j >= 3 &&
                (a[0] == 'g' || a[0] == 'G') &&
                (a[1] == 'e' || a[1] == 'E') &&
                (a[2] == 't' || a[2] == 'T') && a[3] == '\0')
                continue;
            argv[argc++] = c->argv[j];
            incrRefCount(c->argv[j]);
        }
        replaceClientCommandVector(c, argc, argv);
    }
}
```

### 2.4 setrange

```c
/**
 * @brief setrange key offset value
 *        比如setrange name 3 zz
 *        键name的value是dingrui
 *        setrange name 3 zz的语义是dingrui字符串从脚标3(从0开始)开始，用zz这个新字符串替换掉gr这两个字符
 * @param c
 */
void setrangeCommand(client *c) {
    robj *o;
    long offset;
    sds value = c->argv[3]->ptr; // setrange命令的参数value
    // setrange命令中的offset参数
    if (getLongFromObjectOrReply(c,c->argv[2],&offset,NULL) != C_OK)
        return;

    if (offset < 0) {
        addReplyError(c,"offset is out of range");
        return;
    }

    // 旧值
    o = lookupKeyWrite(c->db,c->argv[1]);
    if (o == NULL) { // 不存在键
        /* Return 0 when setting nothing on a non-existing string */
        if (sdslen(value) == 0) {
            addReply(c,shared.czero);
            return;
        }

        /* Return when the resulting string exceeds allowed size */
        if (checkStringLength(c,offset+sdslen(value)) != C_OK)
            return;

        /**
         * 创建一个redisObject实例放到全局hash表中
         * 给sds开辟的内存大小=setrange命令的offset值+setrange命令的value长度
         * sds的buf数组里面现在还是空的
         */
        o = createObject(OBJ_STRING,sdsnewlen(NULL, offset+sdslen(value)));
        dbAdd(c->db,c->argv[1],o);
    } else { // key已经存在
        size_t olen;

        /* Key exists, check type */
        // 字符串类型
        if (checkType(c,o,OBJ_STRING))
            return;

        /* Return existing string length when setting nothing */
        // 字符串长度
        olen = stringObjectLen(o);
        if (sdslen(value) == 0) {
            addReplyLongLong(c,olen);
            return;
        }

        /* Return when the resulting string exceeds allowed size */
        if (checkStringLength(c,offset+sdslen(value)) != C_OK)
            return;

        /* Create a copy when the object is shared or encoded. */
        o = dbUnshareStringValue(c->db,c->argv[1],o); // 全局hash表查询key的值
    }

    if (sdslen(value) > 0) { // setrange命令里面的value
        /**
         * 此时的o是redisObject实例 其内容以及长度就两种情况
         *   - 长度为offset+len(value) 内容为null
         *   - 长度为len(oldVal) 内容为oldVal
         * 第一种情况是不用对sds扩容的
         */
        o->ptr = sdsgrowzero(o->ptr,offset+sdslen(value));
        // 将setrange命令的value拷贝到指定位置
        memcpy((char*)o->ptr+offset,value,sdslen(value));
        signalModifiedKey(c,c->db,c->argv[1]);
        notifyKeyspaceEvent(NOTIFY_STRING,
            "setrange",c->argv[1],c->db->id);
        server.dirty++;
    }
    addReplyLongLong(c,sdslen(o->ptr));
}
```

### 2.5 mset

```c
/**
 * @brief mset命令
 * @param c 
 * @param nx 标识
 *           1标识要求批量set的key都不存在 但凡有key已经存在就不生效
 *           0标识不要求批量set的key都不存在 即可以覆盖更新键值
 */
void msetGenericCommand(client *c, int nx) {
    int j;

    if ((c->argc % 2) == 0) { // 基本的参数个数校验
        addReplyError(c,"wrong number of arguments for MSET");
        return;
    }

    /* Handle the NX flag. The MSETNX semantic is to return zero and don't
     * set anything if at least one key already exists. */
    if (nx) { // 必须所有key都不存在
        for (j = 1; j < c->argc; j += 2) {
            if (lookupKeyWrite(c->db,c->argv[j]) != NULL) {
                addReply(c, shared.czero);
                return;
            }
        }
    }

    // 成对的key-value
    for (j = 1; j < c->argc; j += 2) {
        c->argv[j+1] = tryObjectEncoding(c->argv[j+1]);
        setKey(c,c->db,c->argv[j],c->argv[j+1]);
        notifyKeyspaceEvent(NOTIFY_STRING,"set",c->argv[j],c->db->id);
    }
    server.dirty += (c->argc-1)/2;
    addReply(c, nx ? shared.cone : shared.ok);
}
```

## 3 删

## 4 改

### 4.1 递增递减

```c
/**
 * @brief 递增\递减incr
 * @param c 
 * @param incr 要递增\递减的值
 */
void incrDecrCommand(client *c, long long incr) {
    long long value, oldvalue;
    robj *o, *new;

    o = lookupKeyWrite(c->db,c->argv[1]);
    if (checkType(c,o,OBJ_STRING)) return; // 数据类型校验
    if (getLongLongFromObjectOrReply(c,o,&value,NULL) != C_OK) return;
    // 递增\递减前的值
    oldvalue = value;
    if ((incr < 0 && oldvalue < 0 && incr < (LLONG_MIN-oldvalue)) ||
        (incr > 0 && oldvalue > 0 && incr > (LLONG_MAX-oldvalue))) {
        addReplyError(c,"increment or decrement would overflow");
        return;
    }
    value += incr;

    if (o && o->refcount == 1 && o->encoding == OBJ_ENCODING_INT &&
        (value < 0 || value >= OBJ_SHARED_INTEGERS) &&
        value >= LONG_MIN && value <= LONG_MAX)
    {
        new = o;
        o->ptr = (void*)((long)value);
    } else {
        new = createStringObjectFromLongLongForValue(value);
        if (o) {
            dbOverwrite(c->db,c->argv[1],new);
        } else {
            dbAdd(c->db,c->argv[1],new);
        }
    }
    signalModifiedKey(c,c->db,c->argv[1]);
    notifyKeyspaceEvent(NOTIFY_STRING,"incrby",c->argv[1],c->db->id);
    server.dirty++;
    addReply(c,shared.colon);
    addReply(c,new);
    addReply(c,shared.crlf);
}
```

## 5 查

### 5.1 get

```c
/**
 * @brief get命令入口
 * @param c
 */
void getCommand(client *c) {
    getGenericCommand(c);
}
```

### 5.2 get全参

```c
/**
 * @brief get命令的全参调用 因为get命令没有可选参数 所以全参的get调用和get的入口调用是一样的
 * @param c
 * @return 操作状态吗
 *         0标识成功
 *         -1标识失败
 */
int getGenericCommand(client *c) {
    robj *o;

    // 全局字典查找键
    if ((o = lookupKeyReadOrReply(c,c->argv[1],shared.null[c->resp])) == NULL)
        return C_OK;

    if (checkType(c,o,OBJ_STRING)) { // 校验数据类型得是string字符串
        return C_ERR;
    }
    // 网络模块负责响应客户端
    addReplyBulk(c,o);
    return C_OK;
}
```

### 5.3 getex

```c
/**
 * @brief getex命令 可选项
 *          - persist 如果键此前设置过过期时间 将过期时间从过期dict中移除
 *          - 为键key设置过期时间
 *            - ex 为key设置秒为单位的过期时间
 *            - px 为key设置以毫秒为单位的过期时间
 *            - exat 为key设置秒为单位的过期时间戳
 *            - pxat 为key设置毫秒为单位的过期时间戳
 *         getex不设置可选项 就相当于get命令
 * @param c
 */
void getexCommand(client *c) {
    robj *expire = NULL;
    int unit = UNIT_SECONDS;
    int flags = OBJ_NO_FLAGS;

    if (parseExtendedStringArgumentsOrReply(c,&flags,&unit,&expire,COMMAND_GET) != C_OK) {
        return;
    }

    robj *o;
    // 全局哈希表中不存在key
    if ((o = lookupKeyReadOrReply(c,c->argv[1],shared.null[c->resp])) == NULL)
        return;

    // 确保数据类型是string字符串
    if (checkType(c,o,OBJ_STRING)) {
        return;
    }

    long long milliseconds = 0, when = 0;

    /* Validate the expiration time value first */
    if (expire) { // 设置了过期时间
        if (getLongLongFromObjectOrReply(c, expire, &milliseconds, NULL) != C_OK)
            return;
        if (milliseconds <= 0 || (unit == UNIT_SECONDS && milliseconds > LLONG_MAX / 1000)) {
            /* Negative value provided or multiplication is gonna overflow. */
            addReplyErrorFormat(c, "invalid expire time in %s", c->cmd->name);
            return;
        }
        if (unit == UNIT_SECONDS) milliseconds *= 1000;
        when = milliseconds;
        if ((flags & OBJ_PX) || (flags & OBJ_EX))
            when += mstime();
        if (when <= 0) {
            /* Overflow detected. */
            addReplyErrorFormat(c, "invalid expire time in %s", c->cmd->name);
            return;
        }
    }

    /* We need to do this before we expire the key or delete it */
    // 将get出来的值返回给客户端
    addReplyBulk(c,o);

    /* This command is never propagated as is. It is either propagated as PEXPIRE[AT],DEL,UNLINK or PERSIST.
     * This why it doesn't need special handling in feedAppendOnlyFile to convert relative expire time to absolute one. */
    if (((flags & OBJ_PXAT) || (flags & OBJ_EXAT)) && checkAlreadyExpired(milliseconds)) { // 设置了过期时间戳
        /* When PXAT/EXAT absolute timestamp is specified, there can be a chance that timestamp
         * has already elapsed so delete the key in that case. */
        int deleted = server.lazyfree_lazy_expire ? dbAsyncDelete(c->db, c->argv[1]) :
                      dbSyncDelete(c->db, c->argv[1]);
        serverAssert(deleted);
        robj *aux = server.lazyfree_lazy_expire ? shared.unlink : shared.del;
        rewriteClientCommandVector(c,2,aux,c->argv[1]);
        signalModifiedKey(c, c->db, c->argv[1]);
        notifyKeyspaceEvent(NOTIFY_GENERIC, "del", c->argv[1], c->db->id);
        server.dirty++;
    } else if (expire) {
        setExpire(c,c->db,c->argv[1],when);
        /* Propagate */
        robj *exp = (flags & OBJ_PXAT) || (flags & OBJ_EXAT) ? shared.pexpireat : shared.pexpire;
        robj* millisecondObj = createStringObjectFromLongLong(milliseconds);
        rewriteClientCommandVector(c,3,exp,c->argv[1],millisecondObj);
        decrRefCount(millisecondObj);
        signalModifiedKey(c, c->db, c->argv[1]);
        notifyKeyspaceEvent(NOTIFY_GENERIC,"expire",c->argv[1],c->db->id);
        server.dirty++;
    } else if (flags & OBJ_PERSIST) { // 移除key的过期时间
        if (removeExpire(c->db, c->argv[1])) {
            signalModifiedKey(c, c->db, c->argv[1]);
            rewriteClientCommandVector(c, 2, shared.persist, c->argv[1]);
            notifyKeyspaceEvent(NOTIFY_GENERIC,"persist",c->argv[1],c->db->id);
            server.dirty++;
        }
    }
}
```

### 5.4 getdel

```c
/**
 * @brief 获取键的值 获取后将键删除
 * @param c
 */
void getdelCommand(client *c) {
    if (getGenericCommand(c) == C_ERR) return;
    int deleted = server.lazyfree_lazy_user_del ? dbAsyncDelete(c->db, c->argv[1]) :
                  dbSyncDelete(c->db, c->argv[1]);
    if (deleted) {
        /* Propagate as DEL/UNLINK command */
        robj *aux = server.lazyfree_lazy_user_del ? shared.unlink : shared.del;
        rewriteClientCommandVector(c,2,aux,c->argv[1]);
        signalModifiedKey(c, c->db, c->argv[1]);
        notifyKeyspaceEvent(NOTIFY_GENERIC, "del", c->argv[1], c->db->id);
        server.dirty++;
    }
}
```

### 5.5 getset

```c
/**
 * @brief getset获取key的值 获取完后为key设置新值
 *        比如: getset name dingrui
 * @param c 
 */
void getsetCommand(client *c) {
    // 获取key的值
    if (getGenericCommand(c) == C_ERR) return;
    // 要设置的新值 压缩字符串内存
    c->argv[2] = tryObjectEncoding(c->argv[2]);
    // set命令
    setKey(c,c->db,c->argv[1],c->argv[2]);
    notifyKeyspaceEvent(NOTIFY_STRING,"set",c->argv[1],c->db->id);
    server.dirty++;

    /* Propagate as SET command */
    rewriteClientCommandArgument(c,0,shared.set);
}
```

### 5.6 getrange

```c
/**
 * @brief getrange key start end
 *        获取key的[start...end]位置的子串
 *          - 如果没有这个key 不管start和end参数如何 就返回""空字符串
 *          - 数据库存在key 将key对应的value[start...end]子串返回给客户端
 * @param c
 */
void getrangeCommand(client *c) {
    robj *o;
    long long start, end;
    char *str, llbuf[32];
    size_t strlen;

    if (getLongLongFromObjectOrReply(c,c->argv[2],&start,NULL) != C_OK)
        return;
    if (getLongLongFromObjectOrReply(c,c->argv[3],&end,NULL) != C_OK)
        return;
    // 从数据库查询键
    if ((o = lookupKeyReadOrReply(c,c->argv[1],shared.emptybulk)) == NULL ||
        checkType(c,o,OBJ_STRING)) return;

    if (o->encoding == OBJ_ENCODING_INT) { // 字符串的编码是int
        str = llbuf;
        strlen = ll2string(llbuf,sizeof(llbuf),(long)o->ptr);
    } else { // 字符串编码是EMBSTR或RAW
        str = o->ptr;
        strlen = sdslen(str);
    }

    /* Convert negative indexes */
    if (start < 0 && end < 0 && start > end) {
        addReply(c,shared.emptybulk);
        return;
    }
    if (start < 0) start = strlen+start;
    if (end < 0) end = strlen+end;
    if (start < 0) start = 0;
    if (end < 0) end = 0;
    if ((unsigned long long)end >= strlen) end = strlen-1;

    /* Precondition: end >= 0 && end < strlen, so the only condition where
     * nothing can be returned is: start > end. */
    if (start > end || strlen == 0) {
        addReply(c,shared.emptybulk);
    } else {
        addReplyBulkCBuffer(c,(char*)str+start,end-start+1);
    }
}
```

### 5.7 mget

```c
/**
 * @brief mget k1 k2 k3
 *        获取多个key
 * @param c 
 */
void mgetCommand(client *c) {
    int j;

    addReplyArrayLen(c,c->argc-1);
    for (j = 1; j < c->argc; j++) {
        // 轮询要要查找的所有key
        robj *o = lookupKeyRead(c->db,c->argv[j]);
        if (o == NULL) {
            addReplyNull(c);
        } else {
            if (o->type != OBJ_STRING) {
                addReplyNull(c);
            } else {
                addReplyBulk(c,o);
            }
        }
    }
}
```


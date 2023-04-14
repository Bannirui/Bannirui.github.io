---
title: Redis-0x1c-serverCron任务
date: 2023-04-14 09:36:57
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

## 1 serverCron大任务

```c
/**
 * @brief 事件管理器eventLoop面向的是事件的管理
 *          - 时间事件是自己亲自管理
 *          - 文件事件的管理主要委托给OS的IO复用器 而自己本身工作中心在于就绪事件的调度
 *        因此需要明确知道时间事件的id
 *        eventLoop才能根据时间事件id在自己管理范围内找到时间事件
 *        当初注册时间事件的时候指定过私有数据
 *        此刻eventLoop回调函数的时候就可以使用私有数据了
 *
 *        这个serverCron是redis服务端的一个大的定时任务 这个大的任务执行线程仍然是main线程 其中定义了很多小的任务
 *          - 看门狗
 *            - 默认不开启
 *          - 服务端性能指标采集
 *            - 每秒执行的命令个数  main线程执行   每100ms执行一次
 *            - 每秒读流量         main线程执行   每100ms执行一次
 *            - 每秒写流量         main线程执行   每100ms执行一次
 *          - 内存相关信息采集
 *            - 内存使用峰值       main线程执行    大任务执行频率
 *            - 使用使用信息       main线程执行    每100ms执行一次
 * @param eventLoop 事件管理器
 * @param id 时间事件的id
 * @param clientData 向eventLoop注册时间事件时候指定的私有数据 就是用在函数回调的时候的
 * @return 该函数是时间事件的处理器 其返回值语义是告知eventLoop事件管理器在调度执行完一次时间事件之后 后续如何管理这个事件
 *           - 返回1 标识时间事件是个定时事件 只执行一次 以后不用再执行
 *           - 返回n 标识这个时间事件是个周期性事件 期待等个n毫秒之后再执行一次
 */
int serverCron(struct aeEventLoop *eventLoop, long long id, void *clientData) {
    int j;
    UNUSED(eventLoop);
    UNUSED(id);
    UNUSED(clientData);

    /* Software watchdog: deliver the SIGALRM that will reach the signal
     * handler if we don't return here fast enough. */
    /**
     * 看门狗
     * 默认不开启
     */
    if (server.watchdog_period) watchdogScheduleSignal(server.watchdog_period);

    /* Update the time cache. */
    /**
     * 将系统时间缓存在服务端
     * 很多地方都要用到这个时间 缓存起来 避免了每次使用都要一次系统调用的开销
     */
    updateCachedTime(1);

    /**
     * 动态调整serverCron的运行频率
     * 跟当前服务端通信的客户端越多 定时任务执行的频率越快
     */
    server.hz = server.config_hz;
    /* Adapt the server.hz value to the number of configured clients. If we have
     * many clients, we want to call serverCron() with an higher frequency. */
    if (server.dynamic_hz) { // 默认false 不开启动态调整serverCron执行频率
        while (listLength(server.clients) / server.hz >
               MAX_CLIENTS_PER_CLOCK_TICK)
        {
            server.hz *= 2;
            if (server.hz > CONFIG_MAX_HZ) {
                server.hz = CONFIG_MAX_HZ;
                break;
            }
        }
    }

    run_with_period(100) { // 每100ms执行一次
        long long stat_net_input_bytes, stat_net_output_bytes;
        atomicGet(server.stat_net_input_bytes, stat_net_input_bytes);
        atomicGet(server.stat_net_output_bytes, stat_net_output_bytes);

        // main线程执行 记录每秒执行的命令个数
        trackInstantaneousMetric(STATS_METRIC_COMMAND,server.stat_numcommands);
        // main线程执行 记录读流量
        trackInstantaneousMetric(STATS_METRIC_NET_INPUT,
                stat_net_input_bytes);
        // main线程执行 记录写流量
        trackInstantaneousMetric(STATS_METRIC_NET_OUTPUT,
                stat_net_output_bytes);
    }

    /* We have just LRU_BITS bits per object for LRU information.
     * So we use an (eventually wrapping) LRU clock.
     *
     * Note that even if the counter wraps it's not a big problem,
     * everything will still work but some object will appear younger
     * to Redis. However for this to happen a given object should never be
     * touched for all the time needed to the counter to wrap, which is
     * not likely.
     *
     * Note that you can change the resolution altering the
     * LRU_CLOCK_RESOLUTION define. */
    unsigned int lruclock = getLRUClock();
    atomicSet(server.lruclock,lruclock);

    /**
     * 采集内存使用相关信息
     *   - 记录内存使用峰值 main线程 serverCron大任务执行频率
     *   - 内存的使用信息  main线程  每隔100ms
     */
    cronUpdateMemoryStats();

    /* We received a SIGTERM, shutting down here in a safe way, as it is
     * not ok doing so inside the signal handler. */
    if (server.shutdown_asap) {
        if (prepareForShutdown(SHUTDOWN_NOFLAGS) == C_OK) exit(0);
        serverLog(LL_WARNING,"SIGTERM received but errors trying to shut down the server, check the logs for more information");
        server.shutdown_asap = 0;
    }

    /* Show some info about non-empty databases */
    if (server.verbosity <= LL_VERBOSE) {
        run_with_period(5000) {
            for (j = 0; j < server.dbnum; j++) {
                long long size, used, vkeys;

                size = dictSlots(server.db[j].dict);
                used = dictSize(server.db[j].dict);
                vkeys = dictSize(server.db[j].expires);
                if (used || vkeys) {
                    serverLog(LL_VERBOSE,"DB %d: %lld keys (%lld volatile) in %lld slots HT.",j,used,vkeys,size);
                }
            }
        }
    }

    /* Show information about connected clients */
    if (!server.sentinel_mode) {
        run_with_period(5000) {
            serverLog(LL_DEBUG,
                "%lu clients connected (%lu replicas), %zu bytes in use",
                listLength(server.clients)-listLength(server.slaves),
                listLength(server.slaves),
                zmalloc_used_memory());
        }
    }

    /* We need to do a few operations on clients asynchronously. */
    clientsCron();

    /* Handle background operations on Redis databases. */
    databasesCron();

    /* Start a scheduled AOF rewrite if this was requested by the user while
     * a BGSAVE was in progress. */
    if (!hasActiveChildProcess() &&
        server.aof_rewrite_scheduled)
    {
        rewriteAppendOnlyFileBackground();
    }

    /* Check if a background saving or AOF rewrite in progress terminated. */
    if (hasActiveChildProcess() || ldbPendingChildren())
    {
        run_with_period(1000) receiveChildInfo();
        checkChildrenDone();
    } else {
        /* If there is not a background saving/rewrite in progress check if
         * we have to save/rewrite now. */
        for (j = 0; j < server.saveparamslen; j++) {
            struct saveparam *sp = server.saveparams+j;

            /* Save if we reached the given amount of changes,
             * the given amount of seconds, and if the latest bgsave was
             * successful or if, in case of an error, at least
             * CONFIG_BGSAVE_RETRY_DELAY seconds already elapsed. */
            if (server.dirty >= sp->changes &&
                server.unixtime-server.lastsave > sp->seconds &&
                (server.unixtime-server.lastbgsave_try >
                 CONFIG_BGSAVE_RETRY_DELAY ||
                 server.lastbgsave_status == C_OK))
            {
                serverLog(LL_NOTICE,"%d changes in %d seconds. Saving...",
                    sp->changes, (int)sp->seconds);
                rdbSaveInfo rsi, *rsiptr;
                rsiptr = rdbPopulateSaveInfo(&rsi);
                rdbSaveBackground(server.rdb_filename,rsiptr);
                break;
            }
        }

        /* Trigger an AOF rewrite if needed. */
        if (server.aof_state == AOF_ON &&
            !hasActiveChildProcess() &&
            server.aof_rewrite_perc &&
            server.aof_current_size > server.aof_rewrite_min_size)
        {
            long long base = server.aof_rewrite_base_size ?
                server.aof_rewrite_base_size : 1;
            long long growth = (server.aof_current_size*100/base) - 100;
            if (growth >= server.aof_rewrite_perc) {
                serverLog(LL_NOTICE,"Starting automatic rewriting of AOF on %lld%% growth",growth);
                rewriteAppendOnlyFileBackground();
            }
        }
    }
    /* Just for the sake of defensive programming, to avoid forgeting to
     * call this function when need. */
    updateDictResizePolicy();


    /* AOF postponed flush: Try at every cron cycle if the slow fsync
     * completed. */
    if (server.aof_state == AOF_ON && server.aof_flush_postponed_start)
        flushAppendOnlyFile(0);

    /* AOF write errors: in this case we have a buffer to flush as well and
     * clear the AOF error in case of success to make the DB writable again,
     * however to try every second is enough in case of 'hz' is set to
     * a higher frequency. */
    run_with_period(1000) {
        if (server.aof_state == AOF_ON && server.aof_last_write_status == C_ERR)
            flushAppendOnlyFile(0);
    }

    /* Clear the paused clients state if needed. */
    checkClientPauseTimeoutAndReturnIfPaused();

    /* Replication cron function -- used to reconnect to master,
     * detect transfer failures, start background RDB transfers and so forth. 
     * 
     * If Redis is trying to failover then run the replication cron faster so
     * progress on the handshake happens more quickly. */
    if (server.failover_state != NO_FAILOVER) {
        run_with_period(100) replicationCron();
    } else {
        run_with_period(1000) replicationCron();
    }

    /* Run the Redis Cluster cron. */
    run_with_period(100) {
        if (server.cluster_enabled) clusterCron();
    }

    /* Run the Sentinel timer if we are in sentinel mode. */
    if (server.sentinel_mode) sentinelTimer();

    /* Cleanup expired MIGRATE cached sockets. */
    run_with_period(1000) {
        migrateCloseTimedoutSockets();
    }

    /* Stop the I/O threads if we don't have enough pending work. */
    stopThreadedIOIfNeeded();

    /* Resize tracking keys table if needed. This is also done at every
     * command execution, but we want to be sure that if the last command
     * executed changes the value via CONFIG SET, the server will perform
     * the operation even if completely idle. */
    if (server.tracking_clients) trackingLimitUsedSlots();

    /* Start a scheduled BGSAVE if the corresponding flag is set. This is
     * useful when we are forced to postpone a BGSAVE because an AOF
     * rewrite is in progress.
     *
     * Note: this code must be after the replicationCron() call above so
     * make sure when refactoring this file to keep this order. This is useful
     * because we want to give priority to RDB savings for replication. */
    if (!hasActiveChildProcess() &&
        server.rdb_bgsave_scheduled &&
        (server.unixtime-server.lastbgsave_try > CONFIG_BGSAVE_RETRY_DELAY ||
         server.lastbgsave_status == C_OK))
    {
        rdbSaveInfo rsi, *rsiptr;
        rsiptr = rdbPopulateSaveInfo(&rsi);
        if (rdbSaveBackground(server.rdb_filename,rsiptr) == C_OK)
            server.rdb_bgsave_scheduled = 0;
    }

    /* Fire the cron loop modules event. */
    RedisModuleCronLoopV1 ei = {REDISMODULE_CRON_LOOP_VERSION,server.hz};
    moduleFireServerEvent(REDISMODULE_EVENT_CRON_LOOP,
                          0,
                          &ei);

    // 记录serverCron这个大定时任务执行了多少次
    server.cronloops++;
    // hz配置在redis.conf配置文件中 默认值是10 也就是这个定时任务1s执行10次 即每隔100ms执行一次
    return 1000/server.hz;
}
```

## 2 定制化运行间隔时长

```c
/**
 * @brief 这个宏用来控制serverCron里面小任务多久执行一次
 *        首先界定一件事情 hz在redis.conf配置文件中定义的默认值是10 也就意味着serverCron这个大定时任务每隔100ms会被main线程执行一次
 *        这个宏函数就是用来控制某个小任务间隔多久执行一次的
 *          - 场景1 ms==10 间隔<serverCron的运行间隔 也就是说所有小任务的间隔时间下限就是serverCron的运行间隔时间 单独设置小任务的间隔时间 只有更大才有客制化意义
 *          - 场景2 ms==100 间隔==serverCron的运行间隔 跟场景1一样
 *          - 场景3 ms==1000 代入表达式 即意味着cronloops得是10的整数倍才能运行小任务 也就是小任务运行间隔是10轮大任务的间隔时间 即10*100=1000ms
 *          - 场景4 ms=1001 代入表达式 向下取整 同场景3
 *          - 场景5 ms=5000 代入表达式 小任务的运行间隔是50轮大任务运行间隔 即50轮*100ms=5000ms
 *        那也就意味着
 *        当我们觉得小任务运行间隔时间需要客制化时候 并且明显不需要像serverCron大任务一样频繁的时候 就传递一个大任务运行间隔的整数倍的间隔参数
 * @param ms 希望小任务多久执行一次 单位ms
 */
#define run_with_period(_ms_) if ((_ms_ <= 1000/server.hz) || !(server.cronloops%((_ms_)/(1000/server.hz))))
```

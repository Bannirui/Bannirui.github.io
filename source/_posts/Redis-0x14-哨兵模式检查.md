---
title: Redis-0x14-哨兵模式检查
date: 2023-04-11 21:59:26
category_bar: true
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

检查当前进程，即服务启动是否以哨兵模式进行，在redisServer实例中用`sentinel_mode`字段进行标识。

```c
/**
 * @brief 判定redis启动模式是哨兵模式
 *          - 要么启动的直接就是redis-sentinel可执行文件
 *          - 要么在启动参数中指定了--sentinel可选项
 * @param argc 启动参数数量
 * @param argv 启动参数
 * @return 0-不是以哨兵模式启动
 *         1-以哨兵模式启动
 */
int checkForSentinelMode(int argc, char **argv) {
    int j;

    if (strstr(argv[0],"redis-sentinel") != NULL) return 1; // 启动的是redis-sentinel
    for (j = 1; j < argc; j++)
        if (!strcmp(argv[j],"--sentinel")) return 1; // 启动参数中指定了--sentinel
    return 0;
}
```


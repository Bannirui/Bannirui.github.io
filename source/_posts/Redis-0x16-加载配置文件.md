---
title: Redis-0x16-加载配置文件
date: 2023-04-12 09:45:25
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

将配置项赋值给redisServer实例的字段，用于后面的服务端启动。配置无非就来自2个地方：

* 服务启动参数指定的配置文件redis.conf
* 服务启动参数指定的配置项

## 1 汇总配置内容

```c
/**
 * @brief 将指定配置地方的配置内容都读取到sds中 然后统一将配置内容加载到redisServer实例的字段中
 * @param filename 配置来源-文件
 * @param config_from_stdin 配置来源-命令行标准输入
 * @param options 配置来源-字符串
 */
void loadServerConfig(char *filename, char config_from_stdin, char *options) {
    // 缓存配置内容
    sds config = sdsempty();
    char buf[CONFIG_MAX_LINE+1];
    FILE *fp;

    /* Load the file content */
    // 文件中配置项读取到config中
    if (filename) {
        if ((fp = fopen(filename,"r")) == NULL) {
            serverLog(LL_WARNING,
                    "Fatal error, can't open config file '%s': %s",
                    filename, strerror(errno));
            exit(1);
        }
        while(fgets(buf,CONFIG_MAX_LINE+1,fp) != NULL)
            config = sdscat(config,buf);
        fclose(fp);
    }
    /* Append content from stdin */
    // 命令行配置读取到config中
    if (config_from_stdin) {
        serverLog(LL_WARNING,"Reading config from stdin");
        fp = stdin;
        while(fgets(buf,CONFIG_MAX_LINE+1,fp) != NULL)
            config = sdscat(config,buf);
    }

    /* Append the additional options */
    // options的字符串内容读取到config中
    if (options) {
        config = sdscat(config,"\n");
        config = sdscat(config,options);
    }
    // 尝试将配置加载到redisServer实例字段中
    loadServerConfigFromString(config);
    sdsfree(config);
}
```

## 2 redisServer赋值

```c
/**
 * @brief 解析配置内容 加载到redisServer实例字段中
 * @param config sds实例 指针指向的是sds的buf数组
 */
void loadServerConfigFromString(char *config) {
    const char *err = NULL;
    int linenum = 0, totlines, i;
    int slaveof_linenum = 0;
    sds *lines;
    int save_loaded = 0;

    /**
     * 以换行符为切割符切割config配置内容
     *   - 切割的子串结果放在lines这个数组里面
     *   - 切割的子串数量放在totlines中
     */
    lines = sdssplitlen(config,strlen(config),"\n",1,&totlines);

    for (i = 0; i < totlines; i++) {
        sds *argv;
        int argc;

        linenum = i+1;
        lines[i] = sdstrim(lines[i]," \t\r\n");

        /* Skip comments and blank lines */
        if (lines[i][0] == '#' || lines[i][0] == '\0') continue;

        /* Split into arguments */
        argv = sdssplitargs(lines[i],&argc);
        if (argv == NULL) {
            err = "Unbalanced quotes in configuration line";
            goto loaderr;
        }

        /* Skip this line if the resulting command vector is empty. */
        if (argc == 0) {
            sdsfreesplitres(argv,argc);
            continue;
        }
        sdstolower(argv[0]);

        /* Iterate the configs that are standard */
        int match = 0;
        for (standardConfig *config = configs; config->name != NULL; config++) {
            if ((!strcasecmp(argv[0],config->name) ||
                (config->alias && !strcasecmp(argv[0],config->alias))))
            {
                if (argc != 2) {
                    err = "wrong number of arguments";
                    goto loaderr;
                }
                if (!config->interface.set(config->data, argv[1], 0, &err)) {
                    goto loaderr;
                }

                match = 1;
                break;
            }
        }

        if (match) {
            sdsfreesplitres(argv,argc);
            continue;
        }

        /* Execute config directives */
        if (!strcasecmp(argv[0],"bind") && argc >= 2) {
            int j, addresses = argc-1;

            if (addresses > CONFIG_BINDADDR_MAX) {
                err = "Too many bind addresses specified"; goto loaderr;
            }
            /* Free old bind addresses */
            for (j = 0; j < server.bindaddr_count; j++) {
                zfree(server.bindaddr[j]);
            }
            for (j = 0; j < addresses; j++)
                server.bindaddr[j] = zstrdup(argv[j+1]);
            server.bindaddr_count = addresses;
        } else if (!strcasecmp(argv[0],"unixsocketperm") && argc == 2) {
            errno = 0;
            server.unixsocketperm = (mode_t)strtol(argv[1], NULL, 8);
            if (errno || server.unixsocketperm > 0777) {
                err = "Invalid socket file permissions"; goto loaderr;
            }
        } else if (!strcasecmp(argv[0],"save")) {
            /* We don't reset save params before loading, because if they're not part
             * of the file the defaults should be used.
             */
            if (!save_loaded) {
                save_loaded = 1;
                resetServerSaveParams();
            }

            if (argc == 3) {
                int seconds = atoi(argv[1]);
                int changes = atoi(argv[2]);
                if (seconds < 1 || changes < 0) {
                    err = "Invalid save parameters"; goto loaderr;
                }
                appendServerSaveParams(seconds,changes);
            } else if (argc == 2 && !strcasecmp(argv[1],"")) {
                resetServerSaveParams();
            }
        } else if (!strcasecmp(argv[0],"dir") && argc == 2) {
            if (chdir(argv[1]) == -1) {
                serverLog(LL_WARNING,"Can't chdir to '%s': %s",
                    argv[1], strerror(errno));
                exit(1);
            }
        } else if (!strcasecmp(argv[0],"logfile") && argc == 2) {
            FILE *logfp;

            zfree(server.logfile);
            server.logfile = zstrdup(argv[1]);
            if (server.logfile[0] != '\0') {
                /* Test if we are able to open the file. The server will not
                 * be able to abort just for this problem later... */
                logfp = fopen(server.logfile,"a");
                if (logfp == NULL) {
                    err = sdscatprintf(sdsempty(),
                        "Can't open the log file: %s", strerror(errno));
                    goto loaderr;
                }
                fclose(logfp);
            }
        } else if (!strcasecmp(argv[0],"include") && argc == 2) {
            loadServerConfig(argv[1], 0, NULL);
        } else if ((!strcasecmp(argv[0],"slaveof") ||
                    !strcasecmp(argv[0],"replicaof")) && argc == 3) {
            slaveof_linenum = linenum;
            sdsfree(server.masterhost);
            if (!strcasecmp(argv[1], "no") && !strcasecmp(argv[2], "one")) {
                server.masterhost = NULL;
                continue;
            }
            server.masterhost = sdsnew(argv[1]);
            char *ptr;
            server.masterport = strtol(argv[2], &ptr, 10);
            if (server.masterport < 0 || server.masterport > 65535 || *ptr != '\0') {
                err = "Invalid master port"; goto loaderr;
            }
            server.repl_state = REPL_STATE_CONNECT;
        } else if (!strcasecmp(argv[0],"list-max-ziplist-entries") && argc == 2){
            /* DEAD OPTION */
        } else if (!strcasecmp(argv[0],"list-max-ziplist-value") && argc == 2) {
            /* DEAD OPTION */
        } else if (!strcasecmp(argv[0],"rename-command") && argc == 3) {
            struct redisCommand *cmd = lookupCommand(argv[1]);
            int retval;

            if (!cmd) {
                err = "No such command in rename-command";
                goto loaderr;
            }

            /* If the target command name is the empty string we just
             * remove it from the command table. */
            retval = dictDelete(server.commands, argv[1]);
            serverAssert(retval == DICT_OK);

            /* Otherwise we re-add the command under a different name. */
            if (sdslen(argv[2]) != 0) {
                sds copy = sdsdup(argv[2]);

                retval = dictAdd(server.commands, copy, cmd);
                if (retval != DICT_OK) {
                    sdsfree(copy);
                    err = "Target command name already exists"; goto loaderr;
                }
            }
        } else if (!strcasecmp(argv[0],"cluster-config-file") && argc == 2) {
            zfree(server.cluster_configfile);
            server.cluster_configfile = zstrdup(argv[1]);
        } else if (!strcasecmp(argv[0],"client-output-buffer-limit") &&
                   argc == 5)
        {
            int class = getClientTypeByName(argv[1]);
            unsigned long long hard, soft;
            int soft_seconds;

            if (class == -1 || class == CLIENT_TYPE_MASTER) {
                err = "Unrecognized client limit class: the user specified "
                "an invalid one, or 'master' which has no buffer limits.";
                goto loaderr;
            }
            hard = memtoll(argv[2],NULL);
            soft = memtoll(argv[3],NULL);
            soft_seconds = atoi(argv[4]);
            if (soft_seconds < 0) {
                err = "Negative number of seconds in soft limit is invalid";
                goto loaderr;
            }
            server.client_obuf_limits[class].hard_limit_bytes = hard;
            server.client_obuf_limits[class].soft_limit_bytes = soft;
            server.client_obuf_limits[class].soft_limit_seconds = soft_seconds;
        } else if (!strcasecmp(argv[0],"oom-score-adj-values") && argc == 1 + CONFIG_OOM_COUNT) {
            if (updateOOMScoreAdjValues(&argv[1], &err, 0) == C_ERR) goto loaderr;
        } else if (!strcasecmp(argv[0],"notify-keyspace-events") && argc == 2) {
            int flags = keyspaceEventsStringToFlags(argv[1]);

            if (flags == -1) {
                err = "Invalid event class character. Use 'g$lshzxeA'.";
                goto loaderr;
            }
            server.notify_keyspace_events = flags;
        } else if (!strcasecmp(argv[0],"user") && argc >= 2) {
            int argc_err;
            if (ACLAppendUserForLoading(argv,argc,&argc_err) == C_ERR) {
                char buf[1024];
                const char *errmsg = ACLSetUserStringError();
                snprintf(buf,sizeof(buf),"Error in user declaration '%s': %s",
                    argv[argc_err],errmsg);
                err = buf;
                goto loaderr;
            }
        } else if (!strcasecmp(argv[0],"loadmodule") && argc >= 2) {
            queueLoadModule(argv[1],&argv[2],argc-2);
        } else if (!strcasecmp(argv[0],"sentinel")) {
            /* argc == 1 is handled by main() as we need to enter the sentinel
             * mode ASAP. */
            if (argc != 1) {
                if (!server.sentinel_mode) {
                    err = "sentinel directive while not in sentinel mode";
                    goto loaderr;
                }
                queueSentinelConfig(argv+1,argc-1,linenum,lines[i]);
            }
        } else {
            err = "Bad directive or wrong number of arguments"; goto loaderr;
        }
        sdsfreesplitres(argv,argc);
    }

    /* Sanity checks. */
    if (server.cluster_enabled && server.masterhost) {
        linenum = slaveof_linenum;
        i = linenum-1;
        err = "replicaof directive not allowed in cluster mode";
        goto loaderr;
    }

    /* To ensure backward compatibility and work while hz is out of range */
    if (server.config_hz < CONFIG_MIN_HZ) server.config_hz = CONFIG_MIN_HZ;
    if (server.config_hz > CONFIG_MAX_HZ) server.config_hz = CONFIG_MAX_HZ;

    sdsfreesplitres(lines,totlines);
    return;

loaderr:
    fprintf(stderr, "\n*** FATAL CONFIG FILE ERROR (Redis %s) ***\n",
        REDIS_VERSION);
    fprintf(stderr, "Reading the configuration file, at line %d\n", linenum);
    fprintf(stderr, ">>> '%s'\n", lines[i]);
    fprintf(stderr, "%s\n", err);
    exit(1);
}
```


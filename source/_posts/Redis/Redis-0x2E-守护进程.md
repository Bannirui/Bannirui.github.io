---
title: Redis-0x2E-守护进程
category_bar: true
date: 2025-02-10 18:09:24
categories: Redis
---

### 1 开启后台进程

```c
/**
 * @brief 以后台进程方式运行服务
 */
void daemonize(void) {
    int fd;

    /**
     * 系统调用 fork当前进程
     *   - 系统调用成功了返回值为0
     *   - fork子进程失败了就返回到调用方父进程
     */
    if (fork() != 0) exit(0); /* parent exits */
    /**
     * 系统调用 以下拷贝自系统手册
     *
     * The setsid function creates a new session.  The calling process is the
     * session leader of the new session, is the process group leader of a
     * new process group and has no controlling terminal.  The calling
     * process is the only process in either the session or the process
     * group.
     *
     * Upon successful completion, the setsid function returns the value of
     * the process group ID of the new process group, which is the same as
     * the process ID of the calling process.
     */
    setsid(); /* create a new session */

    /* Every output goes to /dev/null. If Redis is daemonized but
     * the 'logfile' is set to 'stdout' in the configuration file
     * it will not log at all. */
    if ((fd = open("/dev/null", O_RDWR, 0)) != -1) {
        dup2(fd, STDIN_FILENO);
        dup2(fd, STDOUT_FILENO);
        dup2(fd, STDERR_FILENO);
        if (fd > STDERR_FILENO) close(fd);
    }
}
```

### 2 记录进程号

```c
/**
 * @brief 创建pid文件 写入进程号
 */
void createPidFile(void) {
    /* If pidfile requested, but no pidfile defined, use
     * default pidfile path */
    if (!server.pidfile) server.pidfile = zstrdup(CONFIG_DEFAULT_PID_FILE);

    /* Try to write the pid file in a best-effort way. */
    FILE *fp = fopen(server.pidfile,"w");
    if (fp) {
        fprintf(fp,"%d\n",(int)getpid()); // 记录进程号
        fclose(fp);
    }
}
```
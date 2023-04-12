---
title: Redis-0x17-守护进程
date: 2023-04-12 10:29:40
tags: [ Redis@6.2 ]
categories: [ Redis ]
---

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


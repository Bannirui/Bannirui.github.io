---
title: Redis-0x10-socket编程
category_bar: true
date: 2024-04-15 20:00:49
categories: Redis
---

socket相关的体系太庞杂了，这里就遇到一个记录一个。

1 getaddrinfo
---

2 fcntl
---

之前看过这个系统调用的文档{% post_link Redis/Redis-0x11-库函数fcntl %}

通过该系统调用读取和设置文件描述符的标志位

### 2.1 设置socket的非阻塞模式

```c
/**
 * 设置socket的阻塞模式
 * 设置成阻塞或者非阻塞的
 * @param fd socket的fd
 * @param non_block 想要把fd设置成什么阻塞模式
 *                  <ul>
 *                    <li>非0 想要socket是非阻塞的</li>
 *                    <li>0 想要socket是阻塞的</li>
 *                  </ul>
 */
int anetSetBlock(char *err, int fd, int non_block) {
    int flags;

    /* Set the socket blocking (if non_block is zero) or non-blocking.
     * Note that fcntl(2) for F_GETFL and F_SETFL can't be
     * interrupted by a signal. */
	/**
	 * 获取socket的fd状态标志
	 */
    if ((flags = fcntl(fd, F_GETFL)) == -1) {
        anetSetError(err, "fcntl(F_GETFL): %s", strerror(errno));
        return ANET_ERR;
    }

    /* Check if this flag has been set or unset, if so, 
     * then there is no need to call fcntl to set/unset it again. */
	/**
	 * 判定fd的阻塞状态 已经是想要的效果了就ASAP地退出
	 */
    if (!!(flags & O_NONBLOCK) == !!non_block)
        return ANET_OK;

	/**
	 * <ul>
	 *   <li>想要socket是非阻塞的 就把描述符状态标志低位第2位设置成1</li>
	 *   <li>想要socket是阻塞的 就把描述符状态标志低位第2位设置成0</li>
	 * </ul>
	 * 然后再把新的描述符状态标志设置给socket
	 */
    if (non_block)
        flags |= O_NONBLOCK;
    else
        flags &= ~O_NONBLOCK;

	// 设置新的描述符状态标志给socket
    if (fcntl(fd, F_SETFL, flags) == -1) {
        anetSetError(err, "fcntl(F_SETFL,O_NONBLOCK): %s", strerror(errno));
        return ANET_ERR;
    }
    return ANET_OK;
}
```

### 2.2 设置close-on-exec

```c
/**
 * 在fd上设置close-on-exec标志
 * 作用是一个文件描述符fd被标记为FD_CLOEXEC时 当进程通过exec系列函数(比如execve()和execvp())执行新程序时 该fd会被自动关闭
 * @return fcntl系统调用的返回值
 */
int anetCloexec(int fd) {
    int r;
    int flags;

    do {
	    // 读取socket的fd标志
        r = fcntl(fd, F_GETFD);
    } while (r == -1 && errno == EINTR);

	// 看看标志位上是不是已经有了FD_CLOEXEC标志
    if (r == -1 || (r & FD_CLOEXEC))
        return r;

	// 在标志上打上FD_CLOEXEC
    flags = r | FD_CLOEXEC;

    do {
	    // 将新的socket描述符标志设置给socket
        r = fcntl(fd, F_SETFD, flags);
    } while (r == -1 && errno == EINTR);

    return r;
}
```

3 setsockopt
---

设置socket

这个库函数5个形参

- sockfd 是指向套接字实例的文件描述符

- level 设置项是针对什么级别进行设置的

  - SOL_SOCKET 表示设置的是套接字级别

  - IPPROTO_TCP 标识设置的是TCP协议

- optname 设置项名称

  - SO_REUSEADDR 一般用来在服务端设置端口复用

  - SO_KEEPALIVE 设置keepalive

- optval 设置的值

- optval 指针指向变量的大小

### 3.1 设置SO_KEEPALIVE

```c
	// 开启socket的keepalive功能
    if (setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &val, sizeof(val)) == -1)
    {
        anetSetError(err, "setsockopt SO_KEEPALIVE: %s", strerror(errno));
        return ANET_ERR;
    }
```

### 3.2 TCP_KEEPIDLE

```c
	/**
	 * TCP_KEEPIDLE是用于设置TCP的keepalive开始发送探测报文之前的空闲时间的选项
	 * 一旦TCP的keepalive功能被启用 系统将会在连接空闲一段时间后开始发送探测报文以检测连接的存活性
	 * TCP_KEEPIDLE选项允许指定在开始发送探测报文之前允许的最大空闲时间
	 */
    if (setsockopt(fd, IPPROTO_TCP, TCP_KEEPIDLE, &val, sizeof(val)) < 0) {
        anetSetError(err, "setsockopt TCP_KEEPIDLE: %s\n", strerror(errno));
        return ANET_ERR;
    }
```

### 3.3 TCP_KEEPINTVL

```c
	/**
	 * TCP_KEEPINTVL是用于设置TCP的keepalive探测间隔的选项
	 * 一旦TCP的keepalive功能被启用 系统将会定期发送探测报文以检测连接的存活性
	 * TCP_KEEPINTVL选项允许指定探测报文之间的时间间隔
	 */
    if (setsockopt(fd, IPPROTO_TCP, TCP_KEEPINTVL, &val, sizeof(val)) < 0) {
        anetSetError(err, "setsockopt TCP_KEEPINTVL: %s\n", strerror(errno));
        return ANET_ERR;
    }
```

### 3.4 TCP_KEEPCNT

```c
	/**
	 * 用于设置TCP的keepalive探测尝试次数的选项
	 * 当TCP的keepalive功能被启用时 系统将会定期发送探测报文以检测连接的存活性
	 * TCP_KEEPCNT选项允许指定在关闭连接之前允许的最大探测失败次数
	 */
    if (setsockopt(fd, IPPROTO_TCP, TCP_KEEPCNT, &val, sizeof(val)) < 0) {
        anetSetError(err, "setsockopt TCP_KEEPCNT: %s\n", strerror(errno));
        return ANET_ERR;
    }
```

### 3.5 TCP_NODELAY

```c
/**
 * 设置是否开启Nagle算法
 * @param val 开启还是关闭延迟算法 1表示关闭延迟算法 0表示不关闭延迟算法
 */
static int anetSetTcpNoDelay(char *err, int fd, int val)
{
    /**
     * TCP_NODELAY是用于设置TCP的Nagle算法的选项
     * Nagle算法是一种优化TCP传输的算法 它通过在发送数据时进行缓冲 将多个小数据包合并成一个大数据包 从而减少网络上的数据包数量 提高传输效率
     * 在某些情况下 例如实时通信或者需要快速响应的应用中 这种缓冲可能会引入延迟，因此需要禁用Nagle算法
     */
    if (setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &val, sizeof(val)) == -1)
    {
        anetSetError(err, "setsockopt TCP_NODELAY: %s", strerror(errno));
        return ANET_ERR;
    }
    return ANET_OK;
}
```

### 3.6 SO_SNDTIMEO

```c
/**
 * 设置socket的发送超时时间
 * @param ms 超时时间设置多少毫秒
 */
int anetSendTimeout(char *err, int fd, long long ms) {
    struct timeval tv;

    tv.tv_sec = ms/1000;
    tv.tv_usec = (ms%1000)*1000;
	/**
	 * SO_SNDTIMEO是用于设置发送操作超时时间的选项
	 * 它允许设置在发送数据时等待的最大时间 如果在此时间内无法完成发送操作 则发送操作将被中断并返回错误
	 */
    if (setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv)) == -1) {
        anetSetError(err, "setsockopt SO_SNDTIMEO: %s", strerror(errno));
        return ANET_ERR;
    }
    return ANET_OK;
}
```

### 3.7 SO_RCVTIMEO

```c
/**
 * socket在接收数据时最大的等待时长
 * @param ms 等待时长 毫秒
 */
int anetRecvTimeout(char *err, int fd, long long ms) {
    struct timeval tv;

    tv.tv_sec = ms/1000;
    tv.tv_usec = (ms%1000)*1000;
	/**
	 * SO_RCVTIMEO选项用于设置接收操作的超时时间
	 * 它允许指定在接收数据时等待的最大时间 如果在此时间内未接收到数据 则接收操作将被中断并返回错误
	 */
    if (setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) == -1) {
        anetSetError(err, "setsockopt SO_RCVTIMEO: %s", strerror(errno));
        return ANET_ERR;
    }
    return ANET_OK;
}
```
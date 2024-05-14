---
title: Redis-0x10-socket编程
category_bar: true
date: 2024-04-15 20:00:49
categories: Redis
---

socket相关的体系太庞杂了，这里就遇到一个记录一个。

1 getaddrinfo
---

解析主机名或服务，并为套接字分配地址信息

这个库函数有4个参数

- hostname 主机名或ip地址

- servername 服务名或者端口号

- hints 解析提示

- serverinfo 该库函数的解析结果 是个数组

### 1.1 解析提示

解析提示的作用是提供一个模板给`getaddrinfo`

- 一方面预填充信息 将来库函数可以直接拷贝到返回值里面

- 再者 告知了库函数需要的套接字地址结构的某些限定 比如

  - 协议族是IPv4或者IPv6

  - 套接字类型是TCP套接字或者UDP套接字


解析提示的使用方式如下

```c
	// 提供解析提示
    memset(&hints,0,sizeof(hints));
	// 协议族 适用于IPv4和IPv6
    hints.ai_family = AF_UNSPEC;
	// 套接字类型 TCP套接字
    hints.ai_socktype = SOCK_STREAM;
```

### 1.2 参数举例

|hostname|servername|
|---|---|
|www.baidu.com|http|
|localhost|8080|

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

### 3.8 SO_REUSEADDR

```c
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes)) == -1) {
        anetSetError(err, "setsockopt SO_REUSEADDR: %s", strerror(errno));
        return ANET_ERR;
    }

```

4 inet_ntop
---

库函数原型为`const char *inet_ntop(int af, const void *src, char *dst, socklen_t size);`

作用是将套接字的二进制格式的地址解析成字符串格式

参数为

- af 要解析的套接字地址的协议族

  - AF_INET表示IPv4
  
  - AF_INET6表示IPv6.

- src 要解析的套接字地址

- dst 解析结果是字符串 存到什么地方

- size dst字符串的长度

```c
/**
 * 主机名解析成ip地址
 * 将二进制格式转换为字符串格式
 * @param err 上抛异常信息
 * @param host 要解析的主机名
 * @param ipbuf 解析出来的ip地址结果是字符串格式 放到这个char数组里面
 * @param ipbuf_len char数组的长度
 * @param flags
 * @return <ul>状态码
 *           <li>-1 失败</li>
 *           <li>0 成功</li>
 *         </ul>
 */
int anetResolve(char *err, char *host, char *ipbuf, size_t ipbuf_len,
                       int flags)
{
    struct addrinfo hints, *info;
    int rv;

	// 提供解析提示
    memset(&hints,0,sizeof(hints));
    if (flags & ANET_IP_ONLY) hints.ai_flags = AI_NUMERICHOST;
	// 协议族 适用于IPv4或者IPv6
    hints.ai_family = AF_UNSPEC;
	// 套接字类型是TCP套接字
    hints.ai_socktype = SOCK_STREAM;  /* specify socktype to avoid dups */

    if ((rv = getaddrinfo(host, NULL, &hints, &info)) != 0) {
        anetSetError(err, "%s", gai_strerror(rv));
        return ANET_ERR;
    }
    if (info->ai_family == AF_INET) {
	    // 解析结果的协议族是IPv4
        struct sockaddr_in *sa = (struct sockaddr_in *)info->ai_addr;
		// IPv4类型的ip地址放到ipbuf上
        inet_ntop(AF_INET, &(sa->sin_addr), ipbuf, ipbuf_len);
    } else {
	    // 解析结果的协议族是IPv6
        struct sockaddr_in6 *sa = (struct sockaddr_in6 *)info->ai_addr;
		// IPv6类型的ip地址放到ipbuf上
        inet_ntop(AF_INET6, &(sa->sin6_addr), ipbuf, ipbuf_len);
    }

    freeaddrinfo(info);
    return ANET_OK;
}
```

5 socket
---

创建socket套接字实例

- domain 指定通信的地址族 无非就是网络通信或者本地通信

  - 网络通信
  
    - AF_INET 表示IPv4地址族

	- AF_INET6 表示IPv6地址族

  - 本地通信 AF_LOCAL 表示本地(Unix域)套接字 用于在同一台计算机上不同进程间进行本地通信 而不通过网络 因为不需要经过网络协议栈 因此开销小 速度快

- type 指定套接字类型 对应的是运输层的协议类型

  - SOCK_STREAM表示面向连接的流套接字

  - SOCK_DGRAM表示无连接的数据报套接字

- protocol 使用的协议 通常使用默认的协议 即0

```c
/**
 * 创建TCP套接字
 * 并且将其设置socket端口重用
 * @param domain 指定socket的协议族 <ul>
 *                                  <li>AF_INET 表示IPv4地址族</li>
 *                                  <li>AF_INET6 表示IPv6地址族</li>
 *                                  <li>AF_LOCAL 表示本地(Unix域)套接字 用于在同一台计算机上不同进程间进行本地通信 而不通过网络 因为不需要经过网络协议栈 因此开销小 速度快</li>
 *                                </ul>
 * @return <ul>
 *           <li>-1 标识错误码</li>
 *           <li>非-1 表示socket的fd</li>
 *         </ul>
 */
static int anetCreateSocket(char *err, int domain) {
    int s;
	/**
	 * 系统调用创建socket实例
	 * <ul>
	 *   <li>domain 指定通信的地址族<ul>
	 *     <li>AF_INET 表示IPv4地址族</li>
	 *     <li>AF_INET6 表示IPv6地址族</li>
	 *     <li>AF_LOCAL 表示本地(Unix域)套接字 用于在同一台计算机上不同进程间进行本地通信 而不通过网络 因为不需要经过网络协议栈 因此开销小 速度快</li>
	 *   </ul></li>
	 *   <li>type 指定套接字类型<ul>
	 *     <li>SOCK_STREAM表示面向连接的流套接字</li>
	 *     <li>SOCK_DGRAM表示无连接的数据报套接字</li>
	 *   </ul></li>
	 *   <li>protocol 使用的协议 通常使用默认的协议 即0</li>
	 * </ul>
	 */
    if ((s = socket(domain, SOCK_STREAM, 0)) == -1) {
        anetSetError(err, "creating socket: %s", strerror(errno));
        return ANET_ERR;
    }

    /* Make sure connection-intensive things like the redis benchmark
     * will be able to close/open sockets a zillion of times */
	// 这是reids的服务端 将socket设置为端口重用
    if (anetSetReuseAddr(err,s) == ANET_ERR) {
        close(s);
        return ANET_ERR;
    }
    return s;
}
```

6 connect
---

连接到服务器的套接字

- sockfd 客户端socket 去连向服务器的套接字

- addr 指向`sockaddr`结构体的指针 包含着服务器地址和端口信息

- addrlen `addr`结构体的大小

```c
	/**
	 * 让s这个套接字连接到服务器的套接字
	 * <ul>
	 *   <li>s 客户端的套接字</li>
	 *   <li>sa sockaddr结构体的指针 包含着服务端地址和端口信息</li>
	 *   <li>sa大小</li>
	 * </ul>
	 */
    if (connect(s,(struct sockaddr*)&sa,sizeof(sa)) == -1) {
        if (errno == EINPROGRESS &&
            flags & ANET_CONNECT_NONBLOCK)
            return s;

        anetSetError(err, "connect: %s", strerror(errno));
        close(s);
        return ANET_ERR;
    }
```

7 bind
---

将套接字绑定到一个特定的地址和端口上，这一步对服务端程序尤为重要

服务器需要在一个固定的地址和端口上监听客户端的连接请求

- sockfd 由socket函数返回的套接字文件描述符

- addr 指向sockaddr结构的指针 包含要绑定的地址和端口信息

- addrlen addr结构的大小

```c
    if (bind(s,sa,len) == -1) {
        anetSetError(err, "bind: %s", strerror(errno));
        close(s);
        return ANET_ERR;
    }
```

8 listen
---

将套接字设置为被动模式，以便接收来自客户端的请求

- sockfd 由`socket`函数返回的套接字文件描述符

- backlog 指定挂起连接队列的最大长度 未处理的连接请求将保存在这个队列中 直到用`accept`系统调用进行处理

```c
    if (listen(s, backlog) == -1) {
        anetSetError(err, "listen: %s", strerror(errno));
        close(s);
        return ANET_ERR;
    }
```

9 accept
---

接受连接请求，并在网络服务器编程中扮演关键角色
它从监听套接字队列中获取一个待处理的连接，并返回一个新的套接字文件描述符，用于与客户端进行通信

- 参数

  - sockfd 监听套接字文件描述符，它是通过`socket`和`bind`以及`listen`配置好的

  - addr 指向`sockaddr`结构体的指针，用于存储客户端的地址信息。可以为 NULL，这时不获取客户端地址信息


- 返回值

- 成功时，返回新的套接字文件描述符，用于与客户端进行通信

- 失败时，返回-1，并设置`errno`以指示错误

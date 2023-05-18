---
title: Netty-0x07-我眼中的网络编程
date: 2023-05-18 21:34:15
tags:
- 2刷Netty
- 网络
- Java@15
categories: [ Netty ]
---

主要想学到什么

* 自底向上回溯网络编程的发展
* 温习涉及到的名词

### 1 TCP\IP协议栈

![](Netty-0x07-我眼中的网络编程/image-20230518214107228.png)

作为一名普通的业务开发，我怎么使用OS在2个应用之间通信

* OS直接将TCP\IP的实现暴露给用户
* 自此基础上进行封装再暴露给用户

### 2 socket

socket是在逻辑上对TCP\IP协议栈的抽象封装，在物理上是OS暴露用户层的接口

系统调用

* socket 负责创建socket实例 
* connect 负责向server socket发起连接请求
* bind 显式将socket跟ip:port绑定
* listen 将主动socket转换为被动socket，只负责接收连接请求
* aceept 负责建立连接请求
* read 读数据
* write 写数据

伪代码
```c
#include <sys/socket>

void server()
{
    // 进程的fd
    int sfd = socket(PF_INET, SOCK_STREAM, TCP);
    // 显式绑定某个端口
    if(-1 == bind(sfd, 数据结构{ip:port}, 数据结构长度))
    {
        // errno
        return;
    }
    // 将socket转换为一个被动socket 监听在端口上
    if(-1 == listen(sfd, 3))
    {
        // errno
        return;
    }
    // 获取链接请求
    while(1)
    {
        int socket=-1; // err
        if((socket=accept(sfd, ...))==-1)
        {
            // errno
            return;
        }
        // 读写
        size_t len = read(socket, byte[], 1024);
    }
}

int main()
{
    
    
    return 0;
}
```

我们一直说socket，socket是什么东西呢

5元组，{协议，源ip，源port，目的ip，目的port}

socket是负责端到端，两个进程间的通信，因此它一定是成对的

![](Netty-0x07-我眼中的网络编程/image-20230518222908047.png)

### 3 Java是运行在JVM里面的

怎么调用socket相关方法呢

Java针对OS的fd进行封装

* 首先就要封装fd，对应的类是FileDescriptor
* 其次封装Socket，真正对应OS的socket其实是SocksSocketImpl
* 为了区分C\S端，再次基础上封装出来了Socket和ServerSocket
* Socket还需要负责读写，因此组合了InputStream和OutputStream
* 系统调用的read和write是通过工具类实现在JNI里面

```java
    /**
     * 它相当于直接映射着OS层的Socket
     * 实现是NioSocketImpl
     */
    SocketImpl impl;

    /**
     * 开放给客户端使用的数据读写
     * 但是本身它们对接的是实现在NioSocketImpl中的SocketInputStream
     */
    private volatile InputStream in;
    private volatile OutputStream out;
```



```java
    public InputStream getInputStream() throws IOException {
        if (isClosed())
            throw new SocketException("Socket is closed");
        if (!isConnected())
            throw new SocketException("Socket is not connected");
        if (isInputShutdown())
            throw new SocketException("Socket input is shutdown");
        InputStream in = this.in;
        if (in == null) {
            // wrap the input stream so that the close method closes this socket
            /**
             * 核心在impl.getInPutStream()方法
             * 将来客户端通过从Socket实例获取的InputStram进行read的时候
             * 本质是通过impl.getInputStream()的返回值进行的read
             */
            in = new SocketInputStream(this, impl.getInputStream());
            if (!IN.compareAndSet(this, null, in)) { // 把in局部变量赋值给Socket的成员变量in 那么下一次执行getInputStream的时候就不会进入if分支
                in = this.in;
            }
        }
        return in;
    }
```



```java
    @Override
    protected InputStream getInputStream() {
        return new InputStream() {
            @Override
            public int read() throws IOException {
                byte[] a = new byte[1];
                int n = read(a, 0, 1);
                return (n > 0) ? (a[0] & 0xff) : -1;
            }
            @Override
            public int read(byte[] b, int off, int len) throws IOException {
                return NioSocketImpl.this.read(b, off, len);
            }
            @Override
            public int available() throws IOException {
                return NioSocketImpl.this.available();
            }
            @Override
            public void close() throws IOException {
                NioSocketImpl.this.close();
            }
        };
    }
```

怎么封装

* 把OS里面关键的标识fd封装成一个Java类
* OS中读写是纯粹的动作，操作对象是fd，读写本身不隶属于任何的struct
* 而Java中我们封装出来的Socket类是要具有读写功能的，因此中间需要使用工具类的方式，将类的方法转交给JNI实现，将面向对象转换成面向过程

![](Netty-0x07-我眼中的网络编程/image-20230518234650181.png)

伪代码

是可以看出来，即使跟C语言的开发可以说是一摸一样，区别仅仅在于

* C语言用的是库函数
* Java用的是JDK的封装类

```java
    private static void server() throws IOException {
        ServerSocket ss = new ServerSocket();
        ss.bind(new InetSocketAddress("127.0.0.1", 9527), 50);
        Socket socket = ss.accept();
        while (true) {
            // ignore
        }
    }

    private static void client() throws IOException {
        Socket socket = new Socket();
        socket.connect(new InetSocketAddress("127.0.0.1", 9527));
        socket.getInputStream().read();
        socket.getOutputStream().write(12);
    }
```

### 4 目前存在的问题

问题点

* accept是阻塞的系统调用
* read是阻塞的系统调用
* write是阻塞的系统调用

### 5 OS的非阻塞支撑

* 通过fcntl(fd control)系统调用指定Socket属性，支持异步编程
* 多路复用

![](Netty-0x07-我眼中的网络编程/image-20230518235609869.png)

### 6 Java怎么去支持这个非阻塞方式的

基本有两个思路

* 继续升级已有的Socket类
  * 代价小，向下直接兼容版本
  * 相当于构造方法提供一个形参，控制使用阻塞\非阻塞式的模式，直接对标OS的系统调用fcntl
  * 针对多路复用器，封装对应的Java中的多路复用器实现
  * 还是通过getInputStream\getOutputStream，对接的数据依然是byte数组，反序列化这件事情还得多一层结构
* 重新封装个类专门支持非阻塞式的Socket叫NioSocket
  * 冗余代码过多，以后回头看就会发现整个系统设计比较傻逼

在此基础之上，Java专门提供了非阻塞的支持

* Buffer
* Channel
* Selector

相当于没有了Socket，它去哪儿了

可以这样粗略理解，Channel就是Socket，它是对Socket更高层次的抽象和封装

![](Netty-0x07-我眼中的网络编程/image-20230519001214882.png)

### 7 为什么要有Netty

```java
public class SelectorTest {

    private static final int BUF_SIZE = 256;
    private static final int TIMEOUT = 3_000;

    public static void main(String[] args) throws Exception {
        // 打开服务端Socket
        ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
        // 打开Selector
        Selector selector = Selector.open();
        // 服务端Socket监听端口 配置非阻塞模式
        serverSocketChannel.socket().bind(new InetSocketAddress(8080));
        serverSocketChannel.configureBlocking(false);
        /**
         * 将channel注册到selector中
         * 通常都是先注册一个OP_ACCEPT事件 然后在OP_ACCEPT到来时 再将这个channel的OP_READ注册到selector中
         */
        serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);
        while (true) {
            // 阻塞等待channel IO可操作
            if (selector.select(TIMEOUT) == 0) {
                System.out.println(".");
                continue;
            }
            // 获取IO操作就绪的SelectionKey 通过SelectionKey可以知道哪些Channel的哪些IO操作已经就绪
            Iterator<SelectionKey> keyIterator = selector.selectedKeys().iterator();
            while (keyIterator.hasNext()) {
                SelectionKey key = keyIterator.next();
                // 当获取到一个SelectionKey后 就要将它删除 表示已经对这个IO事件进行了处理
                keyIterator.remove();
                if (key.isAcceptable()) {
                    /**
                     * 当OP_ACCEPT事件到来时 就从ServerSocketChannel中获取一个SocketChannel代表客户端的连接
                     * 注意:
                     *   - 在OP_ACCEPT事件中 key.channel()返回的Channel是ServerSocketChannel
                     *   - 在OP_READ和OP_WRITE事件中 从key.channel()返回Channel是SocketChannel
                     */
                    SocketChannel clientChannel = ((ServerSocketChannel) key.channel()).accept();
                    clientChannel.configureBlocking(false);
                    clientChannel.register(key.selector(), SelectionKey.OP_READ,
                            ByteBuffer.allocate(BUF_SIZE));
                }
                if (key.isReadable()) {
                    SocketChannel clientChannel = ((SocketChannel) key.channel());
                    ByteBuffer buf = ((ByteBuffer) key.attachment());
                    int bytesRead = clientChannel.read(buf);
                    if (bytesRead == -1) {
                        clientChannel.close();
                    } else if (bytesRead > 0) {
                        key.interestOps(SelectionKey.OP_READ | SelectionKey.OP_WRITE);
                        System.out.println("Get data length: " + bytesRead);
                    }
                }
                if (key.isValid() && key.isWritable()) {
                    ByteBuffer buf = ((ByteBuffer) key.attachment());
                    buf.flip();
                    SocketChannel clientChannel = (SocketChannel) key.channel();
                    clientChannel.write(buf);
                    if (!buf.hasRemaining()) {
                        key.interestOps(SelectionKey.OP_READ);
                    }
                    buf.compact();
                }
            }
        }
    }
}
```

现在已经有OS对非阻塞的支持，并且Java也开发了对应的封装，我们的业务开发可以直接使用三剑客，但是也会有很多问题

* 重复性太强，每次写的很多代码都是业务无关，偏系统性的
* Java对Selector的封装有BUG，个人直接使用三剑客还要去关注怎么兜底
* 细节性的优化，每个人都不尽相同
* Java喜欢造框架

凡此种种，Netty出现了

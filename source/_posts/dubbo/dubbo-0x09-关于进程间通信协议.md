---
title: dubbo-0x09-关于进程间通信协议
category_bar: true
date: 2025-05-29 10:25:35
categories: dubbo
---

![](./dubbo-0x09-关于进程间通信协议/1748485666.png)

就我自己的理解，服务提供方和服务消费方的通信，不管是不是在同一台机器，本质都是两进程通信

进程通信的常用方法无非就是
- 共享内存
- 网络通信
  - 本地unix局域网
  - 远程网络

作为一个rpc框架，如果我认为http协议足够我应该就选用http就好了吧，我认为http协议太重，那么我就在tcp传输层基础上包装个专门的协议。

看到Protocol的基类我就感觉头晕目眩了，当然了就看默认基于netty的dubbo实现就行了

### 1 Protocol的动态

```java
    private static final Protocol protocol = ExtensionLoader.getExtensionLoader(Protocol.class).getAdaptiveExtension();

    /**
    * 这个地方的protocol是谁的实例
    * {@link Protocol}接口方法用了{@link com.alibaba.dubbo.common.extension.Adaptive}却没有指定别名
    * 那么就先用{@link Protocol}接口名protocol作为别名也找不到对应的实现
    * 最后用接口类上{@link com.alibaba.dubbo.common.extension.SPI}注解指定的dubbo作为别名找到{@link DubboProtocol}这个实现
    */
    Exporter<?> exporter = protocol.export(wrapperInvoker);
```

在dubbo中看到这种就要找对就的运行时实现是什么{% post_link dubbo/dubbo-0x05-SPI机制 %}

Protocol接口类
- export方法用了@Adaptive注解，没指定url中key
- 类用了@SPI("dubbo")注解

所以运行时候就会
- 去wrapperInvoker中`getUrl`
- protocol特殊处理通过`url.getProtocol()`方法拿到的结果作别名
- 用dubbo作为实现的别名用ExtensionLoader去找到对应的类反射出来实现

### 2 DubboProtocol

![](./dubbo-0x09-关于进程间通信协议/1748487041.png)

这个就是配置给SPI去发现加载的


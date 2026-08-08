---
title: Netty-08-channel的factory
category_bar: true
categories: Netty
date: 2026-08-08 22:55:24
---

## 1 factory的本质

就是把channel的构造函数包起来

```java
// ReflectiveChannelFactory.java
public ReflectiveChannelFactory(Class<? extends T> clazz) {
    try {
        this.constructor = clazz.getConstructor(); // NioServerSocket的class对象
    } catch (NoSuchMethodException e) {
        throw new IllegalArgumentException("Class " + StringUtil.simpleClassName(clazz) + " does not have a public non-arg constructor", e);
    }
}
```

然后把这个factory保存起来 需要channel的实例的时候就用这个factory构造一个出来

```java
    public B channelFactory(ChannelFactory<? extends C> channelFactory) { // channelFactory的setter
        if (this.channelFactory != null) throw new IllegalStateException("channelFactory set already");
        /**
         * {@link io.netty.channel.ChannelFactory}本质就是一个Channel工厂->阈维护了一个无参构造器->通过newInstance()创建Channel实例
         *
         * 两个无参构造器:
         * {@link NioServerSocketChannel#NioServerSocketChannel()}->创建服务端Channel实例
         * {@link NioSocketChannel#NioSocketChannel()}->创建客户端Channel实例
         */
        this.channelFactory = channelFactory; // 设置channelFactory属性 将ReflectiveChannelFactory实例赋值给该属性
        return self();
    }
```


## 2 构造实例

```java
    @Override
    public T newChannel() {
        try {
            /**
             * 把channel的构造方法包成factory交给别人 当它需要channel实例的时候就用factory的这个方法构造一个channel出来
             * 反射调用Channel的无参构造方法创建Channel
             * NioSocketChannel用来读写 它的创建时机在connect的时候
             * NioServerSocketChannel用来连接 它的创建时机在bind的时候
             */
            return this.constructor.newInstance();
        } catch (Throwable t) {
            throw new ChannelException("Unable to create Channel from class " + constructor.getDeclaringClass(), t);
        }
    }
```
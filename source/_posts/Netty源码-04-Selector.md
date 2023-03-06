---
title: Netty源码-04-Selector
date: 2023-03-06 21:30:38
tags:
- Netty@4.1.169
categories:
- Netty源码
---

Netty对Selector的优化体现在两个方面：

* 数据结构替换，数组替换hash表，轮询时直接寻址，提高查询效率。
* 基于Linux系统epoll封装的Selector可能存存在空轮询风险，尽量减少空轮询出现带来的负面影响。

## 一 数据结构

每个IO线程都绑定了唯一的复用器，因此Selector的初始化时机是在创建NioEventLoop时。

```java
// NioEventLoop.java
NioEventLoop(NioEventLoopGroup parent, // 标识EventLoop归属于哪个group
             Executor executor, // 线程执行器 将线程和EventLoop绑定
             SelectorProvider selectorProvider, // Java中IO多路复用器提供器
             SelectStrategy strategy, // 正常任务队列选择策略
             RejectedExecutionHandler rejectedExecutionHandler, // 正常任务队列拒绝策略
             EventLoopTaskQueueFactory taskQueueFactory, // 正常任务
             EventLoopTaskQueueFactory tailTaskQueueFactory // 收尾任务
            ) {
    super(parent,
          executor,
          false,
          newTaskQueue(taskQueueFactory), // 正常任务队列
          newTaskQueue(tailTaskQueueFactory), // 收尾任务队列
          rejectedExecutionHandler
         ); // 调用父类构造方法
    this.provider = ObjectUtil.checkNotNull(selectorProvider, "selectorProvider"); // IO多路复用器提供器 用于创建多路复用器实现
    this.selectStrategy = ObjectUtil.checkNotNull(strategy, "selectStrategy"); // 这个select是针对taskQueue任务队列中任务的选择策略
    final SelectorTuple selectorTuple = this.openSelector(); // 开启NIO中的组件 selector 意味着NioEventLoopGroup这个线程池中每个线程NioEventLoop都有自己的selector
    /**
         * 创建NioEventLoop绑定的selector对象
         * 初始化了IO多路复用器
         */
    this.selector = selectorTuple.selector; // Netty优化过的IO多路复用器
    this.unwrappedSelector = selectorTuple.unwrappedSelector; // Java原生的多路复用器
}
```



```java
// NioEventLoop.java
private static final class SelectorTuple {
    final Selector unwrappedSelector; // Java原生的IO多路复用器
    final Selector selector; // Netty优化了Java原生的IO多路复用器

    SelectorTuple(Selector unwrappedSelector) {
        this.unwrappedSelector = unwrappedSelector;
        this.selector = unwrappedSelector;
    }

    SelectorTuple(Selector unwrappedSelector, Selector selector) {
        this.unwrappedSelector = unwrappedSelector;
        this.selector = selector;
    }
}
```

声明了一个数据结构用于存放Selector，对于Netty框架而言，不在主观上强制使用优化策略，因此需要留存最终的实现方案selector，优化版的实现需要依赖Jdk原生的实现，相当于unwrappedSelector时临时存储而已。

因此只要关注selector的实现就行：

```java
// NioEventLoop.java
final SelectorTuple selectorTuple = this.openSelector(); // 开启NIO中的组件 selector 意味着NioEventLoopGroup这个线程池中每个线程NioEventLoop都有自己的selector
```



```java
// NioEventLoop.java
private SelectorTuple openSelector() {
    final Selector unwrappedSelector; // 从命名就可以看出来Netty对Java的多路复用器做了封装
    try {
        /**
             * jdk底层的api
             * 创建了Java的IO多路复用器selector
             */
        unwrappedSelector = this.provider.openSelector();
    } catch (IOException e) {
        throw new ChannelException("failed to open a new selector", e);
    }

    /**
         * 判断是否需要关闭优化
         * 默认false 也就说默认需要进行优化
         * netty要对jdk原生的selector进行优化 selector在select()操作的时候 会通过selector.selectedKeys()操作返回一个Set<SelectionKey> 这个是Set类型 netty对这个set进行了处理 使用SelectedSelectionKeySet这个数据结构进行了替换 当在select()操作时将key存入一个SelectedSelectionKeySet数据结构中
         */
    if (DISABLE_KEY_SET_OPTIMIZATION) return new SelectorTuple(unwrappedSelector); // 不需要优化 直接使用Java原生的复用器实现

    Object maybeSelectorImplClass = AccessController.doPrivileged(new PrivilegedAction<Object>() {
        @Override
        public Object run() {
            try {
                /**
                     * 反射获取sun.nio.ch.SelectorImpl这个类的class对象
                     */
                return Class.forName("sun.nio.ch.SelectorImpl", false, PlatformDependent.getSystemClassLoader());
            } catch (Throwable cause) {
                return cause;
            }
        }
    });

    /**
         * 判断拿到的class对象是不是Selector的实现类
         */
    if (!(maybeSelectorImplClass instanceof Class) || !((Class<?>) maybeSelectorImplClass).isAssignableFrom(unwrappedSelector.getClass()))
        return new SelectorTuple(unwrappedSelector);

    // 这个class对象是Selector的实现
    final Class<?> selectorImplClass = (Class<?>) maybeSelectorImplClass;
    /**
         * 自定义数据结构替代jdk原生的SelectionKeySet
         */
    final SelectedSelectionKeySet selectedKeySet = new SelectedSelectionKeySet();

    Object maybeException = AccessController.doPrivileged(new PrivilegedAction<Object>() {
        @Override
        public Object run() {
            try {
                /**
                     * 通过反射拿到
                     * selectedKeys属性
                     * publicSelectedKeys属性
                     * 这两个属性都是HashSet的实现方式
                     */
                Field selectedKeysField = selectorImplClass.getDeclaredField("selectedKeys");
                Field publicSelectedKeysField = selectorImplClass.getDeclaredField("publicSelectedKeys");

                if (PlatformDependent.javaVersion() >= 9 && PlatformDependent.hasUnsafe()) {
                    // Let us try to use sun.misc.Unsafe to replace the SelectionKeySet.
                    // This allows us to also do this in Java9+ without any extra flags.
                    long selectedKeysFieldOffset = PlatformDependent.objectFieldOffset(selectedKeysField);
                    long publicSelectedKeysFieldOffset = PlatformDependent.objectFieldOffset(publicSelectedKeysField);

                    if (selectedKeysFieldOffset != -1 && publicSelectedKeysFieldOffset != -1) {
                        PlatformDependent.putObject(unwrappedSelector, selectedKeysFieldOffset, selectedKeySet);
                        PlatformDependent.putObject(unwrappedSelector, publicSelectedKeysFieldOffset, selectedKeySet);
                        return null;
                    }
                    // We could not retrieve the offset, lets try reflection as last-resort.
                }

                /**
                     * 将拿到的两个属性设置成可修改的
                     */
                Throwable cause = ReflectionUtil.trySetAccessible(selectedKeysField, true);
                if (cause != null) return cause;
                cause = ReflectionUtil.trySetAccessible(publicSelectedKeysField, true);
                if (cause != null) return cause;

                /**
                     * 将selector的两个属性都换成netty的selectedKeySet实现的数据结构
                     */
                selectedKeysField.set(unwrappedSelector, selectedKeySet);
                publicSelectedKeysField.set(unwrappedSelector, selectedKeySet);
                return null;
            } catch (NoSuchFieldException e) {
                return e;
            } catch (IllegalAccessException e) {
                return e;
            }
        }
    });

    if (maybeException instanceof Exception) {
        this.selectedKeys = null;
        Exception e = (Exception) maybeException;
        return new SelectorTuple(unwrappedSelector);
    }
    /**
         * 将优化后的keySet保存成NioEventLoop的成员变量
         */
    this.selectedKeys = selectedKeySet;
    return new SelectorTuple(unwrappedSelector, new SelectedSelectionKeySetSelector(unwrappedSelector, selectedKeySet));
}
```

实现也很简单，就是将Jdk原生的实现Selector中的两个阈selectedKeys和publicSelectedKeys这两个hash表实现换成数组实现。

## 二 空轮询

```java
// NioEventLoop.java
else if (this.unexpectedSelectorWakeup(selectCnt)) selectCnt = 0; // 任务判定可能发生了空轮询 如果发生了空轮询场景 就通过重建复用器方式尽量避免再次发生空轮询
```

在NioEventLoop线程启动之后，线程轮询于IO任务和非IO任务之间，阻塞点是IO多路复用器的select操作。

但是Jdk对于EPoll多路复用的封装有缺陷，可能发生本该阻塞等待的线程被唤醒，publicSelectedKeys中并没有IO事件，也就是发生了一次空select操作，一旦整个线程轮询模型处于空轮询中，一直占用CPU导致资源浪费。

Netty并没有重新封装EPoll的实现，还是使用的Jdk方案，只是加了一层预警式防御。也就是说空转仍然可能会出现，但是不让空转线程一直占用CPU，当空转次数达到一定阈值时，Netty将其判定为发生了空转，需要防御处理，手段就是重新构建Selector。

```java
// NioEventLoop.java
private boolean unexpectedSelectorWakeup(int selectCnt) {
    if (Thread.interrupted()) {
        // Thread was interrupted so reset selected keys and break so we not run into a busy loop.
        // As this is most likely a bug in the handler of the user or it's client library we will
        // also log it.
        //
        // See https://github.com/netty/netty/issues/2426
        return true;
    }
    if (SELECTOR_AUTO_REBUILD_THRESHOLD > 0 &&
        selectCnt >= SELECTOR_AUTO_REBUILD_THRESHOLD) { // 判定发生空轮询
        // The selector returned prematurely many times in a row.
        // Rebuild the selector to work around the problem.
        this.rebuildSelector();
        return true;
    }
    return false;
}
```

重建Selector也是由NioEventLoop线程完成：

```java
// NioEventLoop.java
public void rebuildSelector() {
    // NioEventLoop线程操作 线程切换
    if (!inEventLoop()) {
        execute(new Runnable() {
            @Override
            public void run() {
                rebuildSelector0();
            }
        });
        return;
    }
    this.rebuildSelector0();
}
```



```java
// NioEventLoop.java
/**
     * netty解决epoll bug的步骤就是创建一个新的selector 将旧selector中注册的channel和事件重新注册到新的selector中 然后将自身selector属性替换成新创建的selector
     */
private void rebuildSelector0() {
    final Selector oldSelector = selector;
    final SelectorTuple newSelectorTuple;

    if (oldSelector == null) return;

    try {
        /**
             * 重新创建一个select
             */
        newSelectorTuple = this.openSelector();
    } catch (Exception e) {
        logger.warn("Failed to create a new Selector.", e);
        return;
    }

    // Register all channels to the new Selector.
    int nChannels = 0;
    for (SelectionKey key: oldSelector.keys()) { // 注册的事件(EPoll的epoll_ctl系统调用 KQueue的EV_SET宏调用) 让复用器关注Socket的什么事件
        Object a = key.attachment(); // 通过attachment关联映射这Netty的Channel和Jdk的Channel关系
        try {
            if (!key.isValid() || key.channel().keyFor(newSelectorTuple.unwrappedSelector) != null)
                continue;
            int interestOps = key.interestOps(); // 当初注册到复用器上时 要关注Channel的什么事件
            key.cancel();
            /**
                 * 注册到重新创建的selector中
                 */
            SelectionKey newKey = key.channel().register(newSelectorTuple.unwrappedSelector, interestOps, a); // 将Channel重新注册到Selector上
            /**
                 * 如果channel是NioChannel 就重新赋值
                 */
            if (a instanceof AbstractNioChannel) ((AbstractNioChannel) a).selectionKey = newKey;
            nChannels ++;
        } catch (Exception e) {
            if (a instanceof AbstractNioChannel) {
                AbstractNioChannel ch = (AbstractNioChannel) a;
                ch.unsafe().close(ch.unsafe().voidPromise());
            } else {
                @SuppressWarnings("unchecked")
                NioTask<SelectableChannel> task = (NioTask<SelectableChannel>) a;
                invokeChannelUnregistered(task, key, e);
            }
        }
    }

    this.selector = newSelectorTuple.selector;
    this.unwrappedSelector = newSelectorTuple.unwrappedSelector;

    try {
        // time to close the old selector as everything else is registered to the new one
        oldSelector.close();
    } catch (Throwable t) {
        if (logger.isWarnEnabled()) {
            logger.warn("Failed to close the old Selector.", t);
        }
    }

    if (logger.isInfoEnabled()) {
        logger.info("Migrated " + nChannels + " channel(s) to the new Selector.");
    }
}
```


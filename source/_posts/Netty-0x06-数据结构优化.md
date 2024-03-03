---
title: Netty-0x06-数据结构优化
date: 2023-05-16 22:34:10
category_bar: true
tags: [ 2刷Netty ]
categories: [ Netty ]
---

### 1 Selector

final SelectorTuple selectorTuple = this.openSelector();

### 2 MPSC

```java
    private static Queue<Runnable> newTaskQueue(
            EventLoopTaskQueueFactory queueFactory) {
        if (queueFactory == null) {
            /**
             * 依赖jctools的MPSC队列实现
             *   - 多生产者
             *   - 单消费者
             */
            return newTaskQueue0(DEFAULT_MAX_PENDING_TASKS);
        }
        return queueFactory.newTaskQueue(DEFAULT_MAX_PENDING_TASKS);
    }
```

### 3 ThreadLocal

```java
private static final FastThreadLocal<EventExecutor> mappings = new FastThreadLocal<EventExecutor>();
```


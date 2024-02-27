---
title: Netty源码-02-FastThreadLocalThread
date: 2023-03-06 21:03:29
categories:
- Netty
tags:
- 1刷Netty
---

对Java Thread做的优化。

## 一 Demo

```java
public class FastThreadLocalTest00 {

    private final static FastThreadLocal<Long> v = new FastThreadLocal<Long>() {
        @Override
        protected Long initialValue() throws Exception {
            System.out.println("init");
            return 0L;
        }
    };

    public static void main(String[] args) throws InterruptedException {
        new FastThreadLocalThread(() -> {
            System.out.println("fast1 v1=" + v.get());
            v.set(1L);
            System.out.println("fast1 v2=" + v.get());
            v.remove();
            System.out.println("fast1 v3=" + v.get());
        }).start();

        new FastThreadLocalThread(() -> {
            System.out.println("fast2 v1=" + v.get());
            v.set(2L);
            System.out.println("fast2 v2=" + v.get());
            v.remove();
            System.out.println("fast2 v3=" + v.get());
        }).start();

        Thread.sleep(3_000);
    }
}
```

## 二 FastThreadLocal

```java
// FastThreadLocal.java

private final int index; // 指向InternalThreadLocalMap中数组下一个可用脚标

public FastThreadLocal() {
        this.index = InternalThreadLocalMap.nextVariableIndex(); // index初始化时为默认值0 把0处的slot预留出来 从1开始可用 此时InternalThreadLocalMap里面的数组并没有实例化
    }
```



```java
// InternalThreadLocalMap.java
public static int nextVariableIndex() {
        int index = nextIndex.getAndIncrement();
        if (index < 0) {
            nextIndex.decrementAndGet();
            throw new IllegalStateException("too many thread-local indexed variables");
        }
        return index;
    }
```

## 三 get方法

```java
// FastThreadLocal.java
public final V get() {
        InternalThreadLocalMap threadLocalMap = InternalThreadLocalMap.get(); // Netty自己封装的数据结构 不是直接用的Jdk原生的threadLocals指向的ThreadLocalMap 懒加载触发InternalThreadLocalMap中的数组初始化
        Object v = threadLocalMap.indexedVariable(this.index);
        if (v != InternalThreadLocalMap.UNSET) {
            return (V) v;
        }
        /**
         * 首次调用get没有数据的回调initialValue方法
         */
        return initialize(threadLocalMap);
    }
```

### 1 InternalThreadLocalMap懒加载

```java
public static InternalThreadLocalMap get() { // 懒加载 InternalThreadLocalMap使用数组存储元素 初始化默认长度32 全部用UNSET标识占位 脚标从1开始可用
    Thread thread = Thread.currentThread(); // Netty封装了FastThreadLocalThread 根据线程类型区分数据存储策略
    if (thread instanceof FastThreadLocalThread) { // 配套Netty封装的FastThreadLocalThread使用
        return fastGet((FastThreadLocalThread) thread);
    } else { // 配套Jdk的Thread使用
        return slowGet();
    }
}
```



```java
private static InternalThreadLocalMap fastGet(FastThreadLocalThread thread) {
    InternalThreadLocalMap threadLocalMap = thread.threadLocalMap();
    if (threadLocalMap == null) {
        thread.setThreadLocalMap(threadLocalMap = new InternalThreadLocalMap()); // 实例化InternalThreadLocalMap存储数据 默认长度32 全部用UNSET填充
    }
    return threadLocalMap;
}
```



```java
private InternalThreadLocalMap() {
    this.indexedVariables = newIndexedVariableTable(); // 初始化数组 默认容量32
}
```



```java
private static Object[] newIndexedVariableTable() {
    Object[] array = new Object[INDEXED_VARIABLE_TABLE_INITIAL_SIZE]; // 数组初始化 默认容量32
    Arrays.fill(array, UNSET); // 全部用UNSET标识填充
    return array;
}
```

### 2 数组元素设值

```java
// FastThreadLocal.java
 Object v = threadLocalMap.indexedVariable(this.index);
```



```java
// InternalThreadLocalMap.java
public Object indexedVariable(int index) { // 根据数组脚标寻址
    Object[] lookup = indexedVariables;
    return index < lookup.length? lookup[index] : UNSET;
}
```

### 3 首次get没值触发回调初始值

首次调用get没有数据的回调initialValue方法

```java
private V initialize(InternalThreadLocalMap threadLocalMap) {
    V v = null;
    try {
        v = initialValue(); // 回调initialValue方法
    } catch (Exception e) {
        PlatformDependent.throwException(e);
    }

    threadLocalMap.setIndexedVariable(index, v); // 首次get无值时将initialValue方法的值放到数组
    addToVariablesToRemove(threadLocalMap, this);
    return v;
}
```

## 四 set方法

```java
// FastThreadLocal.java
public final void set(V value) {
    if (value != InternalThreadLocalMap.UNSET) { // 有效值
        InternalThreadLocalMap threadLocalMap = InternalThreadLocalMap.get(); // 数据结构
        setKnownNotUnset(threadLocalMap, value);
    } else {
        remove();
    }
}

```



```java
private void setKnownNotUnset(InternalThreadLocalMap threadLocalMap, V value) {
        if (threadLocalMap.setIndexedVariable(index, value)) { // 向数组中放元素 脚标后移 容量不够触发数组扩容
            addToVariablesToRemove(threadLocalMap, this);
        }
    }
```



```java
// InternalThreadLocalMap.java
public boolean setIndexedVariable(int index, Object value) {
    Object[] lookup = this.indexedVariables;
    if (index < lookup.length) {
        Object oldValue = lookup[index];
        lookup[index] = value;
        return oldValue == UNSET;
    } else {
        expandIndexedVariableTableAndSet(index, value); // 扩容
        return true;
    }
}
```

## 五 remove方法

```java
public final void remove() {
    remove(InternalThreadLocalMap.getIfSet());
}
```



```java
public final void remove(InternalThreadLocalMap threadLocalMap) {
    if (threadLocalMap == null) {
        return;
    }

    Object v = threadLocalMap.removeIndexedVariable(index);
    removeFromVariablesToRemove(threadLocalMap, this);

    if (v != InternalThreadLocalMap.UNSET) {
        try {
            onRemoval((V) v);
        } catch (Exception e) {
            PlatformDependent.throwException(e);
        }
    }
}
```

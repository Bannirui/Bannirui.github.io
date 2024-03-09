---
title: Java源码-0x03-MarkWord
category_bar: true
date: 2024-03-09 10:36:09
categories: Java
tags: Java@15
---

### 1 类结构

![](./Java源码-0x03-MarkWord/1709952220.png)

```cpp
#if __WORDSIZE == 64
# ifndef __intptr_t_defined
typedef long int		intptr_t;
#  define __intptr_t_defined
# endif
typedef unsigned long int	uintptr_t;
```

这个类很简单，就一个成员变量`_value`，以我当前64位系统为例，该成员的类型是64位整数

即，markword就是一个64位的整数

### 2 布局

![](./Java源码-0x03-MarkWord/1709952617.png)

关于不同状态的翻译，下面贴上源码中的注释作为对比

|中文|英文|
|---|---|
|无锁|unlocked|
|偏向锁|biased|
|轻量级锁|locked|
|重量级锁|monitor|
|GC标记|marked|

偏向锁状态下根据高位记录的线程id又分为

- 记录了偏向的线程id `lock is biased toward given thread`

- 记录了0 `lock is anonymously biased`

### 3 偏向锁

![](./Java源码-0x03-MarkWord/1709953739.png)

我是基于jdk15进行的学习，官网可以看到openjdk15的特性，其中之一就是默认关闭了偏向锁

文件`src/hotspot/share/runtime/globals.hpp`

![](./Java源码-0x03-MarkWord/1709956991.png)

### 3.1 验证UseBiasedLocking

#### 3.1.1 默认

![](./Java源码-0x03-MarkWord/1709954073.png)

#### 3.1.1 手动关闭

![](./Java源码-0x03-MarkWord/1709954256.png)

#### 3.1.1 手动开启

![](./Java源码-0x03-MarkWord/1709954338.png)
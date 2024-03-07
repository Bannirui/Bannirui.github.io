---
title: Java源码-0x01-源码阅读清单
category_bar: true
date: 2024-03-07 12:19:28
categories: Java
tags: Java@15
---

整体计划是将Java的源码事无巨细地过一遍

- 一是弥补一下认知缺陷

- 二是争取从CPP到Java由底至上地理解Java这个语言，很多时候总会感觉多了一层屏障导致理解困难

- 在此过程中完善对计算机OS的知识体系建立

难度很大，过程很大，工程很大，所以能否完结也是待定

### 阅读顺序

- [ ] [1 java.lang](#1)

- [ ] [2 java.util](#2)

- [ ] [3 java.util.concurrent](#3)

- [ ] [4 java.util.concurrent.atomic](#4)

- [ ] [5 java.lang.reflect](#5)

- [ ] [6 java.lang.annotation](#6)

- [ ] [7 java.util.concurrent.locks](#7)

- [ ] [8 java.io](#8)

- [ ] [9 java.nio](#9)

- [ ] [10 java.sql](#10)

- [ ] [11 java.net](#11)

- [ ] [12 java.math](#12)

#### <a id="1">1 java.lang</a>

- [ ] {% post_link Java源码-0x02-Object Object %}

- [ ] String

- [ ] AbstractStringBuilder

- [ ] StringBuffer

- [ ] StringBuilder

- [ ] Boolean

- [ ] Byte

- [ ] Double

- [ ] Float

- [ ] Integer

- [ ] Long

- [ ] Short

- [ ] Thread

- [ ] ThreadLocal

- [ ] Enum

- [ ] Throwable

- [ ] Error

- [ ] Exception

- [ ] Class

- [ ] ClassLoader

- [ ] Compiler

- [ ] System

- [ ] Package

- [ ] Void

- [ ] Number

- [ ] Math

#### <a id="2">2 java.util</a>

- [ ] AbstractList

- [ ] AbstractMap

- [ ] AbstractSet 

- [ ] ArrayList 

- [ ] LinkedList

- [ ] HashMap 

- [ ] Hashtable

- [ ] HashSet

- [ ] LinkedHashMap

- [ ] LinkedHashSet

- [ ] TreeMap

- [ ] TreeSet

- [ ] Vector

- [ ] Queue

- [ ] Stack

- [ ] SortedMap

- [ ] SortedSet 

- [ ] Collections

- [ ] Arrays

- [ ] Comparator

- [ ] Iterator

- [ ] Base64 

- [ ] Date

- [ ] EventListener

- [ ] Random 

- [ ] SubList 

- [ ] Timer 

- [ ] UUID 

- [ ] WeakHashMap

#### <a id="3">3 java.util.concurrent</a>

- [ ] ConcurrentHashMap

- [ ] Executor

- [ ] AbstractExecutorService 

- [ ] ExecutorService 

- [ ] ThreadPoolExecutor

- [ ] BlockingQueue

- [ ] AbstractQueuedSynchronizer

- [ ] CountDownLatch

- [ ] FutureTask

- [ ] Semaphore

- [ ] CyclicBarrier

- [ ] CopyOnWriteArrayList 

- [ ] SynchronousQueue

- [ ] BlockingDeque 

- [ ] Callable

#### <a id="4">4 java.util.concurrent.atomic</a>

- [ ] AtomicBoolean

- [ ] AtomicInteger

- [ ] AtomicLong 

- [ ] AtomicReference

#### <a id="5">5 java.lang.reflect</a>

- [ ] Field

- [ ] Method

#### <a id="6">6 java.lang.annotation</a>

- [ ] Annotation

- [ ] Target

- [ ] Inherited

- [ ] Retention

- [ ] Documented

- [ ] ElementType

- [ ] Native 

- [ ] Repeatable

#### <a id="7">7 java.util.concurrent.locks</a>

- [ ] Lock 

- [ ] Condition

- [ ] ReentrantLock

- [ ] ReentrantReadWriteLock

#### <a id="8">8 java.io</a>

- [ ] File

- [ ] InputStream

- [ ] OutputStream

- [ ] Reader

- [ ] Writer

#### <a id="9">9 java.nio</a>

- [ ] Buffer

- [ ] ByteBuffer

- [ ] CharBuffer

- [ ] DoubleBuffer

- [ ] FloatBuffer

- [ ] IntBuffer

- [ ] LongBuffer

- [ ] ShortBuffer

#### <a id="10">10 java.sql</a>

- [ ] Connection

- [ ] Driver 

- [ ] DriverManager 

- [ ] JDBCType 

- [ ] ResultSet

- [ ] Statement

#### <a id="11">11 java.net</a>

- [ ] Socket 

- [ ] ServerSocket 

- [ ] URI 

- [ ] URL

- [ ] URLEncoder

#### <a id="12">12 java.math</a>

- [ ] BigDecimal

- [ ] BigInteger

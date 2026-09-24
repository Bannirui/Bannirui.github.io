---
title: jvm-12-表示Java引用类型的InstanceRefKlass
category_bar: true
categories: jvm
date: 2026-09-24 22:05:08
---

Java对象的引用众所周知的强软弱虚

在{%post_link java/jvm-10-普通类型InstanceKlass%}里面有个重要的成员

```cpp
  // 引用类型 表示当前的InstanceRefKlass实例的引用类型 对应的是referenceType的枚举 强软弱虚
  u1              _reference_type;          // reference type
```

```cpp
// IntanceRefKlass的引用类型 在InstanceKlass中维护了成员reference_type
enum ReferenceType {
  // 强引用
  REF_NONE,      // Regular class
  // 软引用 SoftReference及其子类
  REF_SOFT,      // Subclass of java/lang/ref/SoftReference
  // 弱引用 WeakReference及其子类
  REF_WEAK,      // Subclass of java/lang/ref/WeakReference
  // Finalizer相关的引用
  REF_FINAL,     // Subclass of java/lang/ref/FinalReference
  // 虚引用 PhantomReference及其子类
  REF_PHANTOM    // Subclass of java/lang/ref/PhantomReference
};
```
---
title: jvm-11-数组类型ArrayKlass
category_bar: true
categories: jvm
date: 2026-09-24 00:50:14
---

它是继承自{%post_link java/jvm-09-Klass%}，是所有数组类的抽象基类

```cpp
  // 数组的维度 比如int[][][]的维度就是3
  int      _dimension;         // This is n'th-dimensional array.
  // 数组的多维转换不单单是高维度到低维度 也需要低维度到高维度 所以每个维度都维护了两个指针 指向更高维度和更低维度 每个维度就像用双向链表串起来一样
  Klass* volatile _higher_dimension;  // Refers the (n+1)'th-dimensional array (if present).
  Klass* volatile _lower_dimension;   // Refers the (n-1)'th-dimensional array (if present).
```
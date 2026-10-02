---
title: jvm-15-Hotspot的oop-Klass二分模型
category_bar: true
categories: jvm
date: 2026-10-03 00:36:01
---

HotSpot采用oop-Klass模型表示Java的对象，oop指向对象，Klass表示对象的具体类型

为了不想每个对象都含有vtable，就把对象模型一拆为二

- oop中不包含任何虚函数，自然就没有了虚函数表 {%post_link java/jvm-16-Java对象的表示oop%}
- Klass中含有虚函数表，进行方法的分发 {%post_link java/jvm-09-Java类的表示Klass%}
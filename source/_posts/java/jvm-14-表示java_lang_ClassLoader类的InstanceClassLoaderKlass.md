---
title: jvm-14-表示java_lang_ClassLoader类的InstanceClassLoaderKlass
category_bar: true
categories: jvm
date: 2026-09-24 22:06:08
---

没有添加新的字段，但是增加了新的oop遍历的方法，在垃圾回收阶段遍历类加载器所加载的所有类，来标记引用的所有对象
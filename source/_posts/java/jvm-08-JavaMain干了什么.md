---
title: jvm-08-JavaMain干了什么
category_bar: true
categories: jvm
date: 2026-09-23 00:23:53
---

主要就是找到java的启动类的main方法，然后执行它

- 1 InitializeJVM初始化JVM
- 2 LoadMainClass获取Java程序的启动类
- 3 GetStaticMethodId查找Java启动类的main方法
- 4 调用JNIEnv中定义的CallStaticVoidMain最终执行到Java启动类的main方法
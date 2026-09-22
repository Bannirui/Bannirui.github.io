---
title: jvm-04-Java入口函数
date: 2023-04-28 13:18:56
category_bar: true
categories: jvm
---

这个函数进行了一些列的操作

- 加载libjjvm
- 参数解析
- Classpath的获取和设置
- 系统属性设置
- JVM初始化
/    // 把jvm动态库里面3个函数地址保存在ifn里面 初始化jvm的时候要用
    return JVMInit(&ifn, threadStackSize, argc, argv, mode, what, ret);
**```jacpp``
最重要的是JVM的初始化，但是在JVM初始化过程中有对jvm动态库的3个函数依赖，因此要先把动态库里面那3个函数地址掏出来

- {%post_link java/jvm-05-加载JVM动态库%}
- {%post_link java/jvm-07-JVM的启动%}
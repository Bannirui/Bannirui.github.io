---
title: Python和CPP混合编程
category_bar: true
date: 2026-01-23 15:38:12
categories: Python
---

[我在git有详细的项目可以当作项目模板使用](https://github.com/Bannirui/my-py-cpp.git)

在py中调用cpp涉及两个层面的东西

- 一是编译cpp的代码成库，用到scikit-build-core
- 二是让python能认识cpp代码，用到pybind11

之后就是工程性的问题了，在pip时机触发cpp代码编译成库，然后导出cpp符号绑定成python认识的就行。
---
title: cmake教程记录
date: 2023-12-07 13:46:42
category_bar: true
categories: 笔记
tag: cmake
---

为什么要学cmake，先说一个我的使用场景。

我常用电脑有2台，mac和linux的，但是我常用工具链就那么几个，在两台电脑上的配置统一化就存在必要性了。再者以后再添置一台电脑，又得吭哧吭哧配置一遍工具链。其次，我曾经在mac上误删了`rm -rf`某个目录导致需要重新配置一遍。

凡此种种，都是实际的需求场景，所以我需要为自己做一个脚本工具，统一管理我使用的工具链，换电脑了只要执行一下脚本就行。

此前我的方式是手写Makefile的方式，但是有几个问题

- 不方便层级式管理
- 充斥大量的`if...else...`语句判断系统平台类型

主要因为跨平台性的考虑，因此现在使用了cmake作为生成器，用来生成构建文件Makefile。

毕竟[git仓库项目](https://github.com/Bannirui/os_script.git)中包含了所有的配置和隐私信息，就设置为了private。

![](cmake教程记录/1701928361.png)

cmake的用途远不为此，跨平台性让我们从构建管理工具的平台限制脱离出来，聚焦于CMakeLists文件的编写即可，可以灵活选择平台和构建工具。

因此用[tutorial](https://github.com/Bannirui/tutorial.git)这个项目记录了一下cmake的学习，基本囊括了日常使用的指令。

![](cmake教程记录/1701929890.png)
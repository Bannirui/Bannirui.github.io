---
title: IDEA远程vim插件异常记录
category_bar: true
date: 2024-03-08 17:32:43
categories: IDE
---

感谢jetbrains社区的帮助，虽然问题不大，但是如鲠在喉地难受。

[社区的记录](https://youtrack.jetbrains.com/issue/VIM-3334/Cant-add-new-lines-when-using-o-or-O-when-using-remote-dev-and-have-IdeaVIM-installed-in-the-host-side.)

### 1 问题

用IDEA连接ssh远程开发的时候，用vim插件进入insert模式的时候新建行失效

- o

- O

### 2 解决方案

社区给的答复是在plugins中只需要在client端安装插件IdeaVim，在host端不需要安装

我的问题就是因为同时在client和host都安装了IdeaVim插件导致的
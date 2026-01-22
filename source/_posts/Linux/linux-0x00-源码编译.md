---
title: linux-0x00-源码编译
category_bar: true
date: 2025-04-14 17:37:10
categories: Linux源码
---

先fork项目，然后将源码下载到本地。

```sh
git clone git@github.com:Bannirui/linux.git
git remote add upstream git@github.com:torvalds/linux.git
git remote set-url --push upstream no_push
git remote -v
git checkout -b study-6.4-rc2 origin/study-6.4-rc2
```
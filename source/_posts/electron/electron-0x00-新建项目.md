---
title: electron-0x00-新建项目
category_bar: true
date: 2025-03-17 10:48:03
categories: electron
---

用脚手架模板新建项目

```sh
npm create @quick-start/electron@latest
```

执行过程中报错没有权限的话就给当前用户赋予sudo权限

```sh
sudo chown -R 501:20 "/Users/dingrui/.npm"
```
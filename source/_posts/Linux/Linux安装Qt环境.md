---
title: Linux安装Qt环境
category_bar: true
date: 2024-05-03 18:45:55
categories: Linux
---

Linux的发行版中带GUI的很多都依赖Qt，所以我觉得直接安装Qt的核心包到系统中可能会替换掉核心依赖，也不利于以后的包清理工作。
再者，QtCreator还是有可取之处的，比如QtDesigner，这个在Clion中是找不到可比拟的插件的。

鉴于上述2个原因，我要在Debian上安装Qt的开源组件

1 下载安装器
---

[官网地址](https://www.qt.io/product/development-tools)上注册个人账号，下载安装器。

2 安装开发工具
---

我选择的是QtCreator

3 基本依赖
---

图形化开发，系统还需要提供一些基础依赖包

```sh
sudo apt install build-essential libgl1-mesa-dev
```

4 cmake文件指定安装包
---

因为这种安装方式不会把头文件install到`/usr/include`中，并且lib也不会安装，所以要指定`CMAKE_PREFIX_PATH`

以为的安装路径为例

```CMakeLists
set(CMAKE_PREFIX_PATH "/home/dingrui/MyApp/Qt/6.7.0/gcc_64")
```
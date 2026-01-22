---
title: 安装KiCad
date: 2023-12-13 22:38:46
category_bar: true
categories: 笔记
tag: KiCad
---

设计类软件基本都是收费的，找到好用的开源软件是件幸事，EDA找到了[KiCad](https://www.kicad.org/)，3D建模找到了[FreeCAD](https://www.freecad.org/)。

1 安装
---

官网贴心地准备了各操作系统的安装方式，非常全乎。

![](安装KiCad/1702478525.png)

2 库文件路径问题
---

应该是linux的上的问题，全局和用户的目录识别有问题。

![](安装KiCad/1702478766.png)

在设置的路径管理中的路径，与符号库和元件库的扫描的路径不一致，导致符号库和元件库里面是空的。

![](安装KiCad/1702479017.png)

- kicad默认配置的路径管理是系统的，也就是`/usr/share/kicad`里面的路径
- 而库管理器默认扫描的是用户的，即`~/.loacal/share/kicad`里面的

因此要想使用kicad自带的库文件，就手动到库管理器里面，加载全局库路径的文件即可，全选一次导入。
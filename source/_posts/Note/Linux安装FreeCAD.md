---
title: Linux安装FreeCAD
date: 2023-12-11 16:21:54
category_bar: true
categories: 笔记
---

1 下载
---

我蛮熟悉UG的，但是没有找到linux的破解版本。其实3D软件大体是相似的，只是各家软件在细分领域有着不同的优势和特性。因此在linux上安装[FreeCAD](https://www.freecad.org/downloads.php)。

2 安装
---

```shell
yay -Ss freecad

yay -Syy freecad
```

通过yay方式安装后运行`freecad`会报错链接不到动态库`libboost_filesystem.so.1.83.0`。因此换用官网下载安装包的方式

```shell
mkdir -p ~/documents/freecad
cp ~/downloads/FreeCAD_0.21.1-Linux-x86_64.AppImage ~/documents/freecad/

cd ~/documents/freecad/
chmod +x ./FreeCAD_0.21.1-Linux-x86_64.AppImage
./FreeCAD_0.21.1-Linux-x86_64.AppImage
```
可以看到能运行起来，下面就是制作一个桌面入口。

3 快捷方式
---

```shell
cd ~/.local/share/applications

cp clash.desktop freecad.desktop
```

然后修改对应的信息即可。

```shell
chmod +x ./freecad.desktop
```

按键`option`唤出搜索窗口输入`freecad`运行，然后右键`freecad`选择`Pin Launcher`固定到底部dock。
---
title: GParted重分区
date: 2023-12-13 19:08:43
category_bar: true
categories: Linux
---

今天安装软件的时候报错提示空间不够，`df -h`如下

![](GParted重分区/1702465863.jpg)

可以看到分区`/dev/nvme0n1p2`，挂在带你在`/`下，当初装这个系统是用`arch install`自动分区的，没注意才分了20G，现在已经快满了，所以要进行重分区。

1 安装GParted
---

```shell
pacman -Ss gparted

sudo pacman -S gparted

gparted
```

2 GParted分区扩容
---

![](GParted重分区/1702468339.jpg)

可以看到我总共就3个分区，除去启动盘，我只要将分区3缩容让出左边一些空间，然后对分区2进行扩容用上刚才让出来的空间。
但是可惜的是分区右边都有一把锁的标识，并且无法`unmount`分区。这3个分区都是我挂在根区下的使用着的分区，肯定不能`unmount`的，但凡其中一个能被卸载，电脑都不能正常工作了，因此也算是一种保护。

3 GParted Live
---

![](GParted重分区/1702469551.png)

在[官网](https://gparted.org/livecd.php)上看到可以把`GParted Live`镜像烧录到U盘做成启动盘，然后用启动盘重分区。

官网的文档极其详尽，跟着操作就行了。

### 3.1 [下载镜像](https://gparted.org/download.php)

![](GParted重分区/1702470022.png)

### 3.2 烧录U盘

只介绍了2种烧录方式

- windows
- [linux](https://gparted.org/liveusb.php#linux-method-d)

linux下用`Tuxboot`烧录最为简单

![](GParted重分区/1702470175.png)

![](GParted重分区/1702470691.png)

我手边的这个U盘还是之前用来做Ubuntu的系统启动盘，现在要另作他用了。
其次`tuxboot`这个工具还必须得用yay来安装。

```shell
yay -Ss tuxboot

yay -S tuxboot
```

这个软件是qt写的，所以可想而知是个比较大的工程，下载编译安装比较耗时(30min)。可惜的是安装好后运行`sudo tuxboot`先是提示缺失`7z`，安装好依赖之后，界面显示不出来相应的工作区，应该是我的系统缺少一些动态库。

于是转而换个工具`unetbootin`

```shell
pacman -Ss unetbootin

yay -Ss unetbootin

yay -S unetbootin

sudo unetbootin
```

将iso镜像烧写到u盘中即可，u盘这儿不是显示的名称，而是盘符名字，只要在终端`df -h`即可看到u盘的盘符名字，不要选错。

![](GParted重分区/1702474800.jpg)

在烧写过程中会有进度条提示

![](GParted重分区/1702474984.jpg)

### 3.2  U盘启动盘

每个人进BIOS不尽相同，选择U盘启动即可。

我的零克迷你机的方式在另一篇{% post_link 多桌面系统环境 %}中讲过。

#### 3.2.1 gparted live模式

不用改变，默认选择即可，n秒不操作键鼠之后会根据默认第一项进入

![](GParted重分区/1702475240.jpg)

#### 3.2.2 快捷键映射

选择第2项目`do not touch keymap`

![](GParted重分区/1702475384.jpg)

#### 3.2.2 语言

左下角提示选择语言，输入26，选择汉语

![](GParted重分区/1702475437.jpg)

#### 3.2.3 启动模式

默认是0，应该是基于x框架的gui，直接按enter即可。

![](GParted重分区/1702475885.jpg)

#### 3.2.4 gparted分区

进入系统，默认会打开gparted工具，如果没有就鼠标双击方式自己打开软件。此时可以看到分区上是没有锁的标志的，之后的操作就是gparted了，比如我现在分区2是20G，我想扩到100G。

![](GParted重分区/1702475992.jpg)

因此

- 先resize分区3，减少80G，将分区3右侧让出空闲80G
- 移动分区3，将分区3移动到最右侧，此时分区2和分区3之间有80G的未分配区
- 最后，resize分区2，将分区2大小扩大80G

![](GParted重分区/1702476195.jpg)

之后有是一段比较耗时的过程，静静等待即可

![](GParted重分区/1702476251.jpg)


#### 3.2.5 重启

之后关闭gparted，双击屏幕的`Exit`图标即可

![](GParted重分区/1702476411.jpg)

随后根据提示，选择`reboot`重启电脑，重启之前拔掉U盘，因为此时BIOS还是设置的U盘启动盘为第一优先级。

![](GParted重分区/1702476559.jpg)

#### 3.2.6 完成分区扩容

此时再看分区情况，分区2已经如愿以偿从20G扩到了100G。

![](GParted重分区/1702476609.jpg)
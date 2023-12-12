---
title: pyocd使用
date: 2023-12-12 09:15:47
categories: 单片机
---

我使用的调试器是`openocd`，但是查看了帮助信息好像没有找到关于`list`列表信息功能，这着实是有点不太科学的。我现在的需求就是需要查看电脑端口的占用情况已经设备详情信息。因此找到了`pyocd`这款调试器，目前这个调试器仅仅为了满足`list`的需求，如果使用体验很好的话，程序的烧录可能也会切到这个调试器。

我的设备是Arch Linux x86_64。

1 安装
---

```shell
pip --version
pip install pyocd
```

然后就提示`error: externally-managed-environment`，并给出友善建议使用`pacman -S python-xzy`，于是乎


```shell
yay -Ss pyocd
yay -Syy python-pyocd
```

2 list
---

```shell
pyocd --version
pyocd --help
pyocd list --help
```

可以看到`pyocd`的子功能`list`提供了很多的option。
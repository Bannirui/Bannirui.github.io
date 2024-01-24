---
title: ArchLinux安装蓝牙模块
date: 2023-12-31 10:16:07
categories: Linux
---

1 安装
---

```shell
yay -Syy bluethz
yay -Syy bluethz-utils
```

2 启动
---

```shell
sudo systemctl enable bluetooth.service
sudo systemctl start bluetooth.service
```

3 使用
---

![](ArchLinux安装蓝牙模块/1703989292.png)
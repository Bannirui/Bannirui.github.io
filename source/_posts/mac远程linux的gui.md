---
title: mac远程linux的gui
date: 2024-02-28 23:00:04
categories: Linux
---

### 1 archlinux服务端配置

#### 1.1 配置文件

文件`/etc/ssh/ssh_config`放开如下两行注释

![](./mac远程linux的gui/1709132597.png)

#### 1.2 重启ssh

```shell
sudo systemctl restart ssh
```

### 2 mac客户端配置

#### 2.1 配置文件

文件`/private/etc/ssh/ssh_config`放开如下注释

![](./mac远程linux的gui/1709132821.png)

#### 2.2 安装XQuartz

[XQuartz官网](https://www.xquartz.org/)

下载安装即可，安装好后会进行重启

```shell
ssh -X dingrui@archlinux
```

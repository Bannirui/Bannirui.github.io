---
title: ssh远程主机
date: 2024-01-25 09:26:27
category_bar: true
categories: Linux
---

1 linux主机服务端
---

### 1.1 sshd安装

- 查看sshd状态`systemctl status sshd`

![](./ssh远程主机/1706147581.png)

- 如果没有ssh服务端就进行安装和配置

  - 是否安装过`yay -Q |grep openssh`

  - 安装`yay -Syy openssh`

  - 启动`systemctl start sshd`

  - 开机自启动`systemctl enable ssh`

### 1.2 sshd配置

因为我不打算登陆root用户，所以没有修改配置文件`/etc/ssh/sshd-config`

![](./ssh远程主机/1706148360.png)

查看当前ssh服务器的ip地址`ip addr`

2 本地连接远程
---

### 2.1 手动连接

在终端输入`ssh 用户名@远程ip -p 22`即可，随后按照提示键入远程主机用户密码。

![](./ssh远程主机/1706149922.png)

首先每次输入ip地址是比较繁琐的

- 可以先修改远程主机的`/etc/hostname`、`/etc/hosts`、`/etc/sysconfig/hostname`，为当前远程主机起个名称，让ssh客户端可以连接。然后重启主机`reboot`即可。

- ssh客户端修改`/etc/hosts`增加上ip映射，那么之后就可以用易于记忆的`ssh 用户名@主机名 -p 22`来替代上面的ip地址了

### 2.2 自动连接

我没有使用上面的ip映射方案，因为用iterm2终端更省事。

- 区别于本机的终端配置，新建一个

- 指定command为`ssh 用户名@远程主机ip -p 22`

- 识别到`password:`后自动输入用户密码，切记在密码之后加上换行符

![](./ssh远程主机/1706150411.png)

![](./ssh远程主机/1706150579.png)

至此，便可以直接新建一个终端窗口直连远程主机

![](./ssh远程主机/1706150869.png)

3 拷贝文件或文件夹
---

||本机->远程|远程->本机|
|---|---|---|
|文件|scp 本机路径 远程用户名@远程主机ip:远程路径|scp 远程用户名@远程主机ip:远程路径 本机路径|
|文件夹|scp -r 本机路径 远程用户名@远程主机ip:远程路径|scp -r 远程用户名@远程主机ip:远程路径 本机路径|
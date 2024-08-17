---
title: MySQL-0x03-认证超时
category_bar: true
date: 2024-08-18 00:17:44
categories: MySQL协议
---

### 1 认证超时

向mysql服务端发送认证包后收到了error包，解析出来看报错信息是超时导致的，因此要改一下服务端的配置文件。

![](./MySQL协议-0x03-认证超时/1722654487.png)

### 2 mysql配置

当时为了图省事，我的服务端是用`homebrew`安装的，因此得先找一下默认的配置文件路径。

```sh
mysql --verbose --help | grep my.cnf
```

![](./MySQL协议-0x03-认证超时/1722654650.png)

我的是在`/usr/local/etc/my.cnf`，在这个文件加上两行配置重启服务端

![](./MySQL协议-0x03-认证超时时/1722654856.png)
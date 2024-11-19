---
title: 安装MySQL
category_bar: true
date: 2024-11-19 09:51:17
categories: Docker
tags: MySQL
---

### 1 image

在desktop搜索mysql 选中了最新的版本pull下来

### 2 container

![](./安装MySQL/1731985029.png)

运行image，通过环境参数制定mysql的默认密码`MYSQL_ROOT_PASSWORD=19920308`

对应的docker run如下

```shell
docker run --name mysql -p 3306:3306 --env=MYSQL_ROOT_PASSWORD=19920308 -d mysql
```

### 3 新建mysql用户

启动docker bash执行如下，创建个新的mysql用户，分配远程访问权限

```sh
CREATE USER 'dingrui'@'%' IDENTIFIED BY '19920308';
GRANT ALL ON *.* TO 'dingrui'@'%';
FLUSH PRIVILEGES;
```

### 4 连接mysql

然后用宿主机ip进行连接
![](./安装MySQL/1731993883.png)
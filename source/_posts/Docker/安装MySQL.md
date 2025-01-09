---
title: 安装MySQL
category_bar: true
date: 2024-11-19 09:51:17
categories: Docker
tags: MySQL
---

### 1 image

- docker pull mysql:5.7
- docker pull mysql:8.0

### 2 container

![](./安装MySQL/1731985029.png)

为了多应用容器共享同个数据库，需要建立docker网络

```sh
docker network create mysql5network
```

运行image，通过环境参数制定mysql的默认密码`MYSQL_ROOT_PASSWORD=19920308`，启动容器并连接到网络中

- docker run --name mysql5 --network mysql5network -p 3306:3306 --env=MYSQL_ROOT_PASSWORD=19920308 -d mysql:5.7
- docker run --name mysql8 --network mysql8network -p 3306:3306 --env=MYSQL_ROOT_PASSWORD=19920308 -d mysql:8.0

### 3 新建mysql用户

启动docker bash以root用户登陆

`mysql -uroot -p19920308`

创建个新的mysql用户并分配远程访问权限

```sh
CREATE USER 'dingrui'@'%' IDENTIFIED BY '19920308';
GRANT ALL ON *.* TO 'dingrui'@'%';
FLUSH PRIVILEGES;
```

### 4 连接mysql

然后用宿主机ip进行连接

![](./安装MySQL/1731993883.png)
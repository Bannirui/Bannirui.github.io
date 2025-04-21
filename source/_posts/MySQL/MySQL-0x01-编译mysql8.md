---
title: MySQL源码-0x01-编译mysql8
category_bar: true
date: 2024-08-18 00:27:51
categories: MySQL
---

### 1 环境

| Name  | Version  |
| ----- | -------- |
| macOS | 11.5.2   |
| clion | 2023.1.1 |
| git   | 2.40.0   |

### 2 源码

```shell
fork

git clone git@github.com:Bannirui/mysql-server.git

git remote add upstream git@github.com:mysql/mysql-server.git
git remote set-url --push upstream no_push

git remote -v

git checkout -b study-8.0 origin/8.0
git add .
git commit -m 'buid on clion'
git push origin study-8.0
```

### 3 Clion设置

[祭上源码编译的官方文档](https://dev.mysql.com/doc/refman/8.0/en/source-installation-prerequisites.html)

#### 3.1 新建日志目录

```shell
mkdir -p build/data
```

#### 3.2 Boost源码

最好不要用cmake自动下载Boost源码，失败率太高，比较好的方式是手动下载到本地。

[先到官网下载Boost源码到本地](https://www.boost.org/users/history/)

#### 3.3 cmake设置

```shell
-DWITH_DEBUG:BOOL=ON
-DDOWNLOAD_BOOST:BOOL=OFF
-DWITH_BOOST:PATH=/Users/dingrui/MyDev/env/boost/boost_1_77_0
-DCMAKE_INSTALL_PREFIX:PATH=/build
-DMYSQL_DATADIR:PATH=/build/data
```

![](./MySQL源码-0x01-编译mysql8/image-20230426185421743.png)

#### 3.4 编译

![](./MySQL源码-0x01-编译mysql8/image-20230426172509886.png)

#### 3.5 运行msqld

##### 3.5.1 新建data目录

```shell
mkdir -p build-out/data
```

##### 3.5.2 gitignore

![](./MySQL源码-0x01-编译mysql8/image-20230426190400219.png)

##### 3.4.3 初始化

```shell
--basedir=/Users/dingrui/Dev/code/git/cpp/mysql-server/build-out
--datadir=/Users/dingrui/Dev/code/git/cpp/mysql-server/build-out/data
--initialize-insecure
```

![](./MySQL源码-0x01-编译mysql8/image-20230426190013421.png)

##### 3.5.4 启动服务

修改启动参数再次运行即可。

```shell
--basedir=/Users/dingrui/Dev/code/git/cpp/mysql-server/build-out
--datadir=/Users/dingrui/Dev/code/git/cpp/mysql-server/build-out/data
```
---
title: Tomcat-0x00-调试环境
index_img: /img/Tomcat-0x00-调试环境.png
date: 2023-04-15 10:43:29
category_bar: true
tags: Tomcat@11.0
categories: Tomcat源码
---

### 1 环境准备

| Name  | Version |
| ----- | ------- |
| macOS | 11.5.2  |
| Git   | 2.40.0  |
| Ant   | 1.10.13 |
| IDEA  | 2023.1  |

### 2 源码

#### 2.1 fork

https://github.com/apache/tomcat

#### 2.2 clone

```shell
git clone git@github.com:Bannirui/tomcat.git
```

#### 2.3 checkout

新切一个分支my-study-11，此后学习过程中的笔记也会同步记录在这个分支上。

```shell
git checkout -b my-study-11
git push origin my-study-11:my-study-11

git remote add upstream https://github.com/apache/tomcat.git
git remote set-url --push upstream no_push
```



![](Tomcat-0x00-调试环境/image-20230415110244331.png)

### 3 IDEA导入

![](Tomcat-0x00-调试环境/image-20230415110556860.png)

#### 3.1 根目录新建文件夹tomcat-build-libs

![](Tomcat-0x00-调试环境/image-20230415110745767.png)

#### 3.2 build.properties

复制build.properties.default为build.properties，并修改如下配置项`base.path`为上面一步新建的文件夹。

![](Tomcat-0x00-调试环境/image-20230415110914589.png)

#### 3.3 build.xml

注释如图3个file配置项，仅保留`build.properties`，也就是上面一步复制出来的文件。

![](Tomcat-0x00-调试环境/image-20230415111112948.png)

#### 3.4 ignore

![](Tomcat-0x00-调试环境/image-20230415111320437.png)

#### 3.5 Ant download-compile

![](Tomcat-0x00-调试环境/image-20230415111427916.png)

### 4 项目设置

#### 4.1 SDK

![](Tomcat-0x00-调试环境/image-20230415150623672.png)

#### 4.2 Modules

![](Tomcat-0x00-调试环境/image-20230415150905512.png)

#### 4.3 Library

将3.5中download compile的添加到项目的library。

![](Tomcat-0x00-调试环境/image-20230415151111573.png)

### 5 调试

#### 5.1 打包

![](Tomcat-0x00-调试环境/image-20230415111427916.png)

#### 5.2 启动

* 启动类为org.apache.catalina.startup.Bootstrap
* 2个VM参数
  * -Dcatalina.home=/Users/dingrui/Dev/code/git/java/tomcat/output/build
  * -Dcatalina.base=/Users/dingrui/Dev/code/git/java/tomcat/output/build

![](Tomcat-0x00-调试环境/image-20230415111650192.png)

#### 5.3 访问服务

![](Tomcat-0x00-调试环境/image-20230415145929949.png)

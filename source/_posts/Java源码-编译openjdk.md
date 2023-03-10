---
title: Java源码-编译openjdk
date: 2023-03-10 23:18:14
tags:
- Java@15
categories:
- Java源码
---

# 1 Sdk编译

前言

* 大于openjdk11u的源码中都含有CompileCommands.gmk，修改即可解决openjdk在Clion中引入头文件问题。
* Java源码换行注释后重新build一下就行，即可解决class与src对应不上问题。

### 1.1 源码

[Git地址](https://github.com/Bannirui/jdk.git)，分支是jdk15-study。

### 1.2 系统工具

* macOS Big Sur 11.5.2
* Xcode 12.5.1
* openjdk 15.0.2
* Make 3.81
* autoconf (GNU Autoconf) 2.71
* Apple clang version 12.0.5 (clang-1205.0.22.11)
* ccache version 4.6
* freetype-confi 2.12.0



### 1.3 编译

#### 1.3.1 字符集修改

![](Java源码-编译openjdk/202211212308471.png)

#### 1.3.2 配置

```shell
bash ./configure \
--with-debug-level=slowdebug \
--with-jvm-variants=server \
--with-freetype=bundled \
--with-boot-jdk=/Library/Java/JavaVirtualMachines/adoptopenjdk-15.jdk/Contents/Home \
--with-target-bits=64 \
--disable-warnings-as-errors \
--enable-dtrace
```

#### 1.3.3 编译

```shell
make CONF=macosx-x86_64-server-slowdebug compile-commands

make CONF=macosx-x86_64-server-slowdebug
```

#### 1.3.4 编译成功

```shell
cd build/macosx-x86_64-server-slowdebug/jdk/bin

./java -version
```

![](Java源码-编译openjdk/202211192118571.png)

## 2 Clion调试

### 2.1 导入Clion

![](Java源码-编译openjdk/202211192124928.png)

### 2.2 源码目录

![](Java源码-编译openjdk/202211192127851.png)

### 2.3 配置

#### 2.3.1 build

![](Java源码-编译openjdk/202211192135626.png)

#### 2.3.2 clean

![](Java源码-编译openjdk/202211192136188.png)

### 2.4 构建目标

![](Java源码-编译openjdk/202211192136119.png)

### 2.5 LLDB修复

```shell
vim ~/.lldbinit
```



```she
br set -n main -o true -G true -C "pro hand -p true -s false SIGSEGV SIGBUS"
```

### 2.6 调试面板配置

#### 2.6.1 Jdk版本

![](Java源码-编译openjdk/202211192145954.png)

#### 2.6.2 Java文件

##### 2.6.2.1 编译Java代码

![](Java源码-编译openjdk/202211192158613.png)

##### 2.6.2.2 调试Class文件

![](Java源码-编译openjdk/202211192203452.png)

## 3 IDea调试

在调试Jdk源码过程中可能需要追踪c/cpp甚至汇编指令，方便起见新建项目不需要package路径。

### 3.1 新建项目

[Git地址](https://github.com/Bannirui/openjdk15-debug.git)

![](Java源码-编译openjdk/202302021319015.png)

注意项

* Build system选择Intellij
* JDK选择自己编译好的SDK

### 3.2 新建SDK

![](Java源码-编译openjdk/202211192236482.png)

### 3.3 项目使用SDK

![](Java源码-编译openjdk/202211192237161.png)

### 3.4 项目依赖

![](Java源码-编译openjdk/202211192238493.png)


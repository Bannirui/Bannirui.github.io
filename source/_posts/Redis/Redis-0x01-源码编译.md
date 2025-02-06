---
title: Redis-0x01-源码编译
category_bar: true
date: 2024-04-13 15:42:29
categories: Redis
---

### 1 环境

| Name  | Ver      |
| ----- | -------- |
| MacOS | 11.5.2   |
| Clion | 2022.3.3 |
| Clang | 12.0.5   |
| LLDB  | 15.0.5   |

### 2 源码

[github源码地址](https://github.com/redis/redis)

[我的源码笔记地址](https://github.com/Bannirui/redis.git)

将源码for到自己仓库

```shell
git clone git@github.com:Bannirui/redis.git
cd redis
git remote add upstream git@github.com:redis/redis.git
git remote set-url --push upstream no_push
git fetch upstream
git checkout 6.2
git checkout -b study-6.2
git push origin study-6.2
```

> 在mac arm平台下直接编译会报错
![](./Redis-0x01-源码编译/1738835101.png)

### 3 导入Clion并编译

#### 3.1 ToolChain

将使用Clang作为构建调试工具，调试器不能使用GDB，之前使用GDB有问题，得使用LLDB。

![](Redis-0x01-源码编译/image-20230323103838439.png)

#### 3.2 编译
##### 3.2.1 直接用make
###### 3.2.1.1 make配置

选择Clang作为Makefile项目的构建工具。

![](Redis-0x01-源码编译/image-20230323104043451.png)

![](Redis-0x01-源码编译/image-20230323104203310.png)

###### 3.2.1.2 make test

根据提示，出现如下提示`It's a good idea to run 'make test'`，则在终端执行`make test`。

![](Redis-0x01-源码编译/image-20230323104341081.png)

###### 3.2.1.3 编译成功

终端出现如下提示`All tests passed without errors`，则表示编译成功。

![](Redis-0x01-源码编译/image-20230323104921216.png)

##### 3.2.2 用cmake生成make脚本
###### 3.2.2.1 cmake配置
![](./Redis-0x01-源码编译/1738834483.png)

###### 3.2.2.2 sh脚本

进到项目根目录下执行
```sh
./configure.sh
./build.sh
```

### 4 调试

#### 4.1 配置

![](Redis-0x01-源码编译/image-20230323105129795.png)

#### 4.2 启动

##### 4.2.1 服务端

服务端已经启动监听在知名端口。

![](Redis-0x01-源码编译/image-20230323105243908.png)

##### 4.2.2 客户端

启动客户端跟服务端交互，此时就可以进行调试跟踪了。

![](Redis-0x01-源码编译/image-20230323105431146.png)
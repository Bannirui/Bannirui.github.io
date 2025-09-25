---
title: jvm-0x10-用Docker作编译环境
category_bar: true
date: 2025-09-25 00:16:54
categories: jvm
---

前面已经在mac{% post_link java/jvm-0x00-编译openjdk %}和linux{% post_link java/jvm-0x01-在Linux上编译openjdk22 %}物理机上折腾过编译，之所以还在不厌其烦整编译，主要原因是我经常切换不同设备，很难保证环境工具的一致性，而且在物理机上编译确实可能对我现有的工具链产生侵入，所以这次又有docker上进行编译。想必这也是我最后一次做编译环境，后面就彻底统一了。

后面我尽量长期坚持更新源码笔记会在[GIT仓库](https://github.com/Bannirui/jdk.git)的`jdk_22_study`分支上。

### 1 Dockerfile

不单单是编译jdk的必需依赖，还是我日常开发常用的工具环境，后面还有其他的我也会添加进来。

```Dockerfile
# 使用官方Ubuntu22.04作为基础镜像
FROM --platform=linux/amd64 ubuntu:22.04

# 设置非交互模式 避免安装过程中阻塞
ENV DEBIAN_FRONTEND=noninteractive

# 更新源并安装所需工具
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # gcc g++ make ld etc
    build-essential \
    # x86 assembler
    nasm \                  
    # ld objdump objcopy
    binutils \              
    # mkfs dd支持
    dosfstools \            
    # mount umount sync
    util-linux \
    # cp rm等基础命令
    coreutils \
    git \
    wget \
    # OpenJDK 21和编译openjdk-22源码需要的依赖
    openjdk-21-jdk autoconf libasound2-dev libcups2-dev libfontconfig1-dev libx11-dev libxext-dev libxrender-dev libxrandr-dev libxtst-dev libxt-dev file zip unzip gawk \
    && rm -rf /var/lib/apt/lists/*

# 设置Java环境变量
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

# 设置工作目录
VOLUME /home/dev
WORKDIR /home/dev

# 容器启动后保持交互 shell
CMD ["/bin/bash"]
```
### 2 准备docker环境

#### 2.1 制作镜像 

```sh
docker buildx build \
  --build-arg http_proxy=http://host.docker.internal:7890 \
  --build-arg https_proxy=http://host.docker.internal:7890 \
  --build-arg all_proxy=socks5://host.docker.internal:7890 \
  -t my-linux-dev ./docker --platform linux/amd64
```

#### 2.2 启动容器

```sh
docker run \
--ulimit nofile=65535:65535 \
--cap-add=SYS_PTRACE \
--security-opt seccomp=unconfined \
--rm -it \
--privileged \
--name my-linux-dev \
-v /etc/localtime:/etc/localtime:ro \
-v $PWD:/home/dev my-linux-dev
```

> 这里有个特别要注意的点就是参数`--ulimit nofile=65535:65535`因为在jdk的工程太过庞大，在编译过程中需要打开很多的文件，所以这个参数一定要给够

### 3 编译

正式的编译过程就跟在物理机上一样了

#### 3.1 configure

```sh
bash ./configure \
--with-debug-level=slowdebug \
--with-jvm-variants=server \
--with-freetype=bundled \
--with-boot-jdk=$JAVA_HOME \
--with-target-bits=64 \
--disable-warnings-as-errors \
--with-extra-cxxflags="-std=c++14"
```

#### 3.2 make

```sh
make CONF=linux-x86_64-server-slowdebug
```

#### 3.3 运行java

```sh
./build/linux-x86_64-server-slowdebug/jdk/bin/java -version
```
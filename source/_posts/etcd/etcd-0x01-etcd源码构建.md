---
title: etcd-0x01-etcd源码构建
category_bar: true
date: 2025-06-05 14:45:26
categories: etcd
---

### 1 etcd主项目

#### 1.1 源码

```sh
git clone git@github.com:Bannirui/etcd.git
cd etcd
git remote add upstream git@github.com:etcd-io/etcd.git
git remote set-url --push upstream no_push
git remote -v
git checkout -b my_study
```

#### 1.2 构建

```sh
make build
```

在项目根目录下生成bin目录，3个可执行文件

- etcd 服务
- etcdctl 命令行工具
- etcdutl 底层工具

#### 1.3 启动

##### 1.3.1 服务端

可以用编译好的可执行文件，也可以在IDEA中调试，考虑到后期的调试，肯定在IDEA中比较方便，在IDEA中直接启动不用手动显式指定启动参数，全部用默认。

```sh
./bin/etcd \
  --name node1 \
  --data-dir default.etcd \
  --listen-client-urls http://127.0.0.1:2379 \
  --advertise-client-urls http://127.0.0.1:2379 \
  --listen-peer-urls http://127.0.0.1:2380 \
  --initial-advertise-peer-urls http://127.0.0.1:2380 \
  --initial-cluster node1=http://127.0.0.1:2380 \
  --initial-cluster-token tkn \
  --initial-cluster-state new
```

##### 1.3.2 客户端

```sh
./bin/etcdctl put foo bar
./bin/etcdctl get foo
```

### 2 raft模块

在看的过程中发现`raft.node`不在当前etcd的工程源码中，而是在依赖的go module中，因此看到raft模块是个单独的工程。

```sh
git clone git@github.com:Bannirui/raft.git
cd raft
git remote add upstream git@github.com:etcd-io/raft.git
git remote set-url --push upstream no_push
git remote -v
git checkout -b my_study
```
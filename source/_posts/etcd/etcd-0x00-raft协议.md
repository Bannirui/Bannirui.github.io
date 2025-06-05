---
title: etcd-0x00-raft协议
category_bar: true
date: 2025-06-05 14:30:38
categories: etcd
---

> [raft的官网](https://raft.github.io/)

很久以前看完{% post_link ZK-3-8源码-00-源码环境 %}后就没咋看过分布式相关的东西，最近无意间瞧见了raft，直观上的感觉是raft比zab更轻量，可以复刻在自己的项目上。

[用python实现了raft基本功能](https://github.com/Bannirui/raft-py.git)，愈发对raft协议在实际工程上的实现方式和技术手段感兴趣。尤其是网络通信和文件存储相关的两个方向。

因此，准备入手etcd。
---
title: 从零实现MapReduce分布式系统
category_bar: true
date: 2026-10-09 01:16:06
categories: SideProject
---

[MapReduce论文](https://static.googleusercontent.com/media/research.google.com/en//archive/mapreduce-osdi04.pdf)

最近看了这个论文，虽然我没有从事大数据方向的工作经验，多多少少也知道Hadoop是MapReduce的工程实现，Hadoop曾经也是风光一时无两

单纯的map/reduce编程思想不难接受，这样的一个系统想想就能感受到它的难度和边界，因此萌生了自己实现一个支持MapReduce系统的想法，应该是我目前遇到的最复杂的一个软件了

[项目git链接](https://github.com/Bannirui/x-map-reduce.git)

其中涉及到的知识点有很多，我想，即使我的能力不能完全支撑做完整个项目，我坚信也能收获很多

- 多线程编程
- 多进程编程
- 运行时动态库
- 网络编程
  - 非阻塞
  - reactor模型
  - 协议
    - TLV设计协议
    - encode/decode
    - 大协议传输
- 线程模型
  - event+reactor
  - event loop
  - boss loop & work loop
- master管理work
  - 节点管理
  - 任务管理
    - 任务派发
    - 任务重试
  - 资源管理
- 怎么让work节点尽量本地化工作
- 怎么让master管理元数据
- 怎么让master派发任务的时候执行用户层ABI实现
- 怎么让shuffle从master上解放出来
- 怎么让集群容错
- master本身怎么做HA
  - 如果给master做集群用什么选举策略
  - 不管是什么共识算法 共识的锚点是什么
    - 理想情况下master只管理集群元数据
    - 那么怎么用元数据做选举策略
---
title: ZK@3.8源码-03-SessionTrackerImpl
date: 2023-03-06 17:38:53
tags:
- ZK@3.8
  categories:
- ZK源码
---

在`ZooKeeperServe`中维护这一个`sessionTracker`，负责对session会话的管理，主要是针对过期的会话进行关闭。`SessionTrackerImpl`就是这个会话管理器的实现。
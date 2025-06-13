---
title: etcd-0x0C-线程模型
category_bar: true
date: 2025-06-12 14:22:09
categories: etcd
---

虽然raft的核心逻辑执行单位仅仅是golang的一个协程，但还是用线程模型比较合适通用。

用多路复用方式实现了事件循环这样的一个线程模型。


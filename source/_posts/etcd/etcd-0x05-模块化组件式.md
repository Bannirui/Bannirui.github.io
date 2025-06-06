---
title: etcd-0x05-模块化组件式
category_bar: true
date: 2025-06-06 15:28:02
categories: etcd
---

```go
	// golang的chan我觉得本质是队列 实际用途既可以当作普通队列的内存缓冲区 又可以退化成常量级别的内存占用的信号量
	// 下面两个是典型的队列用途 用于解耦模块组件之间
	// 客户端put->kv store构建kv键值对->发送到propose channel->raft node订阅propose channel负责同步和半数确认->发送到commit channel->kv store订阅commit channel后持久化
	proposeC := make(chan string)
	defer close(proposeC)
	confChangeC := make(chan raftpb.ConfChange)
	defer close(confChangeC)

	// raft provides a commit stream for the proposals from the http api
	var kvs *kvstore
	// 内存中map序列化json
	getSnapshot := func() ([]byte, error) { return kvs.getSnapshot() }
	// 组件式思想 各司其职 raftNode负责raft算法实现 kvstore负责键值对数据库 httpKVAPI负责对客户端
	commitC, errorC, snapshotterReady := newRaftNode(*id, strings.Split(*cluster, ","), *join, getSnapshot, proposeC, confChangeC)

	kvs = newKVStore(<-snapshotterReady, proposeC, commitC, errorC)

	// the key-value http handler will propose updates to raft
	serveHTTPKVAPI(kvs, *kvport, confChangeC, errorC)
```

按照功能划分有3个核心模块

- httpKVAPI 服务端接收客户端请求 {% post_link etcd/etcd-0x06-怎么跟客户端通信 %}

- kvstore 键值对数据库

- raftnode 实现raft协议共识算法
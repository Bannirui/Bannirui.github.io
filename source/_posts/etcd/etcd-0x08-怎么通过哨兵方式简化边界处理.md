---
title: etcd-0x08-怎么通过哨兵方式简化边界处理
category_bar: true
date: 2025-06-11 14:18:58
categories: etcd
---

在启动过程中看到这个方法，{% post_link etcd/etcd-0x04-WAL技术 %}说明在这一章看漏掉了一点东西，再回过头看下怎么初始化的数据，保证初始状态也有一条数据。这也是为什么在raft中所有的脚标都是1-based。

```go
func (ms *MemoryStorage) lastIndex() uint64 {
	// 能直接用脚标直接索引 说明虽然系统刚启动 但是在MemoryStorage#ents中已经有了数据 说明raft做了边界处理 为了省去判空和数组越界 它初始化了哨兵数据
	return ms.ents[0].Index + uint64(len(ms.ents)) - 1
}
```

```go
// 启动时候尝试恢复内存数据库 包含了两层语义
// 1 用snap快照
// 2 用wal查漏补缺
// 在初始化storage的时候有特殊处理 初始化的时候在Storage#ents中放了一条entry 这个entry的term和index用的int默认值0
func (rc *raftNode) replayWAL() *wal.WAL {
	log.Printf("replaying WAL of member %d", rc.id)
	// 找到用来恢复数据的snap快照 找到的为个snap能恢复的数据是[0...snap#Index] 剩下的数据还得靠wal文件继续回放
	snapshot := rc.loadSnapshot()
	// 找到用来恢复数据的wal文件 wal内容都放在了raftNode#WAL#decoder
	w := rc.openWAL(snapshot)
	_, st, ents, err := w.ReadAll()
	if err != nil {
		log.Fatalf("raftexample: failed to read WAL (%v)", err)
	}
	// 这个地方初始化的时候就会在Storage#ents中放上一条日志 这条日志用的是默认值 term=0 index=0
	// 这样做的目的是 新系统启动时 没有历史数据 放上这一条数据做为哨兵 后面就可以不用考虑为空的场景边界
	rc.raftStorage = raft.NewMemoryStorage()
	if snapshot != nil {
		// 用snap恢复
		rc.raftStorage.ApplySnapshot(*snapshot)
	}
	rc.raftStorage.SetHardState(st)

	// append to storage so raft starts at the right place in log
	// 用wal回放
	rc.raftStorage.Append(ents)

	return w
}
```

```go
func NewMemoryStorage() *MemoryStorage {
	return &MemoryStorage{
		// When starting from scratch populate the list with a dummy entry at term zero.
		// 在用snap和wal恢复数据前 会初始化一个Storage 在初始化的时候就保证了ents不空 避免了新系统没有历史数据还要判空的场景
		ents: make([]pb.Entry, 1),
	}
}
```
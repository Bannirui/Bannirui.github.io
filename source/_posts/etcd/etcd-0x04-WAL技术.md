---
title: etcd-0x04-WAL技术
category_bar: true
date: 2025-06-06 14:20:38
categories: etcd
---

raftexample的数据库是一个内存数据库，在启动时候进行数据恢复也就是写到内存中

```go
// 启动时候尝试恢复内存数据库 包含了两层语义
// 1 用snap快照
// 2 用wal查漏补缺
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

### 1 用snap快照恢复

在raft启动的过程中检测到有snap快照文件后，会尝试用快照文件恢复数据

#### 1.1 首先检测有没有快照文件

很键盘，并不需要真的去找snap文件，间接看wal就行，没有wal目录就判定为没snap

```go
// @Return 用来恢复数据的snap快照
//         没有现成的snapshot文件就初始化一个逻辑snap term=0 index=0
func (rc *raftNode) loadSnapshot() *raftpb.Snapshot {
	// 看看在wal目录下有没有wal文件
	if wal.Exist(rc.waldir) {
		// 从wal日志文件反序列化出来
		walSnaps, err := wal.ValidSnapshotEntries(rc.logger, rc.waldir)
		if err != nil {
			log.Fatalf("raftexample: error listing snapshots (%v)", err)
		}
		// 找到用来恢复数据的快照
		// 这个地方的另一层语义是 如果没有wal目录 必然没有snap 确实 皮之不存毛之焉附
		snapshot, err := rc.snapshotter.LoadNewestAvailable(walSnaps)
		if err != nil && !errors.Is(err, snap.ErrNoSnapshot) {
			log.Fatalf("raftexample: error loading snapshot (%v)", err)
		}
		return snapshot
	}
	// 没有现成的snapshot文件就初始化 term=0 index=0
	return &raftpb.Snapshot{}
}
```

#### 1.2 定位用哪个快照

系统可能存在很多快照，理论上用最新的一个快照文件就行，这个地方做了比较有意思的防御性

```go
// 为什么设计的这么复杂 不直接使用最新的snap文件作为恢复数据的依据呢 而是要跟wal进行比较
// 根本原因是要让wal认可snap 也就是保证恢复的数据一定是在wal中的
// 防止孤儿快照 也就是数据在snap中却不在wal中
// @Param walSnaps default.etcd/member/wal/目录下的wal文件
// @Return snap文件 raft服务器启动的时候用哪个snap文件作为数据恢复的依据
func (s *Snapshotter) LoadNewestAvailable(walSnaps []walpb.Snapshot) (*raftpb.Snapshot, error) {
	return s.loadMatching(func(snapshot *raftpb.Snapshot) bool {
		m := snapshot.Metadata
		for i := len(walSnaps) - 1; i >= 0; i-- {
			if m.Term == walSnaps[i].Term && m.Index == walSnaps[i].Index {
				return true
			}
		}
		return false
	})
}
```

#### 1.3 用snap进行恢复

```go
func (ms *MemoryStorage) ApplySnapshot(snap pb.Snapshot) error {
	ms.Lock()
	defer ms.Unlock()

	//handle check for old snapshot being applied
	msIndex := ms.snapshot.Metadata.Index
	snapIndex := snap.Metadata.Index
	if msIndex >= snapIndex {
		return ErrSnapOutOfDate
	}

	ms.snapshot = snap
	ms.ents = []pb.Entry{{Term: snap.Metadata.Term, Index: snap.Metadata.Index}}
	return nil
}
```

### 2 wal文件

首先wal文件名命名是有设计的

```go
// 生成wal文件名 seq-index.wal 设计成这样的目的是通过文件名可以达成两个效果
// 对seq排序就是对所有记录的排序
// 通过index就可以知道wal文件中记录的index范围 [上一个wal文件名的index...下一个wal文件名的index-1]
// @Param seq 递增序号 0-based 表示wal文件的顺序
// @Param index index号 0-based 表示当前wal文件里面存放的第一个log entry的index是多少 也就是wal文件里面内容从哪个index开始的
func walName(seq, index uint64) string {
	return fmt.Sprintf("%016x-%016x.wal", seq, index)
}
```

#### 2.1 定位用哪些wal文件

```go
// 根据snap的index定位wal文件的目的是找到哪些wal文件内容不在snap中
// 也就是恢复数据靠的是两部分 snap+wal
// 这个地方定位的粒度是wal文件 所以并不是精确定位记录 也不需要
// 不怕文件找多了 就怕找少了
// 也就是说这个地方找到的wal文件 文件中的部分内容可以已经被打在了snap 但是没有关系 用wal回放的时候发现记录已经存在就跳过就行
// @Param names wal文件名 wal的文件名是seq-index.wal 已经按照seq升序排好了 也就是轮询的时候从后往前找wal文件先看新的wal文件 也就是index是大的 方便快速定位到要找的index在哪个wal文件
// @Param index 要找的index
// @Return 要找的log entry的index落在哪个wal文件 返回的是wal文件在slice中的脚标 0-based 没找到返回-1
func searchIndex(lg *zap.Logger, names []string, index uint64) (int, bool) {
	for i := len(names) - 1; i >= 0; i-- {
		name := names[i]
		_, curIndex, err := parseWALName(name)
		if err != nil {
			lg.Panic("failed to parse WAL file name", zap.String("path", name), zap.Error(err))
		}
		if index >= curIndex {
			return i, true
		}
	}
	return -1, false
}
```

#### 2.2 回放wal时候怎么丢弃重复记录

因为wal文件的设计已经保证了记录index的绝对有序，所以当发现内存中第一条记录的index比用来恢复的wal中第一条记录index大，就说明wal找多了，就直接丢弃，从头开始砍，砍到不在内存中的那条记录开始

```go
	if first > entries[0].Index {
		entries = entries[first-entries[0].Index:]
	}
```
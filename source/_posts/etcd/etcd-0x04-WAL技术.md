---
title: etcd-0x04-WAL技术
category_bar: true
date: 2025-06-06 14:20:38
categories: etcd
---

snap是对wal文件的快照，etcd对文件职责进行了分层，db层的数据用快照进行恢复，raft共识层的数据用wal文件进行回放。

### 1 用snap快照恢复db层

在raft启动的过程中检测到有snap快照文件后，会尝试用快照文件恢复数据

#### 1.1 首先检测有没有快照文件

```go
	if haveWAL {
		// db层数据用snap快照文件恢复
		snapshot, be, err = recoverSnapshot(cfg, st, be, beExist, beHooks, ci, ss)
		if err != nil {
			return nil, err
		}
	}
```

#### 1.2 定位用哪个快照

系统可能存在很多快照，理论上用最新的一个快照文件就行，但是etcd这个地方做了比较有意思的防御性

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

#### 1.3 恢复db数据

```go
		// 用snap快照恢复数据
		if err = st.Recovery(snapshot.Data); err != nil {
			cfg.Logger.Panic("failed to recover from snapshot", zap.Error(err))
		}
```
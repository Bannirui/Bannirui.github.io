---
title: etcd-0x03-互斥锁读写文件
category_bar: true
date: 2025-06-06 14:08:20
categories: etcd
---

```go
func (s *kvstore) getSnapshot() ([]byte, error) {
	// 我在raft-py中时考虑过共享文件安全性 etcd用的就是读写锁 保证 读写互斥 读时不写 我以为是COW的方案保证性能呢
	s.mu.RLock()
	defer s.mu.RUnlock()
	// map序列化json
	return json.Marshal(s.kvStore)
}
```
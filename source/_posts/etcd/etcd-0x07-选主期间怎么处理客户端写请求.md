---
title: etcd-0x07-选主期间怎么处理客户端写请求
category_bar: true
date: 2025-06-11 13:31:18
categories: etcd
---

etcd-raft的这个地方还是挺有意思的，也体现出了golang的channel使用技巧

对于一个raft集群

- 无主期间拒绝客户端写请求
- 为了保证集群一致性，整个集群对外接收客户端写请求的有且只能有Leader

上面这两点在raft中是怎么实现控制的呢

### 1 处理客户端写请求

```go
		case pm := <-propc:
			// golang的语法是 propc是nil时 相当于channel不存在 这条case语句就不会被执行
			// 只有当前节点是Leader时propc才会被赋值 否则这个propc就是nill 实现了只有自己Leader才有资格接收客户端写请求
			m := pm.m
			m.From = r.id
			// raft的核心逻辑 所有消息都在这处理
			err := r.Step(m)
			if pm.result != nil {
				pm.result <- err
				close(pm.result)
			}
```

所以只要控制当前节点的内存中变量propc有没有值就行

### 2 控制只有Leader才有propc

```go
		// 这个地方还是挺巧妙的
		// 集群Leader没有变化 也就是说当前这轮的事件循环的Leader还是之前那个 自然也就只有Leader的propc才会被订阅处理 Follower的propc还是空的 也就是说当前集群对外接收客户端写请求的还是之前Leader
		if lead != r.lead {
			// Leader发生了变化 当前集群有Leader就是易主了 当前集群没有Leader就是降级重新选举了
			if r.hasLeader() {
				if lead == None {
					r.logger.Infof("raft.node: %x elected leader %x at term %d", r.id, r.lead, r.Term)
				} else {
					r.logger.Infof("raft.node: %x changed leader from %x to %x at term %d", r.id, lead, r.lead, r.Term)
				}
				// 现在集群有主 Leader是不是自己决定当前节点有没有权处理客户端写请求 怎么保证这个机制
				// 当前是Leader 自己的propc就不是nil 下面自然可以订阅到数据
				// 当前不是Leader 自己的propc是nil 下面case就会被跳过不执行了
				// 也就达到了只有Leader才有权处理客户端写请求
				propc = n.propc
			} else {
				r.logger.Infof("raft.node: %x lost leader %x at term %d", r.id, lead, r.Term)
				// 无主状态 集群的中间态 对外拒绝写服务
				propc = nil
			}
			lead = r.lead
		}
```
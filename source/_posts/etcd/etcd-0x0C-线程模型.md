---
title: etcd-0x0C-线程模型
category_bar: true
date: 2025-06-12 14:22:09
categories: etcd
---

虽然raft的核心逻辑执行单位仅仅是golang的一个协程，但还是用线程模型比较合适通用。

用多路复用方式实现了事件循环这样的一个线程模型。

整个raft的所有流程都在`node.go`文件的`run`方法中

```go
// raft的线程模型 多路复用事件循环就体现在这
func (n *node) run() {
	// 都只声明 没有定义 赋值逻辑放在一些if条件里面 目的就是为了让select在channel为空的时候跳过
	var propc chan msgWithResult
	var readyc chan Ready
	var advancec chan struct{}
	var rd Ready

	r := n.rn.raft
	// raft节点id 1-based 在每个节点内存中维护上一次感知到的Leader是谁 什么叫上一次 下面要进入线程的事件循环 所以在每一轮都看看Leader是不是发生了变化
	// Leader发生变化无非就两种情况
	// 1 有Leader->没有Leader
	// 2 没有Leader->有Leader
	lead := None

	for {
		// 在心跳超时后Follower会给msgs和msgsAfterAppend这两个集合放在数据 msgs放的是要给集群其他节点发送的拉票请求 msgsAfterAppend放的是模拟自己给自己的投票响应
		// advancec的用途是什么 在不是异步存储的场景 默认就是同步方式 怎么保证相间的顺序是同步的呢 就是靠这个通信 raft把ready清单告诉etcd后就把advancec赋值 上层处理完后通过advancec告诉raft 再上层通知处理完之前raft不再向上层发送ready清单
		if advancec == nil && n.rn.HasReady() {
			// Populate a Ready. Note that this Ready is not guaranteed to
			// actually be handled. We will arm readyc, but there's no guarantee
			// that we will actually send on it. It's possible that we will
			// service another channel instead, loop around, and then populate
			// the Ready again. We could instead force the previous Ready to be
			// handled first, but it's generally good to emit larger Readys plus
			// it simplifies testing (by emitting less frequently and more
			// predictably).
			// ready清单
			rd = n.rn.readyWithoutAccept()
			readyc = n.readyc
		}

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

		select {
		// TODO: maybe buffer the config propose if there exists one (the way
		// described in raft dissertation)
		// Currently it is dropped in Step silently.
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
		case m := <-n.recvc:
			// 接收来自其他节点的raft消息
			if IsResponseMsg(m.Type) && !IsLocalMsgTarget(m.From) && r.trk.Progress[m.From] == nil {
				// Filter out response message from unknown From.
				break
			}
			r.Step(m)
		case cc := <-n.confc:
			// 配置变更请求 比如添加节点
			_, okBefore := r.trk.Progress[r.id]
			cs := r.applyConfChange(cc)
			// If the node was removed, block incoming proposals. Note that we
			// only do this if the node was in the config before. Nodes may be
			// a member of the group without knowing this (when they're catching
			// up on the log and don't have the latest config) and we don't want
			// to block the proposal channel in that case.
			//
			// NB: propc is reset when the leader changes, which, if we learn
			// about it, sort of implies that we got readded, maybe? This isn't
			// very sound and likely has bugs.
			if _, okAfter := r.trk.Progress[r.id]; okBefore && !okAfter {
				var found bool
				for _, sl := range [][]uint64{cs.Voters, cs.VotersOutgoing} {
					for _, id := range sl {
						if id == r.id {
							found = true
							break
						}
					}
					if found {
						break
					}
				}
				if !found {
					propc = nil
				}
			}
			select {
			case n.confstatec <- cs:
			case <-n.done:
			}
		case <-n.tickc:
			// 定时触发 驱动心跳和选举
			n.rn.Tick()
		case readyc <- rd: // 把ready清单通过readyc通知给上层
			// Ready是Raft给上层etcd的一份任务清单 包括 要写入WAL的entry 要发送给其他节点的消息 要apply到状态机的entry
			// 写完WAL\发送消息\apply后 要等advancec通知继续
			// 标记这一轮的ready清单已经被接收 仅仅是标记 我已经把ready清单交给上层了
			n.rn.acceptReady(rd)
			if !n.rn.asyncStorageWrites {
				// 没有启用异步存储的情况意味着 我需要等上层处理完Ready清单(WAL写入+网络发送+状态应用)之后 再通过advancec回调通知我继续推进状态
				advancec = n.advancec
			} else {
				rd = Ready{}
			}
			readyc = nil
		case <-advancec:
			// 通知raft释放旧的ready Raft会清理掉unstable中的已持久化entry 更新applied指针 没有这个步骤 Raft无法前进 防止数据丢失
			n.rn.Advance(rd)
			rd = Ready{}
			advancec = nil
		case c := <-n.status:
			c <- getStatus(r)
		case <-n.stop:
			close(n.done)
			return
		}
	}
}
```
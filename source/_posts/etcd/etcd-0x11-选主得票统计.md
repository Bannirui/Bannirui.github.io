---
title: etcd-0x11-选主得票统计
category_bar: true
date: 2025-06-20 16:23:54
categories: etcd
---

### 1 缓存投票箱

```go
// 记录投票结果 只负责记录投票 不在乎投票的人是不是集群一员
// @Param id 发起投票的raft节点
// @Param v id对我竞选Leader的投票结果 True是赞成 False是反对
func (p *ProgressTracker) RecordVote(id uint64, v bool) {
	// 看看投票箱有没有投票记录
	_, ok := p.Votes[id]
	if !ok {
		// 一个选举生命周期只统计别人对自己的一次投票
		p.Votes[id] = v
	}
}
```

### 2 统计投票

```go
// 统计投票箱 过半投自己赞成票就说明自己有资格成为Leader了
// @Param votes 投票箱
func (c MajorityConfig) VoteResult(votes map[uint64]bool) VoteResult {
	if len(c) == 0 {
		// By convention, the elections on an empty config win. This comes in
		// handy with joint quorums because it'll make a half-populated joint
		// quorum behave like a majority quorum.
		return VoteWon
	}

	var votedCnt int //vote counts for yes.
	var missing int
	// 轮询集群中节点id
	for id := range c {
		// 从投票箱中找节点id的投票
		v, ok := votes[id]
		if !ok {
			// 还没投票的节点数量 可能人家还没发起投票 也可能投票结果还在路上
			missing++
			continue
		}
		if v {
			// 投了赞成票
			votedCnt++
		}
	}
	// 集群半数节点数量是多少
	q := len(c)/2 + 1
	// 对自己投赞成票的过半
	if votedCnt >= q {
		return VoteWon
	}
	if votedCnt+missing >= q {
		return VotePending
	}
	return VoteLost
}
```

### 3 竞选结果

```go
// @Return granted 赞成票几票
// @Return rejected 反对票几票
// @Return VoteResult 竞选得票结果 3-Candidate竞选成功可以当Leader
func (p *ProgressTracker) TallyVotes() (granted int, rejected int, _ quorum.VoteResult) {
	// Make sure to populate granted/rejected correctly even if the Votes slice
	// contains members no longer part of the configuration. This doesn't really
	// matter in the way the numbers are used (they're informational), but might
	// as well get it right.
	for id, pr := range p.Progress {
		if pr.IsLearner {
			continue
		}
		// 投票箱看看谁投了赞成票谁投了反对票
		v, voted := p.Votes[id]
		if !voted {
			// 投票的人不是集群一员 不要计票
			continue
		}
		if v {
			// 赞成票数
			granted++
		} else {
			// 反对票数
			rejected++
		}
	}
	// 竞选结果
	result := p.Voters.VoteResult(p.Votes)
	return granted, rejected, result
}
```
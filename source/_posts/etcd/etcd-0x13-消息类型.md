---
title: etcd-0x13-消息类型
category_bar: true
date: 2025-06-12 15:08:52
categories: etcd
---

raft对所有场景的通信消息都封装了一层

### 1 核心消息

| 消息类型         | 含义              | 应用角色         | 说明             |
| ---------------- | ----------------- | ---------------- | ---------------- |
| MsgApp           | AppendEntries RPC | Leader->Follower | 日志复制         |
| MsgAppResp       | AppendEntries响应 | Follower->Leader | 告知是否接受日志 |
| MsgHeartbeat     | 心跳              | Leader->Follower | 保持领导地位     |
| MsgHeartbeatResp | 心跳响应          | Follower->Leader | 保活响应         |

### 2 选举相关

| 消息类型       | 含义                  | 应用角色         | 说明                |
| -------------- | --------------------- | ---------------- | ------------------- |
| MsgHup         | 发起选举              | Local节点        | 自我提升为Candidate |
| MsgVote        | 请求投票              | Candidate->Peer  | 请求成为Leader      |
| MsgVoteResp    | 投票回应              | Peer->Candidate  | 表达支持或拒绝      |
| MsgPreVote     | 预选投票              | Follower->Peer   | 先测试选举是否可能  |
| MsgPreVoteResp | 预选投票响应          | Peer->Follower   | 是否同意候选资格    |
| MsgTimeoutNow  | 立即发起选举 转移领导 | Leader->Follower | 由Leader主动交权    |

### 3 提议/应用

| 消息类型         | 含义              | 应用角色 | 说明                         |
| ---------------- | ----------------- | -------- | ---------------------------- |
| MsgProp          | 客户端提议新entry |          | Leader会收到并尝试复制日志   |
| MsgReadIndex     | 请求读一致性索引  |          | etcd Linearizable Read       |
| MsgReadIndexResp | 返回读一致性索引  |          | Leader回复follower的读取请求 |

### 4 存储

| 消息类型             | 含义                     | 应用角色 | 说明                  |
| -------------------- | ------------------------ | -------- | --------------------- |
| MsgStorageAppend     | 请求写WAL                |          | leader/follower->存储 |
| MsgStorageAppendResp | WAL写入完成              |          | 存储组件->raft        |
| MsgStorageApply      | 请求apply到状态机        |          | raft->应用层          |
| MsgStorageApplyResp  | 应用完成 推进applied指针 |          | 应用层->raft          |

### 5 快照

| 消息类型      | 含义         | 应用角色         | 说明 |
| ------------- | ------------ | ---------------- | ---- |
| MsgSnap       | 快照发送     | Leader->Follower |      |
| MsgSnapStatus | 快照是否成功 | Follower->Leader |      |

### 6 其他

| 消息类型          | 含义             | 应用角色 | 说明                            |
| ----------------- | ---------------- | -------- | ------------------------------- |
| MsgCheckQuorum    | leader检查quorum |          | 心跳或ReadIndex期间检查是否失联 |
| MsgTransferLeader | 请求转移Leader   |          | 客户端或 peer主动请求换Leader   |
| MsgUnreachable    | 表示某节点失联   |          | peer unreachable被传递到leader  |
| MsgForgetLeader   | 忘记leader       |          | 主要用于测试 强制节点认为无主   |

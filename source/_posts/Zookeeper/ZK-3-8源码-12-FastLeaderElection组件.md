---
title: ZK@3.8源码-12-FastLeaderElection组件
date: 2023-03-09 10:53:41
category_bar: true
tags: ZK@3.8
categories: ZooKeeper源码
---

前文已经分析过{% post_link Zookeeper/ZK-3-8源码-11-QuorumCnxManager组件 QuorumCnxManger %}组件关注的是选主投票的网络通信，现在FastLeaderElection组件关注的投票数据。

## 1 组件示意图

该图仅仅是在集群模式启动之初，组件初始化后的实例，还不涉及工作状态和工作流程。

下面跟着源码进行分析组件如何工作的以及数据交互流程是什么。

![](ZK-3-8源码-12-FastLeaderElection组件/image-20230309160038774.png)

## 2 线程启动入口

调度起来Messenger中WorkerSender和WorkerReceiver开始工作。

```java
/**
                 * 启动messenger中的两个线程
                 *   - ws
                 *   - wr
                 */
fle.start(); // 启动选举
```



```java
public void start() {
    /**
         * 启动messenger中的两个线程
         *   - wsThread发送线程 负责执行ws发送任务
         *   - wrThread接收线程 负责执行wr接收任务
         * 这两个线程是使用QuorumCnxManager网络通信处理网络IO数据包的
         */
    this.messenger.start();
}
```



```java
void start() {
    /**
             * 启动两个线程
             *   - wsThread发送线程 负责执行ws发送任务
             *   - wrThread接收线程 负责执行wr接收任务
             */
    this.wsThread.start();
    this.wrThread.start();
}
```



```java
Messenger(QuorumCnxManager manager) {

    this.ws = new WorkerSender(manager);

    /**
             * 线程
             * 该线程被CPU调度起来后会执行ws这个任务
             */
    this.wsThread = new Thread(this.ws, "WorkerSender[myid=" + self.getId() + "]");
    this.wsThread.setDaemon(true);

    this.wr = new WorkerReceiver(manager);

    /**
             * 线程
             * 该线程被CPU调度起来后会执行wr这个任务
             */
    this.wrThread = new Thread(this.wr, "WorkerReceiver[myid=" + self.getId() + "]");
    this.wrThread.setDaemon(true);
}
```

## 3 选主启动入口

lookForLeader()方法。

```java
public Vote lookForLeader() throws InterruptedException {
    try {
        self.jmxLeaderElectionBean = new LeaderElectionBean();
        MBeanRegistry.getInstance().register(self.jmxLeaderElectionBean, self.jmxLocalPeerBean);
    } catch (Exception e) {
        LOG.warn("Failed to register with JMX", e);
        self.jmxLeaderElectionBean = null;
    }

    self.start_fle = Time.currentElapsedTime();
    try {
        /*
             * The votes from the current leader election are stored in recvset. In other words, a vote v is in recvset
             * if v.electionEpoch == logicalclock. The current participant uses recvset to deduce on whether a majority
             * of participants has voted for it.
             */
        // 存储当前选举接收到的票据
        Map<Long, Vote> recvset = new HashMap<Long, Vote>();

        /*
             * The votes from previous leader elections, as well as the votes from the current leader election are
             * stored in outofelection. Note that notifications in a LOOKING state are not stored in outofelection.
             * Only FOLLOWING or LEADING notifications are stored in outofelection. The current participant could use
             * outofelection to learn which participant is the leader if it arrives late (i.e., higher logicalclock than
             * the electionEpoch of the received notifications) in a leader election.
             */
        // 存储上次选举的票据
        Map<Long, Vote> outofelection = new HashMap<Long, Vote>();

        int notTimeout = minNotificationInterval;

        synchronized (this) {
            // 逻辑时钟自增 用来判断票据是否在同一轮选举
            logicalclock.incrementAndGet();
            /**
                 * 选举谁当leader
                 * 选自己当leader
                 * 就是把被推荐当leader的信息记在FLE算法中
                 */
            updateProposal(getInitId(), getInitLastLoggedZxid(), getPeerEpoch());
        }

        // 当票据发生变更就异步发送通知告知所有竞选节点
        sendNotifications();

        SyncedLearnerTracker voteSet = null;

        /*
             * Loop in which we exchange notifications until we find a leader
             */

        while ((self.getPeerState() == ServerState.LOOKING) && (!stop)) { // 直至竞选出Leader才选结束选举 一旦选主成功那么曾经参与选主的节点要么是Leader要么是Follower 状态不可能再是LOOKING
            /*
                 * Remove next notification from queue, times out after 2 times
                 * the termination time
                 */
            /**
                 * FLE算法收到的投票
                 *   - 自己投自己的那一票
                 *   - 别的节点的投票(投谁不知道)
                 */
            Notification n = recvqueue.poll(notTimeout, TimeUnit.MILLISECONDS);

            /*
                 * Sends more notifications if haven't received enough.
                 * Otherwise processes new notification.
                 */
            if (n == null) { // FLE投票箱没有投票
                if (manager.haveDelivered()) { // 当前节点没有待发送投票
                    sendNotifications(); // 再次向节点发送一下自己的投票(自己投自己当Leader)
                } else {
                    manager.connectAll(); // 尝试和每个节点建立连接
                }

                /*
                     * Exponential backoff
                     */
                notTimeout = Math.min(notTimeout << 1, maxNotificationInterval);

                /*
                     * When a leader failure happens on a master, the backup will be supposed to receive the honour from
                     * Oracle and become a leader, but the honour is likely to be delay. We do a re-check once timeout happens
                     *
                     * The leader election algorithm does not provide the ability of electing a leader from a single instance
                     * which is in a configuration of 2 instances.
                     * */
                if (self.getQuorumVerifier() instanceof QuorumOracleMaj
                    && self.getQuorumVerifier().revalidateVoteset(voteSet, notTimeout != minNotificationInterval)) {
                    setPeerState(proposedLeader, voteSet);
                    Vote endVote = new Vote(proposedLeader, proposedZxid, logicalclock.get(), proposedEpoch);
                    leaveInstance(endVote);
                    return endVote;
                }

                LOG.info("Notification time out: {} ms", notTimeout);

            } else if (validVoter(n.sid) && validVoter(n.leader)) {
                /*
                     * Only proceed if the vote comes from a replica in the current or next
                     * voting view for a replica in the current or next voting view.
                     */
                switch (n.state) { // 判断投票者的状态 如果是LOOKING说明也在找Leader
                    case LOOKING: // 发投票的那个节点也在寻主
                        if (getInitLastLoggedZxid() == -1) { // 只要ZKDatabase初始化过zxid的默认值就是0 处理过事务之后这个zxid还是自增 所以-1肯定是异常的
                            LOG.debug("Ignoring notification as our zxid is -1");
                            break;
                        }
                        if (n.zxid == -1) { // 同理ZKDatabase初始化过zxid的默认值就是0 -1异常
                            LOG.debug("Ignoring notification from member with -1 zxid {}", n.sid);
                            break;
                        }
                        // If notification > current, replace and send messages out
                        if (n.electionEpoch > logicalclock.get()) {
                            /**
                             * 发来投票的那个节点的时钟周期比当前节点大 说明当前节点时钟落后了 已经不在一个选举轮次上了
                             * 自己选谁都是没有意义的 发到别人那边的投票直接被丢掉了
                             */
                            logicalclock.set(n.electionEpoch); // 先更新自己的时钟
                            recvset.clear(); // 清空之前收集的外部投票箱 因为投票箱是在特定时钟周期下的凭证 没有意义了

                            /**
                             * 结合收到的别人在有效时钟周期下的投票
                             * 参考它的推荐
                             * 自己也就有了推荐人
                             * 把自己的推荐消息广播出去
                             */
                            if (totalOrderPredicate(n.leader, n.zxid, n.peerEpoch, getInitId(), getInitLastLoggedZxid(), getPeerEpoch())) {
                                updateProposal(n.leader, n.zxid, n.peerEpoch);
                            } else {
                                updateProposal(getInitId(), getInitLastLoggedZxid(), getPeerEpoch());
                            }
                            sendNotifications();
                        } else if (n.electionEpoch < logicalclock.get()) {
                            /**
                             * 发来投票的那个节点的时钟周期比当前节点小 投票作废
                             * 别人的时钟周期已经落后 选谁都没有意义 结束算法流程
                             */
                            LOG.debug(
                                "Notification election epoch is smaller than logicalclock. n.electionEpoch = 0x{}, logicalclock=0x{}",
                                Long.toHexString(n.electionEpoch),
                                Long.toHexString(logicalclock.get()));
                            break;
                        } else if (totalOrderPredicate(n.leader, n.zxid, n.peerEpoch, proposedLeader, proposedZxid, proposedEpoch)) { // 发投票的节点的时钟周期和自己处在一个轮次 最简单 直接pk它的推举和自己的推举
                            /**
                             * 两个推举进行pk
                             * 无论那个候选人胜出 都更新自己现在的主观推荐
                             * 然后把最新的选择告知集群其他候选人
                             */
                            updateProposal(n.leader, n.zxid, n.peerEpoch);
                            sendNotifications();
                        }

                        LOG.debug(
                            "Adding vote: from={}, proposed leader={}, proposed zxid=0x{}, proposed election epoch=0x{}",
                            n.sid,
                            n.leader,
                            Long.toHexString(n.zxid),
                            Long.toHexString(n.electionEpoch));

                        // don't care about the version if it's in LOOKING state
                        /**
                         * 首先 代码能执行到这说明
                         *   - 外来选票是有效的
                         *   - 这个外来选票包含了自己给自己投的
                         * 把外来的有效的通知转换成投票 放到投票箱recvset中
                         * 也就是把外部投票进行归档
                         * 它的用途是啥呢
                         *   - value是选票 也就是谁可以当leader
                         *   - key是谁投了选票
                         * 那么就可以对投票箱进行汇总得出
                         *   - 哪些人被投为了leader
                         *   - 支持当leader的数量
                         */
                        recvset.put(n.sid, new Vote(n.leader, n.zxid, n.electionEpoch, n.peerEpoch));

                        /**
                         * 下面两个步骤合起来看比较容易理解
                         *   - 首先 在当前FLE算法中维护的LEADER候选人信息就是最后可能当leader的人
                         *     - proposedLeader
                         *     - proposedZxid
                         *     - proposedEpoch
                         *     因为上次网络有通知消息进来都会比较pk 将pk胜出的更新为最新的这几个阈值 然后才会再将投票归档
                         *     也就是说所有的投票中如果真的已经可以结算出leader 那么也只有可能是现在算法维护的proposedLeader
                         *   - 有了这个共识之后 事情就变得简单了
                         *     - 因为已经有了leader的得力候选人
                         *     - 拿着投票归档箱去看都有哪些人投了proposedLeader为leader的 把他们记下来
                         *     - 投了proposedLeader的人数超过了集群中参与选主人数一半就结算出leader了
                         */
                        voteSet = getVoteTracker(recvset, new Vote(proposedLeader, proposedZxid, logicalclock.get(), proposedEpoch)); // 从投票归档箱中统计还有谁投了leader得力候选人
                        if (voteSet.hasAllQuorums()) {
                            /**
                             * 集群中参与选主有过半人都投proposedLeader当leader了 选主初步完成了
                             * 此时leader已经决胜出来了
                             *
                             * 下面超时方式看看有没有投票进来
                             *
                             * 有一种场景就是比如集群共3个记点 依次启动1 2 3
                             * 先启动1 再1启动2 就已经可以判定2为leader了
                             * 此刻3再启动
                             * 这个场景就可以触发下面的这种情况
                             */

                            // Verify if there is any change in the proposed leader
                            while ((n = recvqueue.poll(finalizeWait, TimeUnit.MILLISECONDS)) != null) { // 看看还有没有投票
                                if (totalOrderPredicate(n.leader, n.zxid, n.peerEpoch, proposedLeader, proposedZxid, proposedEpoch)) {
                                    recvqueue.put(n);
                                    break;
                                }
                            }

                            /*
                             * This predicate is true once we don't read any new
                             * relevant message from the reception queue
                             */
                            // 200ms内没有新的投票 结束投票
                            if (n == null) {
                                /**
                                 * proposedLeader就是集群leader
                                 * 更新节点的状态
                                 *   - Leader是自己 就直接更新
                                 *   - 自己不是Leader就根据节点特性更新为Follower或者Observer
                                 */
                                setPeerState(proposedLeader, voteSet);
                                // 最终的投票
                                Vote endVote = new Vote(proposedLeader, proposedZxid, logicalclock.get(), proposedEpoch);
                                // 当前投票阶段已经绝胜出leader 投票归档箱已经没有用了 清空它
                                leaveInstance(endVote);
                                return endVote;
                            }
                        }
                        break;
                    case OBSERVING:
                        LOG.debug("Notification from observer: {}", n.sid);
                        break;

                        /*
                        * In ZOOKEEPER-3922, we separate the behaviors of FOLLOWING and LEADING.
                        * To avoid the duplication of codes, we create a method called followingBehavior which was used to
                        * shared by FOLLOWING and LEADING. This method returns a Vote. When the returned Vote is null, it follows
                        * the original idea to break swtich statement; otherwise, a valid returned Vote indicates, a leader
                        * is generated.
                        *
                        * The reason why we need to separate these behaviors is to make the algorithm runnable for 2-node
                        * setting. An extra condition for generating leader is needed. Due to the majority rule, only when
                        * there is a majority in the voteset, a leader will be generated. However, in a configuration of 2 nodes,
                        * the number to achieve the majority remains 2, which means a recovered node cannot generate a leader which is
                        * the existed leader. Therefore, we need the Oracle to kick in this situation. In a two-node configuration, the Oracle
                        * only grants the permission to maintain the progress to one node. The oracle either grants the permission to the
                        * remained node and makes it a new leader when there is a faulty machine, which is the case to maintain the progress.
                        * Otherwise, the oracle does not grant the permission to the remained node, which further causes a service down.
                        *
                        * In the former case, when a failed server recovers and participate in the leader election, it would not locate a
                        * new leader because there does not exist a majority in the voteset. It fails on the containAllQuorum() infinitely due to
                        * two facts. First one is the fact that it does do not have a majority in the voteset. The other fact is the fact that
                        * the oracle would not give the permission since the oracle already gave the permission to the existed leader, the healthy machine.
                        * Logically, when the oracle replies with negative, it implies the existed leader which is LEADING notification comes from is a valid leader.
                        * To threat this negative replies as a permission to generate the leader is the purpose to separate these two behaviors.
                        *
                        *
                        * */
                    case FOLLOWING:
                        /*
                        * To avoid duplicate codes
                        * */
                        Vote resultFN = receivedFollowingNotification(recvset, outofelection, voteSet, n);
                        if (resultFN == null) {
                            break;
                        } else {
                            return resultFN;
                        }
                    case LEADING: // 收到的票据显示那个节点状态已经是LEADING了
                        /*
                        * In leadingBehavior(), it performs followingBehvior() first. When followingBehavior() returns
                        * a null pointer, ask Oracle whether to follow this leader.
                        * */
                        Vote resultLN = receivedLeadingNotification(recvset, outofelection, voteSet, n);
                        if (resultLN == null) {
                            break;
                        } else {
                            return resultLN;
                        }
                    default:
                        LOG.warn("Notification state unrecognized: {} (n.state), {}(n.sid)", n.state, n.sid);
                        break;
                }
            } else {
                if (!validVoter(n.leader)) {
                    LOG.warn("Ignoring notification for non-cluster member sid {} from sid {}", n.leader, n.sid);
                }
                if (!validVoter(n.sid)) {
                    LOG.warn("Ignoring notification for sid {} from non-quorum member sid {}", n.leader, n.sid);
                }
            }
        }
        return null;
    } finally {
        try {
            if (self.jmxLeaderElectionBean != null) {
                MBeanRegistry.getInstance().unregister(self.jmxLeaderElectionBean);
            }
        } catch (Exception e) {
            LOG.warn("Failed to unregister with JMX", e);
        }
        self.jmxLeaderElectionBean = null;
        LOG.debug("Number of connection processing threads: {}", manager.getConnectionThreadCount());
    }
}

```


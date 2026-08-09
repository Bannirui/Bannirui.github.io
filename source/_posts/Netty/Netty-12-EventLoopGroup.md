---
title: Netty-12-EventLoopGroup
category_bar: true
categories: Netty
date: 2026-08-09 00:13:54
---

## 1 构造

```java
    /**
     * EventLoopGroup的语义是线程池 它的职责是管理一堆EventLoop线程 所以它本质是有多个线程
     *   - executor任务执行器 将来负责处理任务 提交到NioEventLoop的立即任务\缓存在taskQueue中的任务
     *   - children数组 缓存的是NioEventLoop实例
     *   - chooser 线程选择器 将来有事件达到NioEventLoopGroup后 通过线程选择器委派给某一个具体的NioEventLoop实例 达到负载均衡的效果
     * @param nThreads group中有多少个EventLoop 线程池有多少个线程
     * @param executor null
     * @param chooserFactory 线程选择器 有任务执行的时候作为线程池怎么从一堆线程中选择一个线程 从NioEventLoopGroup的children数组中选择一个NioEventLoop实例 DefaultEventExecutorChooserFactory.INSTANCE
     * @param args 3个元素
     *             - SelectorProvider.provider() 构造selector实例
     *             - DefaultSelectStrategyFactory.INSTANCE selector的select策略
     *             - RejectedExecutionHandlers.reject() 任务队列的的拒绝策略
     */
    protected MultithreadEventExecutorGroup(int nThreads,
                                            Executor executor,
                                            EventExecutorChooserFactory chooserFactory,
                                            Object... args
    ) {
        /**
         * 因为将来的任务是存放在NioEventLoop的taskQueue中的
         * Netty的事件模型就是以NioEventLoop组合的线程进行驱动的
         * 所以任务的执行需要依赖任务执行器 守护线程(main线程退出可以继续执行)
         * 构造一个executor线程执行器 一个任务对应一个线程(线程:任务=1:n)
         */
        if (executor == null)
            executor = new ThreadPerTaskExecutor(this.newDefaultThreadFactory());

        /**
         * 构建NioEventLoop数组
         * NioEventLoop children数组 线程池中的线程数组
         */
        this.children = new EventExecutor[nThreads];

        /**
         * 轮询NioEventLoop数组 让NioEventLoopGroup组件去创建NioEventLoop实例
         * 根据NioEventLoopGroup构造器指定的数量创建NioEventLoop 也就是指定数量的线程数(线程的创建动作延迟到任务提交时)
         */
        for (int i = 0; i < nThreads; i ++) {
            boolean success = false;
            try {
                /**
                 * 初始化NioEventLoop事件循环器集合 也就是多个线程
                 * 让NioEventLoopGroup组件去创建NioEventLoop实例
                 * args
                 *   - SelectorProvider selector实例
                 *   - SelectStrategyFactory selector的select策略
                 *   - RejectedExecutionHandlers selector的拒绝策略
                 */
                children[i] = this.newChild(executor, args);
                success = true;
            } catch (Exception e) {
                // TODO: Think about if this is a good exception type
                throw new IllegalStateException("failed to create a child event loop", e);
            } finally {
                if (!success) {
                    for (int j = 0; j < i; j ++) { // 但凡有一个child实例化失败 就把已经成功实例化的线程进行shutdown shutdown是异步操作
                        children[j].shutdownGracefully();
                    }

                    for (int j = 0; j < i; j ++) {
                        EventExecutor e = children[j];
                        try {
                            while (!e.isTerminated()) {
                                e.awaitTermination(Integer.MAX_VALUE, TimeUnit.SECONDS);
                            }
                        } catch (InterruptedException interrupted) {
                            // Let the caller handle the interruption.
                            Thread.currentThread().interrupt(); // 把中断状态设置回去 交给关心的线程来处理
                            break;
                        }
                    }
                }
            }
        }

        /**
         * 创建线程选择器 线程选择策略
         * NioEventLoopGroup都绑定一个chooser对象 作为线程选择器 通过这个线程选择器
         * 从children数组中给客户端负载均衡出一个NioEventLoop实例
         * 为每一个channel发生的读写IO分配不同的线程进行处理
         */
        this.chooser = chooserFactory.newChooser(children);

        final FutureListener<Object> terminationListener = new FutureListener<Object>() { // 设置一个listener用来监听线程池中的termination事件 给线程池中的每一个线程都设置这个listener 当监听到所有线程都terminate以后 这个线程池就算真正的terminate了
            @Override
            public void operationComplete(Future<Object> future) throws Exception {
                if (terminatedChildren.incrementAndGet() == children.length)
                    terminationFuture.setSuccess(null);
            }
        };

        for (EventExecutor e: children)
            e.terminationFuture().addListener(terminationListener);

        Set<EventExecutor> childrenSet = new LinkedHashSet<EventExecutor>(children.length);
        Collections.addAll(childrenSet, children);
        // 只读集合
        readonlyChildren = Collections.unmodifiableSet(childrenSet);
    }
```

从上面名字就可以猜出来一定有个SingleThreadEventLoop抽象了NioEventLoop的

## 2 提交任务

在任务提交这件事情上，NioEventLoopGroup不进行实质性的流程处理，真正干活的是NioEventLoop这个组件。

```java
    @Override
    public Future<?> submit(Runnable task) {
        return this.next().submit(task);
    }
```

{%post_link Netty/Netty-11-EventLoop%}
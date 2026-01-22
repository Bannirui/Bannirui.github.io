---
title: Netty-0x04-NioEventLoopGroup和NioEventLoop详细初始化过程
date: 2023-05-15 23:09:42
category_bar: true
tags: [ 2刷Netty ]
categories: [ Netty ]
---

### 1 NioEventLoopGroup

```java
    /**
     * @param nThreads
     *   - server端
     *     - bossGroup->1
     *     - workerGroup
     *   - client端
     */
    public NioEventLoopGroup(int nThreads) {
        this(nThreads, (Executor) null);
    }
```



```java
    /**
     *
     * @param nThreads
     *   - server端
     *     - bossGroup->1
     *     - workerGroup
     *   - client端
     * @param executor
     *  - server端
     *    - bossGroup->null
     *    - workerGroup
     *  - client端
     */
    public NioEventLoopGroup(int nThreads, Executor executor) {
        /**
         * executor用于开启NioEventLoop线程所需要的线程执行器
         * SelectorProvider.provider()用于创建selector 屏蔽了OS平台差异 做到了跨平台特性
         * 多路复用器是跟OS平台强相关的 不同平台有不同实现
         *   - freebsd\macosx->kqueue
         *   - linux->epoll
         *   - windows->poll
         *   - ...
         */
        this(nThreads, executor, SelectorProvider.provider());
    }
```



```java
    public NioEventLoopGroup(int nThreads, Executor executor, final SelectorProvider selectorProvider) {
        this(nThreads, executor, selectorProvider, DefaultSelectStrategyFactory.INSTANCE);
    }
```



```java
    /**
     *
     * @param nThreads
     *   - server
     *     - bossGroup->1
     *     - workerGroup
     *   - client
     * @param executor->null
     * @param selectorProvider->SelectorProvider.provider()
     * @param selectStrategyFactory->DefaultSelectStrategyFactory.INSTANCE
     */
    public NioEventLoopGroup(int nThreads,
                             Executor executor, // null
                             final SelectorProvider selectorProvider, // 创建Java的NIO复用器的实现
                             final SelectStrategyFactory selectStrategyFactory // select策略 在Netty中NioEventLoop这个工作线程需要关注的事件包括了IO任务和普通任务 将来线程会阻塞在Selector多路复用器上 执行一次select调用怎么筛选IO任务普通任务
    ) {
        /**
         * RejectedExecutionHandlers.reject()提供了拒绝策略
         */
        super(nThreads, executor, selectorProvider, selectStrategyFactory, RejectedExecutionHandlers.reject());
    }
```



```java
    /**
     *
     * @param nThreads
     *   - server
     *     - bossGroup->1
     *     - workerGroup
     *   - client
     * @param executor->null
     * @param args 3个元素
     *             - SelectorProvider.provider()
     *             - DefaultSelectStrategyFactory.INSTANCE
     *             - RejectedExecutionHandlers.reject()
     */
    protected MultithreadEventLoopGroup(int nThreads,
                                        Executor executor, // null
                                        Object... args // [SelectorProvider SelectStrategyFactory RejectedExecutionHandlers]
    ) {
        super(nThreads == 0 ? DEFAULT_EVENT_LOOP_THREADS : nThreads, executor, args);
    }
```



```java
    /**
     *
     * @param nThreads
     *   - server
     *     - bossGroup->1
     *     - workerGroup
     *   - client
     * @param executor->null
     * @param args 3个元素
     *             - SelectorProvider.provider()
     *             - DefaultSelectStrategyFactory.INSTANCE
     *             - RejectedExecutionHandlers.reject()
     */
    protected MultithreadEventExecutorGroup(int nThreads,
                                            Executor executor, // null
                                            Object... args // [SelectorProvider SelectStrategyFactory RejectedExecutionHandlers]
    ) {
        this(nThreads, executor, DefaultEventExecutorChooserFactory.INSTANCE, args);
    }
```



```java
    /**
     * 初始化
     *   - executor任务执行器 将来负责处理任务 提交到NioEventLoop的立即任务\缓存在taskQueue中的任务
     *   - children数组 缓存的是NioEventLoop实例
     *   - chooser 线程选择器 将来有事件达到NioEventLoopGroup后 通过线程选择器委派给某一个具体的NioEventLoop实例 达到负载均衡的效果
     * @param nThreads
     *   - server
     *     - bossGroup->1
     *     - workerGroup
     *   - client
     * @param executor->null
     * @param chooserFactory 线程选择器 从NioEventLoopGroup的children数组中选择一个NioEventLoop实例
     *   - DefaultEventExecutorChooserFactory.INSTANCE
     * @param args 3个元素
     *             - SelectorProvider.provider()
     *             - DefaultSelectStrategyFactory.INSTANCE
     *             - RejectedExecutionHandlers.reject()
     */
    protected MultithreadEventExecutorGroup(int nThreads, // 标识着group中有几个EventLoop
                                            Executor executor, // null
                                            EventExecutorChooserFactory chooserFactory, // DefaultEventExecutorChooserFactory.INSTANCE
                                            Object... args // [SelectorProvider SelectStrategyFactory RejectedExecutionHandlers]
    ) {
        /**
         * 因为将来的任务是存放在NioEventLoop的taskQueue中的
         * Netty的事件模型就是以NioEventLoop组合的线程进行驱动的
         * 所以任务的执行需要依赖任务执行器
         */
        if (executor == null) // 线程执行器 非守护线程(main线程退出可以继续执行)
            executor = new ThreadPerTaskExecutor(this.newDefaultThreadFactory()); // 构造一个executor线程执行器 一个任务对应一个线程(线程:任务=1:n)

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
                 */
                children[i] = this.newChild(executor, args); // args=[SelectorProvider SelectStrategyFactory RejectedExecutionHandlers]
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
         * 创建线程选择器
         * 线程选择策略
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
        readonlyChildren = Collections.unmodifiableSet(childrenSet); // 只读集合
    }
```

一般而言，bossGroup和workerGroup的区别在于nThreads的指定

* bossGroup手动显式指定1

* workerGroup交给Netty进行推断，DEFAULT_EVENT_LOOP_THREADS

  ```java
  DEFAULT_EVENT_LOOP_THREADS = Math.max(1, SystemPropertyUtil.getInt("io.netty.eventLoopThreads", NettyRuntime.availableProcessors() * 2));
  ```

### 2 公共成员\方法\组件

#### 2.1 {% post_link java/java源码-0x0F-Selector SelectorProvider %}

SelectorProvider是java提供的类，屏蔽了OS的平台差异，对于我们用户而言，可以将其当成黑盒直接使用。

SelectorProvider::provider提供了一个多路复用器的具体实现。

##### 2.1.1 提供器

```java
    /**
     * 提供给客户端一个SelectorProvider实例 将来用于创建Selector
     * 因为Slector本身是跨平台的 所以SelectorProvider跟它是配套的 也是跨平台的
     *   - macosx
     *     - select
     *     - poll
     *     - kqueue
     */
    public static SelectorProvider provider() {
        return Holder.INSTANCE;
    }
```

##### 2.1.2 创建Selector

```java
    public abstract AbstractSelector openSelector()
        throws IOException;
```

![](Netty-0x04-NioEventLoopGroup和NioEventLoop详细初始化过程/image-20230516221538606.png)

#### 2.2 SelectStrategyFactory

DefaultSelectStrategyFactory.INSTANCE

select策略，在Netty中NioEventLoop这个工作线程需要关注的事件包括了IO任务和普通任务，将来线程会阻塞在Selector多路复用器上，执行一次select调用怎么筛选IO任务普通任务。

```java
    /**
     * 函数编程
     * selectSupplier回调接口
     *     - 在NioEventLoop中是IO多路复用器Selector的非阻塞方式执行select()方法 返回值只有两种情况
     *         - 0值 没有Channel处于IO事件就绪状态
     *         - 正数 IO事件就绪的Channel数量
     * hasTasks
     *     - taskQueue常规任务队列或者tailTasks收尾任务队列不为空就界定为有待执行任务 hasTasks为True
     *
     * 也就是说如果有非IO任务 使用非阻塞方式执行一次复用器的select()操作 尽量多执行一些任务
     * 如果没有非IO任务 就直接准备以阻塞方式执行一次复用器的select()操作
     */
    @Override
    public int calculateStrategy(IntSupplier selectSupplier, boolean hasTasks) throws Exception {
        return hasTasks ? selectSupplier.get() : SelectStrategy.SELECT;
    }
```

#### 2.3 RejectedExecutionHandlers

拒绝策略，taskQueue队列中任务满了直接上抛异常。

```java
    public static RejectedExecutionHandler reject() {
        return REJECT;
    }
```



```java
    private static final RejectedExecutionHandler REJECT = new RejectedExecutionHandler() {
        @Override
        public void rejected(Runnable task, SingleThreadEventExecutor executor) {
            throw new RejectedExecutionException();
        }
    };
```

#### 2.4 EventExecutorChooserFactory

线程选择器，从NioEventLoopGroup的children数组中选择一个NioEventLoop实例，达到负载均衡效果。

```java
    /**
     * 判断val是否是2的幂次方
     * @param val NioEventLoop数组长度
     * @return true标识val是2的幂次方
     *         false标识val不是2的幂次方
     */
    private static boolean isPowerOfTwo(int val) { // 判断是否是2的幂次方
        return (val & -val) == val;
    }
```



```java
    /**
     * 策略模式
     *   - NioEventLoop的线程数是2的倍数 一种线程选择方式
     *   - NioEventLoop的线程数不是2的倍数 一种线程选择方式
     * 本质就是提供了一种轮询方式 让NioEventLoopGroup高效地从children数组中返回一个NioEventLoop实例
     */
    @Override
    public EventExecutorChooser newChooser(EventExecutor[] executors) {
        if (isPowerOfTwo(executors.length)) {
            return new PowerOfTwoEventExecutorChooser(executors); // 线程池的线程数量是2的幂次方采用的选择策略
        } else {
            return new GenericEventExecutorChooser(executors); // 线程池的线程数量不是2的幂次方采用的选择策略
        }
    }
```

##### 2.4.1 PowerOfTwoEventExecutorChooser

```java
        /**
         * next()方法的实现就是选择下一个线程的方法
         * 如果线程数是2的倍数 通过位运算而不是取模 这样效率更高
         */
        @Override
        public EventExecutor next() { // 线程池线程数是2的幂次方 位运算
            return this.executors[idx.getAndIncrement() & this.executors.length - 1];
        }
```

##### 2.4.2 GenericEventExecutorChooser

```java
        /*
         * 线程数不是2的倍数 采用绝对值取模的方式 效率一般
         */
        @Override
        public EventExecutor next() { // 线程池线程数量不是2的幂次方 采用取模方式
            return this.executors[(int) Math.abs(idx.getAndIncrement() % this.executors.length)];
        }
```

#### 2.5 ThreadPerTaskExecutor

用于执行NioEventLoop中taskQueue里面的任务。

```java
    /**
     * 任务执行器
     * 一般用来在线程池\任务执行器的实现中负责驱动任务的执行
     * @param command 提交给任务执行的具体任务
     */
    @Override
    public void execute(Runnable command) {
        /**
         * 资源懒加载
         * 在Java中线程是宝贵的资源
         * Java线程:OS线程=1:1
         * 针对这么宝贵的线程 可以立即进行Thread构造方法的属性赋值 但是不要继续调用start()方法
         *   - start()放触发系统调用 用户空间和内核空间切换 开销较大
         *   - 就等到用的时候再进行系统调用 使线程状态处于就绪
         *   - 等待CPU的调度 被CPU调度起来之后会回调进入entry point 内核->Thread::run->command::run(用户指定的代码片段)
         */
        threadFactory.newThread(command).start();
    }
```

#### 2.6 newChild方法

主要就是用来实例化NioEventLoop。

```java
    /**
     * NioEventLoopGroup实例创建的时候通过构造方法调用链
     *   - NioEventLoopGroup->MutithreadEventLoopGroup->MultithreadEventExecutorGroup
     *   - 在MultithreadEventExecutorGroup定义了一个抽象方法
     *   - 延迟到当前类进行实现
     * 关注的内容就是创建NioEventLoop实例
     * @param executor 线程执行器 实现是ThreadPerTaskExecutor
     * @param args 3个元素的数组
     *               - SelectorProvider.provider()
     *               - DefaultSelectStrategyFactory.INSTANCE
     *               - RejectedExecutionHandlers.reject()
     */
    @Override
    protected EventLoop newChild(Executor executor, Object... args) throws Exception { // executor=ThreadPerTaskExecutor实例 args=[SelectorProvider SelectStrategyFactory RejectedExecutionHandlers]
        /**
         * 实例是SelectorProvider.provider()
         * Java中对IO多路复用器的实现
         * 依赖Jdk的版本
         *   - Window=WindowsSelectorProvider
         *   - MacOSX=KQueueSelectorProvider
         *   - Linux=EPollSelectorProvider
         */
        SelectorProvider selectorProvider = (SelectorProvider) args[0];
        /**
         *  DefaultSelectStrategyFactory实例
         *  实例是DefaultSelectStrategyFactory.INSTANCE
         *  任务选择策略(如何从taskQueue任务队列中选择一个任务) 本质就是轮询
         *    - 数组长度是2的幂次方->位运算
         *    - 数组长度不是2的幂次方->取模
         */
        SelectStrategyFactory selectStrategyFactory = (SelectStrategyFactory) args[1];
        RejectedExecutionHandler rejectedExecutionHandler = (RejectedExecutionHandler) args[2];
        EventLoopTaskQueueFactory taskQueueFactory = null;
        EventLoopTaskQueueFactory tailTaskQueueFactory = null;

        int argsLength = args.length;
        /**
         * 如果客户端指定了taskQueueFactory和tailTaskQueueFactory就使用客户端指定
         */
        if (argsLength > 3) taskQueueFactory = (EventLoopTaskQueueFactory) args[3]; // null
        if (argsLength > 4) tailTaskQueueFactory = (EventLoopTaskQueueFactory) args[4]; // null
        return new NioEventLoop(this, // this是NioEventLoopGroup实例 在构造NioEventLoop的时候将线程是实例传给parent属性
                executor, // ThreadPerTaskExecutor实例
                selectorProvider,
                selectStrategyFactory.newSelectStrategy(), // taskQueue任务队列中有任务就poll一个任务出来执行 空的就阻塞等待任务到来
                rejectedExecutionHandler, // taskQueue任务队列满了拒绝策略(向上抛异常)
                taskQueueFactory, // 非IO任务队列
                tailTaskQueueFactory // 收尾任务队列
        ); // NioEventLoop就是NioEventLoopGroup这个线程池中的个体 相当于线程池中的线程 在每个NioEventLoop实例内部都持有一个自己Thread实例
    }
```

### 3 NioEventLoop

#### 3.1 {% post_link Netty/Netty-0x06-数据结构优化 创建队列实现MPSC %}

```java
    private static Queue<Runnable> newTaskQueue(
            EventLoopTaskQueueFactory queueFactory) {
        if (queueFactory == null) {
            /**
             * 依赖jctools的MPSC队列实现
             *   - 多生产者
             *   - 单消费者
             */
            return newTaskQueue0(DEFAULT_MAX_PENDING_TASKS);
        }
        return queueFactory.newTaskQueue(DEFAULT_MAX_PENDING_TASKS);
    }
```

#### 3.2 构造方法

```java
    /**
     * 构造方法的访问修饰符是默认的 只能在同包级别下访问 也就是说不对外暴露
     * 当前类属性赋值
     *   - selectorProvider 提供创建当前OS的多路复用器实例
     *   - selectStrategy 定义了Selector多路复用器1次select操作下如何处理任务
     *   - selector 基于Java原生Selector优化的版本
     *   - unwrappedSelector Java原生Selector
     * @param parent NioEventLoopGroup实例 标识着NioEventLoop归谁管理
     * @param executor 任务执行器 ThreadPerTaskExecutor的实例 负责执行任务 逻辑关系上是跟NioEventLoop绑定的
     * @param selectorProvider 负责创建IO多路复用器 SelectorProvider::provider
     * @param strategy DefaultSelectStrategyFactory.INSTANCE 负责Selector多路复用器1次select操作如何选择任务(IO任务\普通任务)
     * @param rejectedExecutionHandler RejectedExecutionHandlers.reject() 定义了NioEventLoop中taskQueue任务队列满了怎么办
     * @param taskQueueFactory 定义了如何创建taskQueue任务队列->null
     * @param tailTaskQueueFactory 定义了如何创建tailTaskQueue任务队列->null
     */
    NioEventLoop(NioEventLoopGroup parent,
                 Executor executor, // 线程执行器 将线程和EventLoop绑定
                 SelectorProvider selectorProvider, // Java中IO多路复用器提供器
                 SelectStrategy strategy, // 正常任务队列选择策略
                 RejectedExecutionHandler rejectedExecutionHandler, // 正常任务队列拒绝策略
                 EventLoopTaskQueueFactory taskQueueFactory, // 非IO任务
                 EventLoopTaskQueueFactory tailTaskQueueFactory // 收尾任务
    ) {
        /**
         * 为什么要用MPSC队列
         *   - 为什么要用队列这个数据结构
         *     - FIFO特性
         *     - Netty是NioEventLoop线程:任务=1:N 所以从任务视角来看 任务有先后
         *   - 为什么不是用现有的数据结构比如ArrayBlockingQueue\LinkedBlockingQueue\PriorityQueue
         *     - 首先得保证线程安全
         *     - 其次它们的生产者\消费者模型是N:N
         *     - 但是Netty中现在场景是1个NioEventLoop工作线程 N个任务 也就是生产者:消费者=N:1
         */
        super(parent,
                executor,
                false,
                newTaskQueue(taskQueueFactory), // 非IO任务队列 Netty对队列数据结构的优化
                newTaskQueue(tailTaskQueueFactory), // 收尾任务队列
                rejectedExecutionHandler
        ); // 调用父类构造方法
        /**
         * IO多路复用器提供器 用于创建多路复用器实现
         */
        this.provider = ObjectUtil.checkNotNull(selectorProvider, "selectorProvider");
        /**
         * 定义了将来Selector的1次select怎么处理任务
         *   - IO任务怎么处理
         *   - taskQueue任务队列中任务怎么处理
         */
        this.selectStrategy = ObjectUtil.checkNotNull(strategy, "selectStrategy");
        /**
         * 开启NIO中的组件Selector
         * 通过上面提供的selectorProvider创建适配当前OS平台的Selector多路复用器实现
         * 意味着NioEventLoopGroup这个线程池中每个线程NioEventLoop都有自己的selector
         */
        final SelectorTuple selectorTuple = this.openSelector();
        /**
         * 创建NioEventLoop绑定的selector对象
         * 初始化了IO多路复用器
         */
        this.selector = selectorTuple.selector; // Netty优化过的IO多路复用器
        this.unwrappedSelector = selectorTuple.unwrappedSelector; // Java原生的多路复用器
    }
```



```java
    /**
     * 属性赋值
     *   - addTaskWakesUp 默认值false
     *   - maxPendingTasks
     *   - executor Executor跟NioEventLoop绑定之后形成的新的Executor
     *   - taskQueue MPSC任务队列
     *   - rejectedExecutionHandler RejectedExecutionHandlers.reject()的返回值
     * @param parent NioEventLoop归属的NioEventLoopGroup
     * @param executor ThreadPerTaskExecutor的实例
     * @param addTaskWakesUp 默认值false
     */
    protected SingleThreadEventExecutor(EventExecutorGroup parent,
                                        Executor executor,
                                        boolean addTaskWakesUp,
                                        Queue<Runnable> taskQueue,
                                        RejectedExecutionHandler rejectedHandler
    ) { // 所以本质上每个线程也是一个线程池(单线程线程池)
        super(parent); // 设置parent 也就是NioEventLoopGroup实例
        this.addTaskWakesUp = addTaskWakesUp; // 标识唤醒阻塞线程的方式 NioEventLoop阻塞发生在复用器操作上 因此这个设置为false
        this.maxPendingTasks = DEFAULT_MAX_PENDING_EXECUTOR_TASKS;
        /**
         * 强化原始的Executor任务执行器
         * 将Executor跟NioEventLoop绑定起来
         * Executor本身是ThreadPerTaskExecutor实例 创建线程这个动作延迟到任务执行的时候
         */
        this.executor = ThreadExecutorMap.apply(executor, this);
        this.taskQueue = ObjectUtil.checkNotNull(taskQueue, "taskQueue"); // 创建任务队列 提交给NioEventLoop的任务都会进入到这个taskQueue中等待被执行 这个taskQueue容量默认值16 任务队列 NioEventLoop需要负责IO事件和非IO事件 通常它都是在执行selector::select方法或者正在处理selectedKeys 如果要submit一个任务给它 任务就会被放到taskQueue中 等它来轮询 该队列是线程安全的LinkedBlockingQueue
        this.rejectedExecutionHandler = ObjectUtil.checkNotNull(rejectedHandler, "rejectedHandler"); // 任务队列taskQueue的默认容量是16 如果submit的任务堆积到了16 再往里面提交任务就会触发拒绝策略的执行
    }
```



```java
    protected AbstractEventExecutor(EventExecutorGroup parent) {
        this.parent = parent; // 这个parent就是NioEventLoop所属的线程组NioEventLoopGroup对象
    }
```

### 4 组件示意图

![](Netty-0x04-NioEventLoopGroup和NioEventLoop详细初始化过程/image-20230516224202667.png)

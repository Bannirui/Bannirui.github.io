---
title: JVM-0x07-JVM启动
date: 2023-05-04 15:38:45
category_bar: true
tags:  [ JVM@15 ]
categories: [ JVM ]
---

通过创建线程的方式，将JVM的创建启动控制权转移到新线程被CPU的调度时机。

JVM启动的核心逻辑定义在JavaMain中，即JavaMain函数是JVM虚拟机的启动入口。

### 1 JVMInit

```c
/**
 *
 * @param ifn JVM的启动函数在这个结构体中
 * @param threadStackSize 0
 * @param argc 0 JVM启动参数 没有指定额外的JVM启动参数 都用默认的
 * @param argv null
 * @param mode JVM的启动方式
 *               - 1 Class启动方式
 *               - 2 Jar包启动方式
 *               - ...
 * @param what JVM启动要加载的字节码文件
 *               - 以Class启动方式启动JVM 要加载的字节码文件是VMLoaderTest.java编译好的class字节码文件VMLoaderTest
 * @param ret JVM执行完如何退出
 *              - 0 正常退出
 * @return
 */
int
JVMInit(InvocationFunctions* ifn, jlong threadStackSize,
                 int argc, char **argv,
                 int mode, char *what, int ret) {
  // sameThread宏定义默认值false 即新启一个线程作为JVM主线程
    if (sameThread) {
        JLI_TraceLauncher("In same thread\n");
        // need to block this thread against the main thread
        // so signals get caught correctly
        __block int rslt = 0;
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        {
            NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock: ^{
                JavaMainArgs args;
                args.argc = argc;
                args.argv = argv;
                args.mode = mode;
                args.what = what;
                args.ifn  = *ifn;
                rslt = JavaMain(&args);
            }];

            /*
             * We cannot use dispatch_sync here, because it blocks the main dispatch queue.
             * Using the main NSRunLoop allows the dispatch queue to run properly once
             * SWT (or whatever toolkit this is needed for) kicks off it's own NSRunLoop
             * and starts running.
             */
            [op performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:YES];
        }
        [pool drain];
        return rslt;
    } else {
      /**
       * 新建一个线程作为JVM的主线程
       *   - 对这个线程而言 不指定其线程栈大小 交给jdk使用默认值
       *   - JVM启动参数都不指定 全部使用默认 比如最大堆 垃圾回收算法等等
       *   - 只指定JVM让其以Class启动方式 class字节码文件为what 执行完Java代码之后 退出方式为ret
       */
        return ContinueInNewThread(ifn, threadStackSize, argc, argv, mode, what, ret);
    }
}
```

### 2 ContinueInNewThread

```c
/**
 * 新建一个线程作为JVM的主线程启动JVM
 * @param ifn JVM的启动函数在这个结构体中
 * @param threadStackSize 0 不指定线程栈大小 交给jdk使用默认值
 * @param argc 0 JVM的启动参数 没有指定jVM的启动参数 都是用默认的
 * @param argv null
 * @param mode JVM启动方式
 *               - 1 Class启动方式
 * @param what JVM启动加载的字节文件
 *               - VMLoaderTest.java编译好的class字节码文件
 * @param ret JVM退出方式
 *              - 0 正常退出
 * @return
 */
int
ContinueInNewThread(InvocationFunctions* ifn, jlong threadStackSize,
                    int argc, char **argv,
                    int mode, char *what, int ret)
{
    if (threadStackSize == 0) {
        /*
         * If the user hasn't specified a non-zero stack size ask the JVM for its default.
         * A returned 0 means 'use the system default' for a platform, e.g., Windows.
         * Note that HotSpot no longer supports JNI_VERSION_1_1 but it will
         * return its default stack size through the init args structure.
         */
        struct JDK1_1InitArgs args1_1;
        memset((void*)&args1_1, 0, sizeof(args1_1));
        args1_1.version = JNI_VERSION_1_1;
        ifn->GetDefaultJavaVMInitArgs(&args1_1);  /* ignore return value */
        if (args1_1.javaStackSize > 0) {
            threadStackSize = args1_1.javaStackSize;
        }
    }

    { /* Create a new thread to create JVM and invoke main method */
        JavaMainArgs args;
        int rslt;

        args.argc = argc;
        args.argv = argv;
        args.mode = mode;
        args.what = what;
        args.ifn = *ifn;

        rslt = CallJavaMainInNewThread(threadStackSize, (void*)&args);
        /* If the caller has deemed there is an error we
         * simply return that, otherwise we return the value of
         * the callee
         */
        return (ret != 0) ? ret : rslt;
    }
}
```

### 3 CallJavaMainInNewThread

```c
/**
 * 创建一个新线程作为JVM的主线程 指定这个线程的栈大小为stack_size
 * 该线程被CPU调度之后会回调ThreadJavaMain方法 这个方法的参数为args
 * 也就是说JVM的启动入口就是ThreadJavaMain函数
 * @param stack_size JVM主线程 线程栈大小
 * @param args 启动JVM的参数
 * @return
 */
int
CallJavaMainInNewThread(jlong stack_size, void* args) {
    int rslt;
    pthread_t tid;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);

    if (stack_size > 0) {
      // 指定线程栈大小
        pthread_attr_setstacksize(&attr, stack_size);
    }
    pthread_attr_setguardsize(&attr, 0); // no pthread guard page on java threads

    if (pthread_create(&tid, &attr, ThreadJavaMain, args) == 0) { // 系统调用创建线程 这个线程就是JVM的主线程 该线程被CPU调度之后就回调ThreadJavaMain方法 并且方法的参数为args
        void* tmp;
        pthread_join(tid, &tmp);
        rslt = (int)(intptr_t)tmp;
    } else {
       /*
        * Continue execution in current thread if for some reason (e.g. out of
        * memory/LWP)  a new thread can't be created. This will likely fail
        * later in JavaMain as JNI_CreateJavaVM needs to create quite a
        * few new threads, anyway, just give it a try..
        */
        rslt = JavaMain(args);
    }

    pthread_attr_destroy(&attr);
    return rslt;
}
```


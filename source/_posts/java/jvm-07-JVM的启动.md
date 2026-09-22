---
title: jvm-07-JVM的启动
date: 2023-05-04 15:38:45
category_bar: true
categories: jvm
---

找到启动JVM的代码在哪儿

```sh
grep -Rn "JVMInit("
```

这个调用链路是

- 1 java_md.c#JVMInit
- 2 java.c#ContinueInNewThread
- 3 java_md.c#CallJavaMainInNewThread
- 4 java_md.c#ThreadJavaMain 线程的调度被调度起来会执行的函数
- 5 java.c#JavaMain {%post_link java/jvm-08-JavaMain干了什么%}

```cpp
    // 系统调用创建线程 CPU调度到ThreadJavaMain函数
    if (pthread_create(&tid, &attr, ThreadJavaMain, args) == 0) {
        void* tmp;
        /**
         * cur thread will be blocked here, how to terminate thread, it will terminate in one of following ways:
         * 1 It calls pthread_exit(3), specifying an exit status value that is available to another thread in the same process that calls pthread_join(3).
         * 2 It  returns  from start_routine().  This is equivalent to calling pthread_exit(3) with the value supplied in the return statement.
         * 3 It is canceled (see pthread_cancel(3)).
         * 4 Any of the threads in the process calls exit(3), or the main thread performs a return from main(). This causes the termination of all threads in the process.
         */
        // 当前线程阻塞在这里
        pthread_join(tid, &tmp);
```

```cpp
static void* ThreadJavaMain(void* args) {
    return (void*)(intptr_t)JavaMain(args);
}
```

---
title: jvm-0x04-设置运行环境参数
date: 2023-04-28 13:31:57
category_bar: true
categories: jvm
---

CreateExecutionEnvironment该函数主要负责两件事情：

* 路径解析
  * jre
  * jvm
  * jvmcfg
* 尝试创建新线程

### 1 路径解析

```c
    jboolean jvmpathExists;

    /* Compute/set the name of the executable */
    SetExecname(*pargv);

    char * jvmtype    = NULL;
    int  argc         = *pargc;
    char **argv       = *pargv;

    /* Find out where the JRE is that we will be using. */
    if (!GetJREPath(jrepath, so_jrepath, JNI_FALSE) ) {
        JLI_ReportErrorMessage(JRE_ERROR1);
        exit(2);
    }
    JLI_Snprintf(jvmcfg, so_jvmcfg, "%s%slib%sjvm.cfg",
                 jrepath, FILESEP, FILESEP);
    /* Find the specified JVM type */
    if (ReadKnownVMs(jvmcfg, JNI_FALSE) < 1) {
        JLI_ReportErrorMessage(CFG_ERROR7);
        exit(1);
    }

    jvmpath[0] = '\0';
    jvmtype = CheckJvmType(pargc, pargv, JNI_FALSE);
    if (JLI_StrCmp(jvmtype, "ERROR") == 0) {
        JLI_ReportErrorMessage(CFG_ERROR9);
        exit(4);
    }

    if (!GetJVMPath(jrepath, jvmtype, jvmpath, so_jvmpath)) {
        JLI_ReportErrorMessage(CFG_ERROR8, jvmtype, jvmpath);
        exit(4);
    }
```

### 2 尝试创建线程

```c
    /**
     * 本质就是创建一个线程
     * debug实参
     *   - argc->2
     *   - argv
     *     - /jdk/build/macosx-x86_64-server-slowdebug/jdk/bin/java
     *     - VMLoaderTest
     */
    MacOSXStartup(argc, argv);
```



```c
/**
 * 创建新的线程
 * 这个函数的设计我是没看懂的
 * 从jdk的启动开始 执行路径是  t1       t1                 t1                   t1         t2       t2
 *                        main->JLI_Launch->CreateExecutionEnvironment->MacOSXStartup->main->JLI_Launch->...
 * 但是注释上说的是
 * Mac OS X requires the Cocoa event loop to be run on the "main"
 * thread. Spawn off a new thread to run main() and pass
 * this thread off to the Cocoa event loop.
 * @param argc
 * @param argv 从JLI_Launch函数带下来的启动参数
 *          - /jdk/build/macosx-x86_64-server-slowdebug/jdk/bin/java
 *          - VMLoaderTest
 */
static void MacOSXStartup(int argc, char *argv[]) {
    // Thread already started?
    // static修饰的started标识符 即该方法只会被调用一次
    static jboolean started = false;
    if (started) {
        return;
    }
    started = true;

    // Hand off arguments
    struct NSAppArgs args;
    args.argc = argc;
    args.argv = argv;

    // Fire up the main thread
    pthread_t main_thr;
    /**
     * 系统调用创建线程
     *   - main_thr 线程创建成功后用来接收线程id
     *   - 线程属性使用默认的
     *   - apple_main 线程创建好后处于就绪状态 被cpu调度之后 执行的逻辑入口
     *   - args apple_main执行的启动参数
     */
    if (pthread_create(&main_thr, NULL, &apple_main, &args) != 0) {
        JLI_ReportErrorMessageSys("Could not create main thread: %s\n", strerror(errno));
        exit(1)
    }
    if (pthread_detach(main_thr)) {
        JLI_ReportErrorMessageSys("pthread_detach() failed: %s\n", strerror(errno));
        exit(1);
    }

    ParkEventLoop();
}
```

#### 2.1 {% post_link java/jvm-0x05-pthread系统调用 %}

创建好线程，线程处于就绪状态，等待被cpu调度，一旦被调度成功，新线程就开始执行。

#### 2.2 线程start_routine

即线程被cpu调度之后，开始执行的逻辑。

这个里面还涉及到{% post_link java/jvm-0x07-加载动态链接库 %}。

```c
/**
 * 系统调用pthread_create时传递的start_routine参数
 * 创建的线程被cpu调度后从该函数开始执行
 * @param arg
 * @return
 */
static void *apple_main (void *arg)
{
    if (main_fptr == NULL) { // 默认值为空
#ifdef STATIC_BUILD
        extern int main(int argc, char **argv);
        main_fptr = &main;
#else
        /**
         * 系统调用
         * main_fptr指向的是main.c#main函数
         */
        main_fptr = (int (*)())dlsym(RTLD_DEFAULT, "main");
#endif
        if (main_fptr == NULL) {
            JLI_ReportErrorMessageSys("error locating main entrypoint\n");
            exit(1);
        }
    }

    struct NSAppArgs *args = (struct NSAppArgs *) arg;
    /**
     * main_fptr就是指向main.c#main函数的地址
     * t2调用main.c#main函数 启动参数就是t1线程当时执行main.c#main的启动参数
     */
    exit(main_fptr(args->argc, args->argv));
}
```


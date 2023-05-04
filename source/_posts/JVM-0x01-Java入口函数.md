---
title: JVM-0x01-Java入口函数
date: 2023-04-28 13:18:56
tags:  [ JVM@15 ]
categories: [ JVM ]
---

这个函数涉及过程比较多，按照功能将其拆分成小的模块。

### 1 参数解析

这个环节我觉得不重要，就是打端点看看哪些参数做了哪些操作，所有的这些变量肯定都是为了后面服务的执行铺垫的，后面看到重要的环节了，不知道某个参数怎么赋值的再回过头来看就行了。

```c
  /**
   * java的启动方式
   *   - Class启动
   *   - Jar包启动
   *   - ...
   */
    int mode = LM_UNKNOWN;
    char *what = NULL;
    char *main_class = NULL;
    int ret;
    InvocationFunctions ifn;
    jlong start = 0, end = 0;
    char jvmpath[MAXPATHLEN];
    char jrepath[MAXPATHLEN];
    char jvmcfg[MAXPATHLEN];

    _fVersion = fullversion;
    _launcher_name = lname;
    _program_name = pname;
    _is_java_args = javaargs;
    _wc_enabled = cpwildcard;

    // 窗体模式启动进程 只支持win系统
    InitLauncher(javaw);
    DumpState();
    if (JLI_IsTraceLauncher()) {
        int i;
        printf("Java args:\n");
        for (i = 0; i < jargc ; i++) {
            printf("jargv[%d] = %s\n", i, jargv[i]);
        }
        printf("Command line args:\n");
        for (i = 0; i < argc ; i++) {
            printf("argv[%d] = %s\n", i, argv[i]);
        }
        AddOption("-Dsun.java.launcher.diag=true", NULL);
    }

    /*
     * SelectVersion() has several responsibilities:
     *
     *  1) Disallow specification of another JRE.  With 1.9, another
     *     version of the JRE cannot be invoked.
     *  2) Allow for a JRE version to invoke JDK 1.9 or later.  Since
     *     all mJRE directives have been stripped from the request but
     *     the pre 1.9 JRE [ 1.6 thru 1.8 ], it is as if 1.9+ has been
     *     invoked from the command line.
     */
    SelectVersion(argc, argv, &main_class);
```

### 2 {% post_link JVM-0x02-创建运行环境 创建运行环境 %}

```c
    /**
     * 创建运行环境
     *   - 解析jre jvm路径
     *   - 创建线程t2
     *     - 第一次执行到这的线程是t1 t2被创建之后t1被挂起
     *     - t2线程被cpu调度之后执行的是main.c中的入口方法main 顺着调用链会再次执行到这
     *     - 第二次执行和第一次执行的唯一区别就是不用再创建新的线程
     */
    CreateExecutionEnvironment(&argc, &argv,
                               jrepath, sizeof(jrepath),
                               jvmpath, sizeof(jvmpath),
                               jvmcfg,  sizeof(jvmcfg));
```

也就是说从启动开始，会有2个不同的线程以同样的启动参数执行到这。

时序图如下：

![](JVM-0x01-Java入口函数/image-20230428143738915.png)

### 3 {% post_link JVM-0x04-加载JVM 加载JVM %}

JVM启动的前置准备，JVM的启动函数。

```c
    /**
     * 加载JVM
     * 从JVM动态链接库中加载好启动JVM需要的函数 在后面进行JVM启动时机直接调用
     *
     * jvmpath /jdk/build/macosx-x86_64-server-slowdebug/jdk/lib/server/lib/libjvm.dylib
     * 从jvm动态链接库加载出3个函数放在ifn中
     *   - JNI_CreateJavaVM
     *   - JNI_GetDefaultJavaVMInitArgs
     *   - JNI_GetCreatedJavaVMs
     */
    if (!LoadJavaVM(jvmpath, &ifn)) {
        return(6);
    }
```

### 4 {% post_link JVM-0x06-JVM启动参数 解析JVM启动参数 %}

JVM启动的前置准备，JVM的启动参数。

```c
    /**
     * 解析JVM启动参数
     *   - argc 1
     *   - argv VMLoaderTest
     *   - jrepath /jdk/build/macosx-x86_64-server-slowdebug/jdk/bin/java
     * 解析出来的结果存放
     *   - mode 启动方式
     *     - 1 Class启动方式
     *     - 2 Jar包启动方式
     *   - what JVM加载的class字节码文件
     *     - VMLoaderTest
     *   - ret JVM退出方式
     *     - 0 正常退出
     */
    if (!ParseArguments(&argc, &argv, &mode, &what, &ret, jrepath)) {
        return(ret);
    }
```

### 5 {% post_link JVM-0x07-JVM启动 启动JVM %}

根据前置准备好的信息，正式启动JVM。

* JVM启动函数
* JVM启动参数

```c
    /**
     * 启动JVM
     *   - ifn 包含了JVM动态链接库的3个函数
     *     - JNI_CreateJavaVM函数
     *     - JNI_GetDefaultJavaVMInitArgs函数
     *     - JNI_GetCreatedJavaVMs函数
     *   - threadStackSize 0
     *   - argc JVM启动参数 0
     *   - argv JVM启动参数 null
     *   - mode JVM启动方式
     *     - 1 Class启动方式
     *     - 2 Jar包启动方式
     *     - ...
     *   - what
     *     - JVM要加载的字节码文件 VMLoaderTest
     *   -ret JVM退出方式
     *     - 0 正常退出
     *
     * 语义就是启动JVM 让JVM以Class启动方式加载VMLoaderTest这个class字节码文件
     * 该函数本身并不直接负责启动JVM 其内部通过创建新线程的方式将JVM的启动这个动作控制权转移给新的线程
     * 而JVM启动时机就是新线程被CPU调度的时候 新线程被调度之后执行的是JavaMain方法 即JVM的启动逻辑在JavaMain方法中
     */
    return JVMInit(&ifn, threadStackSize, argc, argv, mode, what, ret);
```

### 6 小结

上述一系列流程如下图，JVM的启动核心逻辑在JavaMain函数中。

![](JVM-0x01-Java入口函数/image-20230504165958744.png)

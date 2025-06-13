---
title: jvm-0x06-加载JVM
date: 2023-05-04 14:17:45
category_bar: true
categories: jvm
---
JVM启动的前置准备，加载JVM动态链接库，JVM启动涉及到的函数。

```c
/**
 * 从jvm的动态链接库中获取出3个启动JVM需要的函数 在进行JVM启动时机时直接调用加载出来的函数就行
 *   - JNI_CreateJavaVM
 *   - JNI_GetDefaultJavaVMInitArgs
 *   - JNI_GetCreatedJavaVMs
 * @param jvmpath jvm路径 libjvm.dylib的全路径
 *                即动态链接库文件 应该是jvm的实现被编译成了动态链接库 在运行时通过插件方式进行使用
 *                /jdk/build/macosx-x86_64-server-slowdebug/jdk/lib/server/lib/libjvm.dylib
 * @param ifn 从动态链接库中获取指定的3个函数
 *              - JNI_CreateJavaVM
 *              - JNI_GetDefaultJavaVMInitArgs
 *              - JNI_GetCreatedJavaVMs
 */
jboolean
LoadJavaVM(const char *jvmpath, InvocationFunctions *ifn)
{
    Dl_info dlinfo;
    // 动态链接库打开后的句柄
    void *libjvm;

    JLI_TraceLauncher("JVM path is %s\n", jvmpath);

#ifndef STATIC_BUILD
    libjvm = dlopen(jvmpath, RTLD_NOW + RTLD_GLOBAL); // 系统调用 打开动态链接库文件
#else
    libjvm = dlopen(NULL, RTLD_FIRST);
#endif
    if (libjvm == NULL) {
        JLI_ReportErrorMessage(DLL_ERROR1, __LINE__);
        // 通过dlerror显式获取动态链接库的操作失败的出错信息
        JLI_ReportErrorMessage(DLL_ERROR2, jvmpath, dlerror());
        return JNI_FALSE;
    }

    /**
     * 获取JNI_CreateJavaVM函数
     * 声明在jni.h中
     * 实现在jni.cpp中
     */
    ifn->CreateJavaVM = (CreateJavaVM_t)
        dlsym(libjvm, "JNI_CreateJavaVM");
    if (ifn->CreateJavaVM == NULL) {
        JLI_ReportErrorMessage(DLL_ERROR2, jvmpath, dlerror());
        return JNI_FALSE;
    }

    /**
     * 获取JNI_GetDefaultJavaVMInitArgs函数
     * 声明在jni.h中
     * 实现在jni.cpp中
     */
    ifn->GetDefaultJavaVMInitArgs = (GetDefaultJavaVMInitArgs_t)
        dlsym(libjvm, "JNI_GetDefaultJavaVMInitArgs");
    if (ifn->GetDefaultJavaVMInitArgs == NULL) {
        JLI_ReportErrorMessage(DLL_ERROR2, jvmpath, dlerror());
        return JNI_FALSE;
    }

    /**
     * 获取JNI_GetCreatedJavaVMs函数
     * 声明在jni.h中
     * 实现在jni.cpp中
     */
    ifn->GetCreatedJavaVMs = (GetCreatedJavaVMs_t)
    dlsym(libjvm, "JNI_GetCreatedJavaVMs");
    if (ifn->GetCreatedJavaVMs == NULL) {
        JLI_ReportErrorMessage(DLL_ERROR2, jvmpath, dlerror());
        return JNI_FALSE;
    }

    return JNI_TRUE;
}
```
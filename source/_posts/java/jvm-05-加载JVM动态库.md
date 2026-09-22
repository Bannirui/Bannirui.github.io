---
title: jvm-05-加载JVM动态库
date: 2023-05-04 14:17:45
category_bar: true
categories: jvm
---

```cpp
/**
 * 从动态库里面找到3个函数地址保存到ifn里面
 * 单纯用系统函数dlopen/dlsym
 * @param jvmpath libjvm.so动态库的路径 /home/dingrui/MyDev/cpp/jdk/build/linux-x86_64-server-slowdebug/jdk/lib/server/libjvm.so
 * @param ifn 保存动态库的3个函数地址
 */
jboolean
LoadJavaVM(const char *jvmpath, InvocationFunctions *ifn)
{
    void *libjvm;

    JLI_TraceLauncher("JVM path is %s\n", jvmpath);

    libjvm = dlopen(jvmpath, RTLD_NOW + RTLD_GLOBAL);
    if (libjvm == NULL) {
        JLI_ReportErrorMessage(DLL_ERROR1, __LINE__);
        JLI_ReportErrorMessage(DLL_ERROR2, jvmpath, dlerror());
        return JNI_FALSE;
    }
    // jvm动态库的这3个函数实现在jni.cpp里面
    ifn->CreateJavaVM = (CreateJavaVM_t)
        dlsym(libjvm, "JNI_CreateJavaVM");
    if (ifn->CreateJavaVM == NULL) {
        JLI_ReportErrorMessage(DLL_ERROR2, jvmpath, dlerror());
        return JNI_FALSE;
    }

    ifn->GetDefaultJavaVMInitArgs = (GetDefaultJavaVMInitArgs_t)
        dlsym(libjvm, "JNI_GetDefaultJavaVMInitArgs");
    if (ifn->GetDefaultJavaVMInitArgs == NULL) {
        JLI_ReportErrorMessage(DLL_ERROR2, jvmpath, dlerror());
        return JNI_FALSE;
    }

    ifn->GetCreatedJavaVMs = (GetCreatedJavaVMs_t)
        dlsym(libjvm, "JNI_GetCreatedJavaVMs");
    if (ifn->GetCreatedJavaVMs == NULL) {
        JLI_ReportErrorMessage(DLL_ERROR2, jvmpath, dlerror());
        return JNI_FALSE;
    }

    return JNI_TRUE;
}
```

这个系统调用还是很有趣的{%post_link java/jvm-06-动态库的有趣操作%}
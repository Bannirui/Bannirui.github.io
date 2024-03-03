---
title: JVM-0x05-加载动态链接库
date: 2023-05-04 13:37:40
category_bar: true
tags:  [ JVM@15 ]
categories: [ JVM ]
---

系统调用。

### 1 dlopen

#### 1.1 作用

打开动态链接库文件。

#### 1.2 原型

```c
void* dlopen(const char* path, int mode);
```

#### 1.3 描述

```xml
dlopen() examines the mach-o file specified by path.  If the file is
compatible with the current process and has not already been loaded
into the current process, it is loaded and linked.  After being
linked, if it contains any initializer functions, they are called,
before dlopen() returns.  dlopen() can load dynamic libraries and bun-
dles.  It returns a handle that can be used with dlsym() and
dlclose().  A second call to dlopen() with the same path will return
the same handle, but the internal reference count for the handle will
be incremented.  Therefore all dlopen() calls should be balanced with
a dlclose() call.
```

### 2 dlsym

#### 2.1 作用

get address of a symbol

#### 2.2 原型

```c
void*
    dlsym(void* handle, const char* symbol);
```

#### 2.3 描述

```xml
dlsym() returns the address of the code or data location specified by
the null-terminated character string symbol.  Which libraries and bun-
dles are searched depends on the handle parameter.

If dlsym() is called with a handle, returned by dlopen() then only
that image and any libraries it depends on are searched for symbol.
```

### 3 dlerror

#### 3.1 作用

动态链接库相关操作(dlopen\dlsym)的错误信息。

#### 3.2 原型

```c
const char*
    dlerror(void);
```

#### 3.3 描述

```xml
dlerror() returns a null-terminated character string describing the
last error that occurred on this thread during a call to dlopen(),
dlopen_preflight(), dlsym(), or dlclose().  If no such error has
occurred, dlerror() returns a null pointer.  At each call to
dlerror(), the error indication is reset.  Thus in the case of two
calls to dlerror(), where the second call follows the first immedi-
ately, the second call will always return a null pointer.
```


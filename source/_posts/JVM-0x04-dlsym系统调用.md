---
title: JVM-0x04-dlsym系统调用
date: 2023-04-28 14:23:19
tags:  [ JVM@15 ]
categories: [ JVM ]
---

### 1 函数原型

```c
void*
    dlsym(void* handle, const char* symbol);
```



### 2 详解

```xml
dlsym() returns the address of the code or data location specified by
the null-terminated character string symbol.  Which libraries and bun-
dles are searched depends on the handle parameter.

If dlsym() is called with a handle, returned by dlopen() then only
that image and any libraries it depends on are searched for symbol.

If dlsym() is called with the special handle RTLD_DEFAULT, then all
mach-o images in the process (except those loaded with dlopen(xxx,
RTLD_LOCAL)) are searched in the order they were loaded.  This can be
a costly search and should be avoided.

If dlsym() is called with the special handle RTLD_NEXT, then dyld
searches for the symbol in the dylibs the calling image linked against
when built. It is usually used when you intentionally have multiply
defined symbol across images and want to find the "next" definition.
It searches other images for the definition that the caller would be
using if it did not have a definition.  The exact search algorithm
depends on whether the caller's image was linked -flat_namespace or
-twolevel_namespace.  For flat linked images, the search starts in the
load ordered list of all images, in the image right after the caller's
image.  For two-level images, the search simulates how the static
linker would have searched for the symbol when linking the caller's
image.

If dlsym() is called with the special handle RTLD_SELF, then the
search for the symbol starts with the image that called dlsym().  If
it is not found, the search continues as if RTLD_NEXT was used.

If dlsym() is called with the special handle RTLD_MAIN_ONLY, then it
only searches for symbol in the main executable.
```



### 3 返回值

```xml
The dlsym() function returns a null pointer if the symbol cannot be
found, and sets an error condition which may be queried with
dlerror().
```


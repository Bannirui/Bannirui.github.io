---
title: 编译报错backslash-newline
category_bar: true
date: 2024-06-16 10:35:36
categories: C\CPP
---

编译时遇到warning为`warning: backslash-newline at end of file`

源码为
```c
#pragma once

#define print(x)                    \
do                                  \
{                                   \
  int size=sizeof(x);               \
  if(size<=4)                       \
  {                                 \
    __asm__("mov $0x3f8, %%dx\n\t"  \
            "out %%eax, %%dx\n\t"   \
            :                       \
            : "a"(x)                \
            : "dx"                  \
    );                              \
  }                                 \
  else if(size==8)                  \
  {                                 \
    __asm__("mov $0x3f8, %%dx\n\t" \
            "out %%eax, %%dx\n\t"   \
            "shr $32, %%rax\n\t"    \
            "out %%eax, %%dx\n\t"   \
            :                       \
            : "a"(x)                \
            : "dx"                  \
    );                              \
  }                                 \
} while (0)
```

在文件末尾添加新的空白行即可
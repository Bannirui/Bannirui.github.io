---
title: jvm-0x05-pthread系统调用
date: 2023-04-28 14:01:05
category_bar: true
categories: jvm
---

系统调用。

### 1 pthread_create

#### 1.1 函数原型

```c
int
pthread_create(pthread_t *thread, const pthread_attr_t *attr,
                   void *(*start_routine)(void *), void *arg);
```

#### 1.2 详解

```xml
The pthread_create() function is used to create a new thread, with
attributes specified by attr, within a process.  If attr is NULL, the
default attributes are used.  If the attributes specified by attr are
modified later, the thread's attributes are not affected.  Upon suc-
cessful completion pthread_create() will store the ID of the created
thread in the location specified by thread.

The thread is created executing start_routine with arg as its sole
argument.  If the start_routine returns, the effect is as if there was
an implicit call to pthread_exit() using the return value of
start_routine as the exit status.  Note that the thread in which
main() was originally invoked differs from this.  When it returns from
main(), the effect is as if there was an implicit call to exit() using
the return value of main() as the exit status.

Upon thread exit the storage for the thread must be reclaimed by
another thread via a call to pthread_join().  Alternatively,
pthread_detach() may be called on the thread to indicate that the sys-
tem may automatically reclaim the thread storage upon exit.  The
pthread_attr_setdetachstate() function may be used on the attr argu-
ment passed to pthread_create() in order to achieve the same effect as
a call to pthread_detach() on the newly created thread.

The signal state of the new thread is initialized as:

o   The signal mask is inherited from the creating thread.

o   The set of signals pending for the new thread is empty.
```

#### 1.3 返回值

```xml
If successful, the pthread_create() function will return zero.  Other-
wise an error number will be returned to indicate the error.
```

### 2 pthread_detach

#### 2.1 函数原型

```c
int
pthread_detach(pthread_t thread);
```

#### 2.2 详解

```xml
The pthread_detach() function is used to indicate to the implementa-
tion that storage for the thread thread can be reclaimed when the
thread terminates.  If thread has not terminated, pthread_detach()
will not cause it to terminate.  The effect of multiple
pthread_detach() calls on the same target thread is unspecified.
```

#### 2.3 返回值

```xml
If successful, the pthread_detach() function will return zero.  Other-
wise an error number will be returned to indicate the error.  Note
that the function does not change the value of errno as it did for
some drafts of the standard.  These early drafts also passed a pointer
to pthread_t as the argument.  Beware!
```


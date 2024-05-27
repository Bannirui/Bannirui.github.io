---
title: Redis-0x1A-后台线程
category_bar: true
date: 2024-05-22 15:07:12
categories: Redis
---

实现在bio.c中，插个题外话java中有BIO，为Blocking IO，Redis中的这个bio为Background IO。

因此这个部分基本都是跟线程相关的内容

- 在Java中线程相关的操作被封装在了`Thread`类中，虽然跟系统线程1:1，但是屏蔽了所有线程生命周期的细节

- 锁相关的原语被封装在了JVM关键字`synchronized`中，同样屏蔽了所有的细节

通过这个章节的学习，应该可以大大提升对线程的理解

1 线程
---

### 1.1 pthread_create

POSIX线程库的函数，用于创建新的线程

原型

```c
     #include <pthread.h>

     int
     pthread_create(pthread_t *thread, const pthread_attr_t *attr, void *(*start_routine)(void *), void *arg);
```

- thread 指针 指向pthread_t类型 用于存储创建好的新线程的标识符

- attr 指针 指向pthread_attr_t类型 用于指定新线程的属性 通常情况传NULL表示使用默认属性

- start_routine 函数指针 指向入参是void* 出参是void*的函数 该函数用于新线程的入口 新线程被CPU调度起来后执行的逻辑就通过这个函数指针来指定

- arg 指针 传递给start_routine函数的参数

源码

```c
        void *arg = (void*)(unsigned long) j;
		/**
		 * 系统调用pthread_create创建线程
		 * <ul>参数
		 *   <li>thread 指向pthread_t类型变量的指针 用于存储新线程的标识符</li>
		 *   <li>attr 指向pthread_attr_t类型变量的指针 用于指定新线程的属性 通常情况传递NULL表示使用默认属性</li>
		 *   <li>start_routine 指向函数的指针 该函数用于新线程的入口点 该函数的签名必须是void* (*start_routine) (void*) 它接受一个void*类型的参数并返回一个void*类型指针</li>
		 *   <li>arg 传递给start_routine函数的参数 是一个void*类型指针</li>
		 * </ul>
		 */
        if (pthread_create(&thread,&attr,bioProcessBackgroundJobs,arg) != 0) {
            serverLog(LL_WARNING,"Fatal: Can't initialize Background Jobs.");
            exit(1);
        }
		// 新建的线程缓存到线程池
        bio_threads[j] = thread;
```

### 1.2 pthread_self

返回函数调用者线程的id
通常在多线程环境中调用函数获取当前线程的id

源码

```c
		/**
		 * 不能自己kill自己
		 * pthread_self函数返回的是当前线程的id
		 */
        if (bio_threads[j] == pthread_self()) continue;
```

### 1.3 pthread_cancel

POSIX线程库中的函数 用于请求取消指定线程

这个函数将发送一个取消请求给指定的线程 线程在收到取消请求后 可以选择在适当的时候取消执行
被取消的线程将在取消点处终止执行
取消点指的是那些可以安全地取消线程并清理资源的程序执行位置

这个函数仅向目标线程发送一个取消请求 而不会立即终止线程的执行 线程在收到取消请求后 仍然需要在适当的时候检查取消状态 并在取消点终止执行

源码

```c
		/**
		 * 通过pthread_cancel发送取消请求给后台线程来取消后台线程
		 */
        if (bio_threads[j] && pthread_cancel(bio_threads[j]) == 0) {
			/**
			 * pthread_cancel不是同步取消线程的
			 * 通过信号机制向目标线程发送取消请求 因此可以看成异步方式
			 * 这个地方就得阻塞在这等到目标线程真的被取消了
			 */
            if ((err = pthread_join(bio_threads[j],NULL)) != 0) {
                serverLog(LL_WARNING,
                    "Bio thread for job type #%d can not be joined: %s",
                        j, strerror(err));
            } else {
                serverLog(LL_WARNING,
                    "Bio thread for job type #%d terminated",j);
            }
        }
```

### 1.4 pthread_join

POSIX线程库函数 用于等待指定的线程结束 并获取该线程的返回值

调用pthread_join将阻塞当前线程 直到指定线程结束为止

原型

```c
     #include <pthread.h>

     int
     pthread_join(pthread_t thread, void **value_ptr);
```

参数

- thread 指定的线程 当前线程阻塞等待哪个线程结束

- value_ptr 如果不为NULL 则线程的返回值将存储在value_ptr指向的地址中 如果不关心线程的返回值 可以将value_ptr设置为NULL

### 1.5 pthread_setname_np

非标准的POSIX扩展函数 用于设置线程的名称
在标准的POSIX线程库中 并没有提供设置线程名称的函数 但一些操作系统比如Linux提供了这样的扩展函数

原型

```c
#include <pthread.h>

int pthread_setname_np(pthread_t thread, const char* name);
```

参数

- thread 是目标线程的线程id

- name 要设置的线程名称

设置线程名称方便在多线程程序中调试和排查问题

源码

```c
			/**
			 * pthread_cancel不是同步取消线程的
			 * 通过信号机制向目标线程发送取消请求 因此可以看成异步方式
			 * 这个地方就得阻塞在这等到目标线程真的被取消了
			 */
            if ((err = pthread_join(bio_threads[j],NULL)) != 0) {
                serverLog(LL_WARNING,
                    "Bio thread for job type #%d can not be joined: %s",
                        j, strerror(err));
            } else {
                serverLog(LL_WARNING,
                    "Bio thread for job type #%d terminated",j);
            }
```

2 互斥锁
---

### 2.1 pthread_mutex_init

原型是

```c
     #include <pthread.h>

     int
     pthread_mutex_init(pthread_mutex_t *mutex, const pthread_mutexattr_t *attr);
```

参数

- `mutex`指向要初始化的互斥锁的一个指针

- `attr` 指针，指向`pthread_mutexattr_t`类型，用于指定互斥锁的属性，如果传入NULL就是使用默认的属性

### 2.2 pthread_mutex_lock

是POSIX线程库中用来对互斥锁进行加锁操作的函数
它的作用是阻塞当前线程，直到它成功地获取了指定的互斥锁

原型

```c
     #include <pthread.h>

     int
     pthread_mutex_lock(pthread_mutex_t *mutex);
```

- `mutex` 指针 指向要加锁的互斥锁

返回0表示线程成功获取互斥锁，返回非0为错误码，表示线程获取锁失败

源码

```c
	// 当前线程对互斥锁上锁
    pthread_mutex_lock(&bio_mutex[type]);
```


### 2.3 pthread_mutex_unlock

是POSIX线程库中用来释放互斥锁的函数
它的作用是将一个已经被锁住的互斥锁解锁，从而允许其他线程获取该锁

原型

```c
     #include <pthread.h>

     int
     pthread_mutex_unlock(pthread_mutex_t *mutex);
```

- `mutex` 指针 指向要解锁的互斥锁

返回0表示线程释放互斥锁成功，返回非0标识错误码，表示线程释放互斥锁失败

源码

```c
	// 当前线程对互斥锁解锁
    pthread_mutex_unlock(&bio_mutex[type]);
```

3 条件变量
---

### 3.1 pthread_cond_init

用来初始化条件变量，条件变量通常与互斥锁一起使用，用于线程间同步

原型是

```c

     #include <pthread.h>

     int
     pthread_cond_init(pthread_cond_t *cond, const pthread_condattr_t *attr);
```

参数

- `cond` 指针，指向要初始化的条件变量

- `attr` 指针，指向`pthread_condattr_t`类型，用于指定条件变量的属性，传入NULL表示用默认的属性

源码

```c
		/**
		 * 用于初始化条件变量 通常与互斥锁一起使用 用于线程之间的同步
		 * 系统调用的参数
		 * <ul>
		 *   <li>第一个参数 指向要初始化的条件变量</li>
		 *   <li>第二个参数 指定条件变量属性 传入NULL表示使用默认属性</li>
		 * </ul>
		 * 返回0表示初始化成功 返回非0为错误码表示初始化失败
		 */
        pthread_cond_init(&bio_newjob_cond[j],NULL);

```

### 3.2 pthread_cond_signal

POSIX线程库中用来发送信号给等待在条件变量上的一个线程
作用是通知等待中的线程 某个条件可能已经为真 一遍它们可以继续执行

通常情况下用来唤醒一个等待在条件变量上的线程 如果有多个线程在等待条件变量 那么只有一个线程会被唤醒 被唤醒的线程会尝试重新获取相关的互斥锁 然后继续执行

原型

```c
     #include <pthread.h>

     int
     pthread_cond_signal(pthread_cond_t *cond);
```

参数

- cond 指针 指向条件变量

返回值

- 返回0表示成功发送信号

- 返回一个非0的错误码 表示发送信号失败

源码

```c
	/**
	 * 随机唤醒一个当初阻塞在条件队列上的线程 让它继续执行
	 * 典型的生产者消费者模型
	 * 有任务队列空了的时候工作线程会阻塞等待直到有任务到来
	 *
	 * pthread_cond_signal系统调用是POSIX线程库中用来发送信号给等待在条件变量上的一个线程的函数
	 * 作用是通知等待中的线程 某个条件可能已经变为真 以便它们可以继续执行
	 * 通常情况用来唤醒一个等待在条件变量上的线程 如果有多个线程等待在条件变量上 那么只有一个线程会被唤醒 被唤醒的线程会尝试重新获取相关的互斥锁 然后继续执行
	 */
    pthread_cond_signal(&bio_newjob_cond[type]);
```

### 3.3 pthread_cond_broadcast

POSIX线程库中用来发送信号给等待在条件变量上的所有线程的函数

作用是通知所有等待中的线程 某个条件可能已经变成真 以便它们可以继续执行

通常用于在一组线程等待相同条件变量时 一次性地唤醒所有等待的线程 每个被唤醒的线程会尝试重新获取相关的互斥锁 然后继续执行

原型

```c
     #include <pthread.h>

     int
     pthread_cond_broadcast(pthread_cond_t *cond);
```

参数

- `cond` 指针 指向条件变量

返回值

- 0表示成功发送信号

- 非0错误码 表示发送信号失败

### 3.4 pthread_cond_wait

用于等待条件变量的信号

原型

```c
     #include <pthread.h>

     int
     pthread_cond_wait(pthread_cond_t *cond, pthread_mutex_t *mutex);
```

调用该函数会将当前线程挂起 直到条件变量`cond`被其他线程发送信号为止

在调用函数之前 必须先获取互斥锁`mutex` 以确保在等待条件变量时的线程安全

在函数返回时 会自动释放`mutex` 并重新获取它 以确保在返回时保持互斥锁的状态

源码

```c
		/**
		 * 唤醒所有阻塞在条件队列上的线程 唤醒它们重新竞争互斥锁
		 */
        pthread_cond_broadcast(&bio_step_cond[type]);
```
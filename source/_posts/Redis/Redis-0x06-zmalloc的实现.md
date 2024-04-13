---
title: Redis-0x06-zmalloc的实现
category_bar: true
date: 2024-04-13 22:28:06
categories: Redis
---

> 前文了解了为何redis需要抽象一层内存管理器，以及redis是怎么做的跨平台兼容。

> 这个章节尝试跟着zmalloc的代码进行逐行学习，整个zmalloc.c源文件700+行，再除去注释和换行等，实际代码规模不大，因此计划以函数为粒度进行解读和学习。

1 ASSERT_NO_SIZE_OVERFLOW
---

> 这是一个断言函数，这个函数存在的目的也是为了跨平台兼容。

```c
/**
 * PREFIX_SIZE是内存前缀 这个内存前缀是redis级别的 目的是为了知道redis从OS系统真实获得(或者近似真实获得)了多少内存
 *   <li>对于已经有malloc_size支持的内存分配器 有直接库函数知道redis从OS获取到的真实内存大小 所以不需要redis额外负担记录的职责<li>
 *   <li>对于没有malloc_size redis只能自己负担这个记录工作 但是因为没有OS帮助 是不知道OS分配的真实内存大小 只能靠redis记下自己主动申请了多少空间</li>
 * 因此在第二种情况下 redis就要评估到底需要多大的额外空间来记录内存大小 这个值大小肯定依赖malloc接受的入参 又跟机器的字宽有直接关系
 * 但是不论怎样 肯定是一个unsigned的整数 并且PREFIX_SIZE肯定得>0
 * 此时redis期待向OS申请的内存大小就是sz+PREFIX_SIZE 两个unsigned整数相加就可能存在整数溢出的情况 如果溢出了那么两数求和就是负数
 *
 * 因此ASSERT_NO_SIZE_OVERFLOW断言的就是判断要向malloc申请的内存大小没有超过malloc能够分配的上限 即没有溢出
 */
#ifdef HAVE_MALLOC_SIZE
#define PREFIX_SIZE (0)
/* 内存分配器支持malloc_size 不需要redis自己负担前缀内存来记录大小 因此也size_t类型本身就是malloc函数接受的类型 直接传给malloc即可 即不需要对参数判断 因此断言函数是空的 */
#define ASSERT_NO_SIZE_OVERFLOW(sz)

#else
#if defined(__sun) || defined(__sparc) || defined(__sparc__)
#define PREFIX_SIZE (sizeof(long long))
#else
#define PREFIX_SIZE (sizeof(size_t))
#endif
/* 内存分配器不支持malloc_size 需要redis自己负担前缀内存来记录大小 因此总共期待申请的内存大小是sz+PREFIX_SIZE 此时就要判断这个和是否溢出了size_t类型的整数大小 */
#define ASSERT_NO_SIZE_OVERFLOW(sz) assert((sz) + PREFIX_SIZE > (sz))

#endif
```

2 used_memory
---

> redis记录用了OS系统的内存空间大小。

```c
 /**
  * redis侧记录使用的内存大小
  * <ul>
  *   <li>编译环境有malloc_size支持的情况下 记录的就是OS实实在在分配给redis的内存大小 也就是redis真实用了多少空间</li>
  *   <li>编译环境没有malloc_size支持的情况下 记录的就是redis实际向OS申请的内存大小 OS实际分配给redis的空间>=这个值 因此这种情况下记录的`使用空间`就是实际被分配的约数</li>
  * </ul>
  * 为什么要定义成原子变量
  * 我现在的认知是虽然redis的IO操作(即面向用户的存取操作)是单线程
  * 但是redis还会开启新线程处理后台任务或者非用户层的存取任务
  * 那么就可能面临并发更新这个内存值的情况
  */
static redisAtomic size_t used_memory = 0;
```

对这个变量的操作无非就是加或者减：

### 2.1 申请了新内存空间

```c
 /* 原子更新使用内存 malloc申请完之后 加上新分配的空间大小 */
#define update_zmalloc_stat_alloc(__n) atomicIncr(used_memory,(__n))
```

### 2.2 释放了内存空间

```c
/* 原子更新使用内存 free释放完之后 减去释放的空间大小 */
#define update_zmalloc_stat_free(__n) atomicDecr(used_memory,(__n))
```

3 内存分配失败处理器
---

```c
// 定义函数指针 指针变量指向的函数在发生OOM时被调用 则该函数就是名义上的OOM处理器
// 决定了发生内存OOM时怎么处理
static void (*zmalloc_oom_handler)(size_t) = zmalloc_default_oom;

// 内存OOM处理器-默认处理器
static void zmalloc_default_oom(size_t size) {
    fprintf(stderr, "zmalloc: Out of memory trying to allocate %zu bytes\n",
        size);
    fflush(stderr);
    abort();
}
```

如果对默认的处理器不甚满意，则可以对这个函数指针变量进行赋值，按照处理器函数的原型自定义一个函数，之后发生OOM时便可以回调到自定义的处理器。

```c
/**
 * 注册内存OOM回调函数
 * @param oom_handler 函数指针 发生OOM时的处理器
 */
void zmalloc_set_oom_handler(void (*oom_handler)(size_t)) {
    zmalloc_oom_handler = oom_handler;
}
```

4 malloc的封装
---

### 4.1 trymalloc_usable

> 不处理OOM 关注内存块大小

```c
/* Try allocating memory, and return NULL if failed.
 * '*usable' is set to the usable size if non NULL. */
/**
 * 尝试动态内存分配
 * 分配失败就返回NULL
 * @param size 期待申请的内存大小
 * @param usable 在内容申请成功的前提下 表示成功申请下来的内存块大小(设为n) 可能存在两种情况
 *        <ul>
 *          <li>n>=申请的大小</li>
 *          <li>n==申请的大小</li>
 *        </ul>
 * @return 可以使用的起始地址 用来存取用户数据
 */
void *ztrymalloc_usable(size_t size, size_t *usable) {
  /**
   * 这个断言函数我觉得真实精妙
   * 判定一个类型的数数否溢出的思路
   */
    ASSERT_NO_SIZE_OVERFLOW(size);
	/**
	 * 调用malloc通过内存分配器向OS申请内存
	 */
    void *ptr = malloc(MALLOC_MIN_SIZE(size)+PREFIX_SIZE);

    if (!ptr) return NULL;
#ifdef HAVE_MALLOC_SIZE
	// 有malloc_size库函数支持 直接获取申请到的内存块的实际大小 更新使用内存 加上新分配的大小
    size = zmalloc_size(ptr);
    update_zmalloc_stat_alloc(size);
	// 内存块实际大小(该值>=申请的大小)
    if (usable) *usable = size;
	// malloc给的指针已经指向了给用户使用的起始地址
    return ptr;
#else
  // 没有有malloc_size库函数支持 更新使用内存 加上新申请的大小
  // 使用内存块的前缀空间记录这个内存块的大小(理论上应该记录实际大小 但是无从获取 因此只能记录期待申请的大小)
    *((size_t*)ptr) = size;
    update_zmalloc_stat_alloc(size+PREFIX_SIZE);
	// 内存块的近似大小(该值==申请的大小)
    if (usable) *usable = size;
	// 自己空出前缀空间 模拟malloc的实现 将指针指向给用户使用的起始地址
    return (char*)ptr+PREFIX_SIZE;
#endif
}
```

### 4.2 zmalloc_usable

> 处理OOM 关注内存块大小

```c
/**
 * 对malloc的封装
 * 尝试动态分配内存 并获取到内存块大小
 * 如果OOM了也要进行处理
 */
void *zmalloc_usable(size_t size, size_t *usable) {
    void *ptr = ztrymalloc_usable(size, usable);
    if (!ptr) zmalloc_oom_handler(size);
    return ptr;
}
```

### 4.3 ztry_malloc

> 不处理OOM 不关注内存块大小

```c
/**
 * 对malloc的封装
 * 尝试动态分配内存
 * 如果OOM了也直接交给上层关注
 */
void *ztrymalloc(size_t size) {
    void *ptr = ztrymalloc_usable(size, NULL);
    return ptr;
}
```

### 4.4 zmalloc

> 处理OOM 关注内存块大小

```c
/**
 * 对malloc的封装
 * 如果OOM要对OOM进行处理
 */
void *zmalloc(size_t size) {
    // 尝试申请内存 并不关注获得的内存块大小
    void *ptr = ztrymalloc_usable(size, NULL);
	// 内存分配失败 回调处理器处理OOM
    if (!ptr) zmalloc_oom_handler(size);
    return ptr;
}
```

如上，其实就是统一对malloc的封装，按照场景需求分为两类

- 是否需要OOM处理

- 是否关注内存块大小

那么二者组合情况就有4种

- 处理OOM 关注内存块 则不带try带usable

- 处理OOM 不关注内存块 则不带try不带usable

- 不处理OOM 关注内存块 则带try带usable

- 不处理OOM 不关注内存块 则带try不带usable

5 malloc系列
---

> 根据上述的命名方式，结合malloc、calloc、realloc三者之间的区别，其他的函数基本不用看也知道该怎么封装了。

| malloc           | 处理OOM        | 不处理OOM         |
|------------------|----------------|-------------------|
| 关注内存块大小   | zmalloc_usable | ztrymalloc_usable |
| 不关注内存块大小 | zmalloc        | ztrymalloc        |

| calloc           | 处理OOM        | 不处理OOM         |
|------------------|----------------|-------------------|
| 关注内存块大小   | zcalloc_usable | ztrycalloc_usable |
| 不关注内存块大小 | zcalloc        | ztrycalloc        |

| realloc          | 处理OOM         | 不处理OOM          |
|------------------|-----------------|--------------------|
| 关注内存块大小   | zrealloc        | ztryrealloc_usable |
| 不关注内存块大小 | zrealloc_usable | ztryrealloc        |

6 zfree的封装
---

### 6.1 zfree

```c
/**
 * 对free(...)函数的封装
 * <ul>
 *   <li>更新内存使用量 要释放的内存块对应的内存块大小要扣减掉</li>
 *   <li>向OS申请释放内存</li>
 * </ul>
 * 要更新内存使用量 就要知道内存块大小 此时也更加印证了PREFIX_SIZE的重要性 正式因为PREFIX_SIZE统一了跟OS系统一样的内存块大小机制 大大简化了整个的内存使用量统计操作
 */
void zfree(void *ptr) {
#ifndef HAVE_MALLOC_SIZE
    void *realptr;
    size_t oldsize;
#endif

    if (ptr == NULL) return;
#ifdef HAVE_MALLOC_SIZE
	// 更新内存使用量 释放掉的内存量
    update_zmalloc_stat_free(zmalloc_size(ptr));
	// 释放
    free(ptr);
#else
	// 前移前缀空间 这个地方才是OS视角的use_ptr
    realptr = (char*)ptr-PREFIX_SIZE;
	// 前缀空间上存储的内存大小
    oldsize = *((size_t*)realptr);
	// 更新内存使用量 释放掉的内存量
    update_zmalloc_stat_free(oldsize+PREFIX_SIZE);
	// 释放
    free(realptr);
#endif
}
```

对于PREFIX_SIZE机制，可以借助下图来理解:

比如我们作为用户进程向OS申请了sz大小的内存

- 先看红色字体，从OS视角来看 实际分配的内存块比sz更大。这个内存块的起始地址是real，因为要记录一些元信息，因此给到我们的是use的起始地址。

- 再从用户视角来看，我们以为这个内存地址就是从use开始的，并且真个分配到的内存只有sz，起始可能可用的比sz还要大一点。

- 其次再看蓝色字体，就是在redis层面模拟OS的这样机制，我们也额外负担一点内存空间来模拟存储内存块大小。

我觉得这样用一点空间换取来的是api和算法的统一，也让维护的内存使用量具有实际意义。

![](Redis-0x06-zmalloc的实现/IMG_B9C8F5A5AE81-1.jpeg)

### 6.2 zfree_usable

```c
/* Similar to zfree, '*usable' is set to the usable size being freed. */
// 同zfree 只是将待释放的内存块大小返回出来
void zfree_usable(void *ptr, size_t *usable) {
#ifndef HAVE_MALLOC_SIZE
    void *realptr;
    size_t oldsize;
#endif

    if (ptr == NULL) return;
#ifdef HAVE_MALLOC_SIZE
    update_zmalloc_stat_free(*usable = zmalloc_size(ptr));
    free(ptr);
#else
    realptr = (char*)ptr-PREFIX_SIZE;
    *usable = oldsize = *((size_t*)realptr);
    update_zmalloc_stat_free(oldsize+PREFIX_SIZE);
    free(realptr);
#endif
}
```

7 zstrdup
---

```c
/**
 * 复制字符串
 * 实现很简单 但是我不太理解为啥把这个函数放在zmalloc
 */
char *zstrdup(const char *s) {
    // 字符串长度 多一个byte放\0结束符
    size_t l = strlen(s)+1;
    char *p = zmalloc(l);

    memcpy(p,s,l);
    return p;
}
```

8 zmalloc_used_memory
---

```c
// 内存使用量
size_t zmalloc_used_memory(void) {
    size_t um;
	// 读取used_memory变量的值
    atomicGet(used_memory,um);
    return um;
}
```

9 zmalloc_get_rss
---

> 上面提到过redis自己在服务端维护了变量`used_memory`，其约等于OS系统实际分配的内存空间。

> 现在要获取redis进程在OS系统中驻留的内存空间，系统给进程分配了内存之后，为了使用效率提升，可能会将一部分不常使用的空间放到swap交换区去，那么物理内存的驻留空间实际是减少的，可以提升内存的使用效率。

RSS=Resident Set Size

从描述也可以看得出来，RSS的获取依赖各个系统的实现，因此redis就要进行跨平台的封装。

因为我常用的系统只有mac和linux，所以这两个平台上的实现方式可以跟到函数详细研究，其他平台就粗略看一下。

### 9.1 linux

在正式看redis的函数之前，回忆一些常用操作和知识作为铺垫。

#### 9.1.1 strchr(...)

这个函数就是给定一个字符串，给定一个目标字符，函数会找到在这个字符串中第一次出现目标字符的地方。

![](Redis-0x06-zmalloc的实现/9929901699585153.png)

#### 9.1.2 strtol系列函数

将字符串形式的数字转换成指定进制表达的整数形式。

![](Redis-0x06-zmalloc的实现/6591261699585265.png)

#### 9.1.3 sysconf(...)

系统进程的运行时信息sysconf(_SC_PAGESIZE)就是获取到内存页的一页有多少byte，比如一页4k就是4096byte。

![](Redis-0x06-zmalloc的实现/8836931699585757.png)

#### 9.1.4 RSS


#### 9.1.5 zmalloc_get_rss实现

至此，我们再来看redis中如何获取rss的，就会十分轻松。

```c
/* Test for proc filesystem */
// linux系统上运行时的指标都从/proc虚拟文件系统上拿
#ifdef __linux__
/* linux系统从/proc虚拟文件系统获取RSS /proc/{pid}/stat 的第24项就是RSS(驻留物理内存多少个page) */
#define HAVE_PROC_STAT 1
```

```c
/**
 * linux系统的/proc虚拟文件系统
 * 在linux上想要知道某个进程的实际内存占用很简单 使用top命令即可 其中RES就是内存驻留(不包含swap交换内存) 单位是kb
 * 具体到某个进程的运行时信息存储在文件/proc/{pid}/stat上 这个文件内容每个指标项通过空格作为分割符 第24个就是RSS指标 单位是页
 * 因此linux系统某个进程的RSS就是直接读这个文件即可
 */
#if defined(HAVE_PROC_STAT)
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

size_t zmalloc_get_rss(void) {
    // 页大小(单位是bytes) 下面要去读/proc/{pid}/stat获取RSS大小 得到的是页数
	// 结果是4096 byte
    int page = sysconf(_SC_PAGESIZE);
    size_t rss;
    char buf[4096];
    char filename[256];
    int fd, count;
    char *p, *x;
	// 虚拟文件系统的文件路径/proc/{pid}/stat
    snprintf(filename,256,"/proc/%ld/stat",(long) getpid());
	// 文件不存在
    if ((fd = open(filename,O_RDONLY)) == -1) return 0;
	// 文件内容读到buf数组中 读完关闭文件
    if (read(fd,buf,4096) <= 0) {
        close(fd);
        return 0;
    }
    close(fd);

    p = buf;
	// 各个指标用空格作为分割符 第24个就是RSS指标
    count = 23; /* RSS is the 24th field in /proc/<pid>/stat */
    while(p && count--) {
        p = strchr(p,' ');
        if (p) p++;
    }
    if (!p) return 0;
	// 找到第24项和25项之间的空格 人为将其改成\0结束符 目的是让函数strtoll(...)将第24项字符串形式转成整数形式
    x = strchr(p,' ');
    if (!x) return 0;
    *x = '\0';
	// 将第24项的RSS字符串形式转换成10进制整数形式(long long类型)
    rss = strtoll(p,NULL,10);
	// rss页*每页page个byte
    rss *= page;
    return rss;
}
```

### 9.2 mac

```c
/* 苹果系统依赖的是微内核mach的实现 但是我没有找到对应的手册说明 也就无从谈起解读 只能说如果可以学习redis 如果有一天自己要在mac上获取进程的RSS信息 可以用它的方式 */
#elif defined(HAVE_TASKINFO)
#include <sys/types.h>
#include <sys/sysctl.h>
#include <mach/task.h>
#include <mach/mach_init.h>

size_t zmalloc_get_rss(void) {
    task_t task = MACH_PORT_NULL;
    struct task_basic_info t_info;
    mach_msg_type_number_t t_info_count = TASK_BASIC_INFO_COUNT;

    if (task_for_pid(current_task(), getpid(), &task) != KERN_SUCCESS)
        return 0;
    task_info(task, TASK_BASIC_INFO, (task_info_t)&t_info, &t_info_count);

    return t_info.resident_size;
}
```

10 zmalloc_get_allocator_info
---

这个函数特定的功能相当于是jemalloc提供的特定场景支持，因此当内存分配器不是指定的jemalloc时候，这个功能会被阉割掉。

- 有jemalloc支持，linux默认会指定jemalloc作为内存分配器

- 没有jemalloc支持

### 10.1 有jemalloc的环境

涉及到jemalloc系列函数，先看一下redis是如何整合jemalloc到项目中的


```c
/**
 * 通过Makefile的跟踪和https://github.com/jemalloc/jemalloc/blob/dev/INSTALL.md
 * 知道的是jemalloc提供的系列函数都指定了je_作为前缀
 * 那么反推这里的je_mallctl就是mallctl的实现
 * 所以只要搞明白mallctl的作用即可
 * mallctl(name, oldp, oldlenp, newp, newlen)
 * 即mallctl会将要查询的name的结果放到oldp指针变量
 */
int zmalloc_get_allocator_info(size_t *allocated,
                               size_t *active,
                               size_t *resident) {
    uint64_t epoch = 1;
    size_t sz;
    *allocated = *resident = *active = 0;
    /* Update the statistics cached by mallctl. */
    sz = sizeof(epoch);
    je_mallctl("epoch", &epoch, &sz, &epoch, sz);
    sz = sizeof(size_t);
    /* Unlike RSS, this does not include RSS from shared libraries and other non
     * heap mappings. */
    je_mallctl("stats.resident", resident, &sz, NULL, 0);
    /* Unlike resident, this doesn't not include the pages jemalloc reserves
     * for re-use (purge will clean that). */
    je_mallctl("stats.active", active, &sz, NULL, 0);
    /* Unlike zmalloc_used_memory, this matches the stats.resident by taking
     * into account all allocations done by this process (not only zmalloc). */
    je_mallctl("stats.allocated", allocated, &sz, NULL, 0);
    return 1;
}
```

### 10.2 没有jemalloc的环境

```c
/**
 * 内存分配器不是jemalloc 没有查询接口支持
 * <li>allocated</li>
 * <li>active</li>
 * <li>resident</li>
 * 这3个值给定0 在使用的时候以0为判定分支
 */
#else

int zmalloc_get_allocator_info(size_t *allocated,
                               size_t *active,
                               size_t *resident) {
    *allocated = *resident = *active = 0;
    return 1;
}
```

11 set_jemalloc_bg_thread
---

这个函数同样依赖jemalloc的`mallctl`支持。

### 11.1 有jemalloc的环境

```c
void set_jemalloc_bg_thread(int enable) {
    /* let jemalloc do purging asynchronously, required when there's no traffic
     * after flushdb */
    char val = !!enable;
    je_mallctl("background_thread", NULL, 0, &val, 1);
}
```

### 11.2 没有jemalloc的环境

```c
// 没有使用jemalloc 函数相当于空实现
void set_jemalloc_bg_thread(int enable) {
    ((void)(enable));
}
```

12 jemalloc_purge
---

这个函数同样依赖jemalloc的`mallctl`支持。

### 11.1 有jemalloc的环境

```c
int jemalloc_purge() {
    /* return all unused (reserved) pages to the OS */
    char tmp[32];
    unsigned narenas = 0;
    size_t sz = sizeof(unsigned);
	// mallctl
    if (!je_mallctl("arenas.narenas", &narenas, &sz, NULL, 0)) {
        sprintf(tmp, "arena.%d.purge", narenas);
        if (!je_mallctl(tmp, NULL, 0, NULL, 0))
            return 0;
    }
    return -1;
}
```

### 11.2 没有jemalloc的环境

```c
// 没有使用jemalloc 函数相当于空实现
int jemalloc_purge() {
    return 0;
}
```

13 zmalloc_get_private_dirty
---

本质是对`zmalloc_get_smap_bytes_by_field`的调用，而`zmalloc_get_smap_bytes_by_field`需要依赖OS的系统调用，这个地方redis并没有对全平台做兼容实现，只关注了linux和mac。

同之前的RSS指标采集一样：

- linux系统的指标从proc虚拟文件系统采集

- mac系统的指标依赖mach微内核的系统调用

### 13.1 mac系统

```c
/**
 *
 * @param field 字符串 要查询的指标项
 * 	            <ul>
 * 	              <li>Private_Dirty:</li>
 * 	              <li>Rss:</li>
 * 	              <li>AnonHugePages:</li>
 * 	            </ul>
 * @param pid
 * @return 空间大小(byte)
 */
size_t zmalloc_get_smap_bytes_by_field(char *field, long pid) {
    // mac系统
#if defined(__APPLE__)
    struct proc_regioninfo pri;
    if (pid == -1) pid = getpid();
	// 跟RSS一样 mac的指标获取依赖的是mach微内核的系统调用
	// proc_pidinfo函数结果pri中的空间大小计量单位 跟linux系统的proc虚拟文件系统指标一样都是以page为计量单位
    if (proc_pidinfo(pid, PROC_PIDREGIONINFO, 0, &pri,
                     PROC_PIDREGIONINFO_SIZE) == PROC_PIDREGIONINFO_SIZE)
    {
	  	// 页大小 1页=4k=4096byte
        int pagesize = getpagesize();
        if (!strcmp(field, "Private_Dirty:")) {
            return (size_t)pri.pri_pages_dirtied * pagesize;
        } else if (!strcmp(field, "Rss:")) {
            return (size_t)pri.pri_pages_resident * pagesize;
        } else if (!strcmp(field, "AnonHugePages:")) {
            return 0;
        }
    }
    return 0;
#endif
    // 不是linux系统也不是mac系统
    ((void) field);
    ((void) pid);
    return 0;
}
#endif
```

### 13.2 linux系统

跟RSS一样，`cat /proc/4649/smaps >> Desktop/smap.txt`，看一下文件的内容就可以非常简易地了解代码的实现。

![](Redis-0x06-zmalloc的实现/2023-11-15_10-59-05.png)

```c
/*
 * linux系统通过proc虚拟文件系统获取smaps
 */
#if defined(HAVE_PROC_SMAPS)
/**
 *
 * @param field 字符串 要查询的指标项
 * 	            <ul>
 * 	              <li>Private_Dirty:</li>
 * 	              <li>Rss:</li>
 * 	              <li>AnonHugePages:</li>
 * 	            </ul>
 * @param pid 进程(线程)
 * @return 空间大小(byte)
 */
size_t zmalloc_get_smap_bytes_by_field(char *field, long pid) {
    // 缓存文件中每一行的读取信息
    char line[1024];
    size_t bytes = 0;
    int flen = strlen(field);
    FILE *fp;

	// /proc/{pid}/smaps文件
    if (pid == -1) {
        fp = fopen("/proc/self/smaps","r");
    } else {
        char filename[128];
        snprintf(filename,sizeof(filename),"/proc/%ld/smaps",pid);
        fp = fopen(filename,"r");
    }
	// 文件打开失败
    if (!fp) return 0;
	// 逐行读取文件 截取文件中要找的几行如下
	// Private_Dirty:         0 kB
	// Rss:                  16 kB
	// AnonHugePages:         0 kB
    while(fgets(line,sizeof(line),fp) != NULL) {
	    /**
	     * 指标项有3中可能性
	     * <ul>
	     *   <li>Private_Dirty:</li>
	     *   <li>Rss:</li>
	     *   <li>AnonHugePages:</li>
	     * </ul>
	     */
        if (strncmp(line,field,flen) == 0) {
		    // 找到了对应要找的指标那一行 找到kb的k所在位置 人为改成字符串结束符
			// 然后将计量单位前面的数字从字符串转整型
			// 截取的范围是冒号(:)之后到k(kb的k)之前这一段包含空格和数字的内容
            char *p = strchr(line,'k');
            if (p) {
                *p = '\0';
				// 多少个byte
                bytes += strtol(line+flen,NULL,10) * 1024;
            }
        }
    }
    fclose(fp);
    return bytes;
}
```
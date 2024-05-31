---
title: Redis-0x1B-库函数文件操作
category_bar: true
date: 2024-05-28 10:45:30
categories: Redis
---

1 stat
---

这个函数用于获取指定文件的信息

### 1.1 原型

```c
     #include <sys/stat.h>

     int
     fstat(int fildes, struct stat *buf);

     int
     lstat(const char *restrict path, struct stat *restrict buf);

     int
     stat(const char *restrict path, struct stat *restrict buf);

     int
     fstatat(int fd, const char *path, struct stat *buf, int flag);
```

### 1.2 入参

- path 文件路径

- buf 指针 指向stat类型 用于存储文件信息


### 1.3 返回值

- 0表示成功

- -1表示失败

2 fread
---

从文件读到内存中

### 2.1 原型

```c
     #include <stdio.h>

     size_t
     fread(void *restrict ptr, size_t size, size_t nitems, FILE *restrict stream);
```

### 2.2 入参

- ptr 指向内存空间

- size 每个读取元素粒度 比如读的是字符 就是1Byte

- items 读取多少个元素

- stream 从哪儿堵 指向磁盘文件

### 2.3 返回值

读到了多少byte的内容

### 2.4 源码

```c
    if (fread(sig,1,5,fp) != 5 || memcmp(sig,"REDIS",5) != 0)
```

3 fseek
---

重置游标

### 3.1 原型

```c
     #include <stdio.h>

    int
    fseek(FILE *stream, long offset, int whence);
```

### 3.2 入参

- stream 文件流

- offset 游标偏移到什么位置

- whence 当设置SEEK_SET SEEK_CUR SEEK_END的时候 offset是相对于文件起始点的位置

### 3.3 返回值

- 0 表示成功

- -1 表示失败

### 3.4 源码

```c
		// 上面用fread读了5个字节的内容 现在需要把游标重置到起点处
        if (fseek(fp,0,SEEK_SET) == -1) goto readerr;
```

4 ftello
---

ftello是对ftell的扩展 提供对大文件的支持

用于获取文件流的当前位置

### 4.1 原型

```c
     #include <stdio.h>
     off_t
     ftello(FILE *stream);
```

### 4.2 入参

- stream 指针 指向`FILE`类型 要操作的文件流

### 4.3 出参

- -1 表示失败

- 非-1 表示文件流的当前文件位置 以字节为单位

### 4.4 源码

```c
			// ftello是对ftell的升级 支持大文件 拿到文件流当前文件位置
            loadingProgress(ftello(fp));
```

5 fgets
---

用于从指定的文件流读取一行字符
它读取字符并存储到指定的字符串中

直到以下几种情况为止

- 读取到一个新行字符

- 达到文件末尾

- 达到最大读取字符数(包括终止的空字符)

fgets非常适合用于逐行读取文件内容尤其在处理文本文件时

### 5.1 原型

```c
     #include <stdio. h>

     char *
     fgets(char * restrict str, int size, FILE * restrict stream);
```

### 5.2 入参

- str 指向字符数组的指针 存储读取到的字符串

- size 要读取的最大字符数

- stream 要读取的文件流

### 5.3 返回

- 成功 指向str指针

- 失败或到达文件末尾 返回NULL

### 5.4 源码

```c
        if (fgets(buf,sizeof(buf),fp) == NULL)
```
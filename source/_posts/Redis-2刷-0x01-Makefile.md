---
title: Redis-2刷-0x01-Makefile
date: 2023-11-01 21:58:21
categories: [ 'Redis' ]
tags: [ '2刷Redis' ]
---

Redis以make作为项目构建管理工具，因此我们只要看Makefile的rule编写，就知道编译源码的过成了。况且每个人编写Makefile的习惯各样，也可以借此良机借鉴风格。

1 项目编译
---

首先，在Readme中作者描述了如何编译项目，即在项目根目录执行`make`。

![](Redis-2刷-0x01-Makefile/2023-11-01_22-19-29.png)

2 根目录Makefile
---

根据编译命令可知，我们只要关注当前文件的第一条rule即可，如下：

```Makefile
# Top level makefile, the real shit is at src/Makefile

# 执行make的时候找到的第一个target是default 该target依赖一个dependency为all
# 但是该Makefile中没有再定义为all的target 即make找不到叫all的target
# 在这种情况下make会执行.DEFAULT
default: all

# 因为make的执行是从default作为入口下来的
# 因此$@指代的是all
# 也就是说要执行的shell是cd src && make all
.DEFAULT:
	cd src && $(MAKE) $@
```

关于make的规则，可以参考[官网的文档](https://www.gnu.org/savannah-checkouts/gnu/make/manual/make.html)。

3 src目录下Makefile
---
```Makefile
# redis源码根目录下makefile中的cd src && make all
# MakeFile真正工作的地方
all: $(REDIS_SERVER_NAME) $(REDIS_SENTINEL_NAME) $(REDIS_CLI_NAME) $(REDIS_BENCHMARK_NAME) $(REDIS_CHECK_RDB_NAME) $(REDIS_CHECK_AOF_NAME)
	@echo ""
	@echo "Hint: It's a good idea to run 'make test' ;)"
	@echo ""
```



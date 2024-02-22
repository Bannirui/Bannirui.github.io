---
title: Redis-2刷-0x14-cmake构建项目
date: 2024-02-21 19:27:13
categories: Redis
tags: 2刷Redis
---

Redis项目是通过make构建的，考虑到以下几点，我觉得有必要通过cmake脚本生成MakeFile

- cmake的跨平台性

- 源码的结构自定义组织

但是reids项目本身为了兼容跨平台性以及性能优化，提供了诸多的编译选项，我当前的cmake脚本只关注linux平台

- linux系统

- jemalloc内存分配器

### 1 项目结构

![](./Redis-2刷-0x14-cmake构建项目/1708518055.png)

项目的构建分为两个部分

- 依赖的3rd_party编译，将其编译位链接库

- 源码，将其编译位可执行程序

### 2 make

之前看过了MakeFile的rule，{% post_link Redis-2刷-0x01-Makefile %}

### 3 cmake脚本编写

为了尽可能的简单，因此只关注于linux平台，并且当前只编写了编译redis-server可执行程序的脚本

从MakeFile中可以看出来redis工程共提供了如下6个可执行程序的编译

- redis-server

- redis-sentinel

- redis-check-rdb

- redis-check-aof

- redis-cli

- redis-benchmark

#### 3.1 根目录

##### 3.1.1 CmakeLists.txt文件

负责源码的编译以及链接库

```CMakeLists
cmake_minimum_required(VERSION 3.28.0)
project(redis_6.2 C)

#[[
1 redis源码
2 前置依赖脚本
3 编译成可执行程序redis-server
4 依赖3rd库 libhiredis.a liblua.a libjemalloc.a
5 系统库
6 链接库
]]

#执行shell
execute_process(
    COMMAND sh ${CMAKE_CURRENT_SOURCE_DIR}/src/mkreleasehdr.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/src
)

#系统库
set(SYS_LIB -lm -latomic -ldl -lnsl -lresolv -lpthread -lrt -lcrypt -lbsd)

#redis-server的源码文件
set(REDIS_SERVER_SRC
src/adlist.c
src/quicklist.c
src/ae.c
src/anet.c
src/dict.c
src/server.c
src/sds.c
src/zmalloc.c
src/lzf_c.c
src/lzf_d.c
src/pqsort.c
src/zipmap.c
src/sha1.c
src/ziplist.c
src/release.c
src/networking.c
src/util.c
src/object.c
src/db.c
src/replication.c
src/rdb.c
src/t_string.c
src/t_list.c
src/t_set.c
src/t_zset.c
src/t_hash.c
src/config.c
src/aof.c
src/pubsub.c
src/multi.c
src/debug.c
src/sort.c
src/intset.c
src/syncio.c
src/cluster.c
src/crc16.c
src/endianconv.c
src/slowlog.c
src/scripting.c
src/bio.c
src/rio.c
src/rand.c
src/memtest.c
src/crcspeed.c
src/crc64.c
src/bitops.c
src/sentinel.c
src/notify.c
src/setproctitle.c
src/blocked.c
src/hyperloglog.c
src/latency.c
src/sparkline.c
src/redis-check-rdb.c
src/redis-check-aof.c
src/geo.c
src/lazyfree.c
src/module.c
src/evict.c
src/expire.c
src/geohash.c
src/geohash_helper.c
src/childinfo.c
src/defrag.c
src/siphash.c
src/rax.c
src/t_stream.c
src/listpack.c
src/localtime.c
src/lolwut.c
src/lolwut5.c
src/lolwut6.c
src/acl.c
src/gopher.c
src/tracking.c
src/connection.c
src/tls.c
src/sha256.c
src/timeout.c
src/setcpuaffinity.c
src/monotonic.c
src/mt19937-64.c
)

#external 3rd库
add_subdirectory(deps)

#3rd头文件路径
set(DEPS_HEADER_PATH ${CMAKE_CURRENT_SOURCE_DIR}/deps)
include_directories(${DEPS_HEADER_PATH}/hdr_histogram)
include_directories(${DEPS_HEADER_PATH}/hiredis)
include_directories(${DEPS_HEADER_PATH}/jemalloc/include)
include_directories(${DEPS_HEADER_PATH}/linenoise)
include_directories(${DEPS_HEADER_PATH}/lua/src)

#3rd库路径
set(DEPS_LIB_PATH ${CMAKE_CURRENT_BINARY_DIR}/deps)
link_directories(${DEPS_LIB_PATH}/hdr_histogram)
link_directories(${DEPS_LIB_PATH}/hiredis)
link_directories(${DEPS_LIB_PATH}/jemalloc)
link_directories(${DEPS_LIB_PATH}/linenoise)
link_directories(${DEPS_LIB_PATH}/lua)

add_executable(redis-server ${REDIS_SERVER_SRC})

#链接库文件
target_link_libraries(redis-server
    hiredis
    lua
    jemalloc
    ${SYS_LIB}
)
```

##### 3.1.2 configure.sh文件

执行cmake脚本生成Makefile

```shell
#!/bin/sh

cmake -S . -B build
```

##### 3.1.3 build.sh文件

执行make

```shell
#!/bin/sh

cd build ; make
```

##### 3.1.4 run.sh文件

运行redis-server可执行程序

```shell
#!/bin/sh

cd build ; ./redis-server
```

#### 3.2 deps目录

负责编译3rd_party的依赖

```CMakeLists
add_subdirectory(hdr_histogram)
add_subdirectory(hiredis)
add_subdirectory(jemalloc)
add_subdirectory(linenoise)
add_subdirectory(lua)
```

##### 3.2.1 deps/hdr_histogram

```CMakeLists
add_library(hdr_histogram
    hdr_histogram.h hdr_histogram.c
)
```

##### 3.2.2 deps/hiredis

hiredis本身就是cmake项目，因此不需要额外编写cmake脚本

##### 3.2.3 deps/jemalloc

###### 3.2.3.1 sh脚本

```shell
#!/bin/sh

./configure --with-version=5.1.0-0-g0 --with-lg-quantum=3 --with-jemalloc-prefix=je_
make lib/libjemalloc.a
```

###### 3.2.3.2 cmake脚本

```CMakeLists
execute_process(
    COMMAND bash "${CMAKE_CURRENT_SOURCE_DIR}/build_jemalloc.sh"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)

file(COPY lib/libjemalloc.a DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
file(REMOVE lib/libjemalloc.a)
```

##### 3.2.4 deps/linenoise

```CMakeLists
add_library(linenoise linenoise.c)
```

##### 3.2.5 deps/lua

```CMakeLists
file(GLOB LUA_SRC ./src/*.c)
add_library(lua ${LUA_SRC})
```
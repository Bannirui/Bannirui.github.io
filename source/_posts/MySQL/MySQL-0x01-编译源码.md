---
title: MySQL-0x01
category_bar: true
date: 2024-07-29 20:27:36
categories: MySQL
---

### 1 bison

- 1.1 cmake报系统bison版本过低

  ![](./MySQL-0x01-编译源码/1722256141.png)

- 1.2 查看系统版本

  ![](./MySQL-0x01-编译源码/1722256292.png)

- 1.3 通过brew安装bison

  - 1.3.1 `brew search bison`

  - 1.3.2 `brew info bison`

  - 1.3.3 `brew install bison`

  ![](./MySQL-0x01-编译源码/1722256845.png)

- 1.4 更新zshrc

  ![](./MySQL-0x01-编译源码/1722258203.png)

- 1.5 软链接

  - 1.5.1 `bison --version`显示版本还是2.3

  - 1.5.2 `brew unlink bison`

  - 1.5.3 `source ~/.zshrc`

  - 1.5.4 `brew link bison --force`

- 1.6 `bison --version`再次检查版本

  ![](./MySQL-0x01-编译源码/1722257783.png)

### 2 编译

- 2.1 configure

```sh
cmake . -G "Unix Makefiles" -B build
```

![](./MySQL-0x01-编译源码/1722258372.png)

- 2.2 make

```sh
cd build ; make
```

编译MySQL是个漫长的过程

![](./MySQL-0x01-编译源码/1722260190.png)
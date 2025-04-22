---
title: linux-0x02-实模式
category_bar: true
date: 2025-04-22 15:34:07
categories: linux
---

CPU处理器上电后，默认会给两个寄存器赋值，让CPU寻址执行

- CS寄存器赋值0xF000
- IP寄存器赋值0xFFF0

此时CPU要执行的指令在0xFFFF0处

在实模式下，内存布局

![](./linux-0x02-实模式/1745307351.png)
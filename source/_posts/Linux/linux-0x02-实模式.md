---
title: linux-0x02-实模式
category_bar: true
date: 2025-04-22 15:34:07
categories: Linux源码
---

CPU处理器上电后，默认会给两个寄存器赋值，让CPU寻址执行

- CS寄存器赋值0xF000
- IP寄存器赋值0xFFF0

此时CPU要执行的指令在0xFFFF0处，这个地方是BIOS的代码，最终BIOS的代码会将启动盘第一扇区的内容加载到0x07C00，并让CPU跳过去。

此时的内存布局

![](./linux-0x02-实模式/1745307351.png)
---
title: linux-0x0C-切换CPU保护模式
category_bar: true
date: 2025-05-11 10:48:03
categories: linux
---

为了这一步前面已经做了很多铺垫工作

- {% post_link Linux/linux-0x04-引导代码 %}内核代码被搬到了地址0上
- {% post_link Linux/linux-0x08-全局描述符表 %}构建好了GDT表，有代码段描述符和数据段描述符
- {% post_link Linux/linux-0x0B-A20 %}突破了CPU对20地址线的访问

现在CPU模式切换也就是2行指令的事情

```asm
    | lmsw指令只能修改cr0寄存器的低16位 cr0寄存器的第0位叫PE位 lmsw指令只能将PE从0改成1 不能从1改成0
    | 通过lmsw指令对cr0寄存器PE位使能切换到保护模式
	mov	ax,#0x0001	| protected mode (PE) bit
	lmsw	ax		| This is it!
	| 此时cpu已经是32保护模式了 jmpi跟的0是段内逻辑偏移地址 8是CS 而此时CS中值的语义是段选择子 0x8的高14位是0x1 也就是说是到GDT中找到1号段描述符 它的段基址是0
	| 要跳到的物理地址=段基址+逻辑偏移=0+0=0
	| 也就要跳到0地址是 此时0地址上放着磁盘2号扇区及2号扇区之后的内容 也就是内核代码
	jmpi	0,8		| jmp offset 0 of segment 8 (cs)
```

关于0号地址上为什么是内核代码可以再看{% post_link Linux/linux-0x0D-代码的布局 %}
---
title: linux-0x04-引导代码
category_bar: true
date: 2025-04-27 16:09:56
categories: linux
---

前面{% post_link Linux/linux-0x02-实模式 %}已经把启动段代码加载到了0x07c00，CPU也跳转过去。开始执行引导代码了，下面就看看引导代码在干什么。

### 1 启动段

引导代码把自己搬到高地址空间去执行。

从何处来，到何处去。

- 从0x07c00
- 搬到0x90000

```c
| BIOS已经把启动盘第一扇区代码加载到了内存0x007c00 并且cpu也跳过去了
| 现在cs=0x07c0 ip=0
| Boot Segment启动段代码开始工作
entry start
| 重复movw指令直到cx为0 一个word是2Byte 也就是复制512Byte
| 启动段代码自己把自己从0x07c00搬到0x90000 跳到高地址执行
start:
	mov	ax,#BOOTSEG
	mov	ds,ax
	mov	ax,#INITSEG
	mov	es,ax
	mov	cx,#256
	sub	si,si
	sub	di,di
	| 重复执行movw
	| 每搬完一次数据就si+=2 di+=2
	| cx-=1直到cx为0
	rep
	| movw的作用是搬运2Byte ds:si->es:di
	| mov只复制一次时si跟di寄存器值不会步进值自增 只有搭配rep指令时才会自增
	movw
	| 执行到这时Boot Segment代码已经被拷贝到了0x90000处了并且代码的复制功能已经执行完了 要跳到高地址地方继续执行
	jmpi	go,INITSEG
```

![](./linux-0x04-引导代码/1745742536.png)

### 2 初始段

#### 2.1 开辟栈空间

```asm
| 执行到这此时CS是0x9000
| 初始化各个段寄存器ds es ss和sp
go:	mov	ax,cs
	mov	ds,ax
	mov	es,ax
	mov	ss,ax
	| 栈基地址0x9000 栈顶指针0x400 这个地方规划栈空间预留了1024K的大小
	| 栈指针增长方向是向低地址空间 入栈sp减小 出栈sp增加
	| 从0x9000:0->0x9000:0x400地址空间就是栈空间
	mov	sp,#0x400		| arbitrary value >>512
```

此时的内存布局情况是

![](./linux-0x04-引导代码/1745980488.png)

#### 2.2 BIOS的10号中断调用

关于`int 0x10`在另一篇有详细介绍{% post_link Linux/linux-0x05-10号BIOS中断 %}

##### 2.2.1 拿到光标位置

```asm
    | AH设置int 0x10功能号 读取光标位置 位置行列都是0-based 行号返回到DH 列号返回到DL
    | 这个地方读取光标坐标的用途是下面要输出字符串 输出字符串的光标就是现在获取到的
	mov	ah,#0x03	| read cursor pos
	| BH是int 0x10的参数 指定显示页 0表示使用默认的显示页
	xor	bh,bh
	int	0x10
```

##### 2.2.2 打印字符串

```asm
	| 要显示的字符串长度24
	mov	cx,#24
	| BH页码
	| BL属性
	mov	bx,#0x0007	| page 0, attribute 7 (normal)
	| 要显示的字符串地址 ES:BP 现在es已经是0x9000了 只要指定段内偏移量就行了
	mov	bp,#msg1
	| AH功能号0x13
	| AL显示方式0x01
	mov	ax,#0x1301	| write string, move cursor
	int	0x10
```
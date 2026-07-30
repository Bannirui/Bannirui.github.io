---
title: LangGraph-0x05-node函数的设计
category_bar: true
categories: LangGraph
date: 2026-07-30 20:33:30
---

回答3个问题

- 输入什么
- 返回值是什么
- 返回值怎么merge

{%post_link LangGraph/LangGraph-0x08-为什么LangGraph支持普通函数%}中已经提到过，在LangGraph中，最终所有的结点函数都会被封装成Runnable对象。

其本质还是函数，有了统一调度能力的函数，所以框架调度一个函数，关注的无非就是我要给函数什么参数，函数会返回给我什么结果，我要怎么处理结果。

## 1 输入是什么

{%post_link LangGraph/LangGraph-0x09-LangGraph如何自动推断结点输入 %}

## 2 返回值是什么
## 3 返回值怎么merge

---
title: LangGraph-0x0E-compile到底发生了什么
category_bar: true
categories: LangGraph
date: 2026-07-30 21:29:22
---

## 1 前置校验

这个步骤就是

- 对预设的邻接关系的顶点进行校验，保证构建图的时候需要的顶点是能找到的
- 一旦校验没有问题，就准备开始构建图了，不准再修改图的结构了

### 1.1 起点

```python
        # 保证起始点都能在缓存中找到
        for source in all_sources:
            if source not in self.nodes and source != START:
                raise ValueError(f"Found edge starting at unknown node '{source}'")
        # 在add_edge注册邻边关系的时候务必添加了start->X和X->end
        if START not in all_sources:
            raise ValueError(
                "Graph must have an entrypoint: add at least one edge from START to another node"
            )
```

### 1.2 目的点

```python
        # 保证邻接关系的目的点都能在缓存中找到
        for target in all_targets:
            if target not in self.nodes and target != END:
                raise ValueError(f"Found edge ending at unknown node `{target}`")
```

### 1.3 不准修改图

```python
        # 执行到了说明图的结点和边是没有问题的 可以构建图了 表示真正开始进入构建图的流程了 通过这个标识不准再add_node和add_edge注册结点和边修改图和结构了
        self.compiled = True
```

## 2
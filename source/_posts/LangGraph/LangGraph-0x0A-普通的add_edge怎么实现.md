---
title: LangGraph-0x0A-普通的add_edge怎么实现
category_bar: true
categories: LangGraph
date: 2026-07-30 20:43:00
---

```python
# 多个结点怎么连接的
builder.add_edge(START, retrieve.__name__)
builder.add_edge(retrieve.__name__, generate.__name__)
builder.add_edge(generate.__name__, check.__name__)
builder.add_edge(check.__name__, END)
```

这个函数负责向框架注册邻边关系，将来构建图的依据

```python
        # 这个函数只负责注册邻边关系 真正构建图的时候会用到
        self.waiting_edges.add((tuple(start_key), end_key))
```
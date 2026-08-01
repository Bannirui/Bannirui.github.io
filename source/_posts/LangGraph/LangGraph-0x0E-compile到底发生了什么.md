---
title: LangGraph-0x0E-compile到底发生了什么
category_bar: true
categories: LangGraph
date: 2026-07-30 21:29:22
---

完成了pregel引擎的搭建，这个模型是解决图问题的方案，本质是图，所以需要完成的工作就是图的顶点构建和邻边关系维护。

在pregel模型中抽象了Actor是图中的顶点，Channel是图中的边。

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

## 2 实例化pregel模型

```python
        # 2 最终真正构建好的图就是CompiledStateGraph对象 实例化出来 构造函数的作用仅仅是把StateGraph传进去
        # 这也是为什么说一旦图构建好后就不能再更改了 因为对客户端而言能修改图结构的接口是add_node和add_edge而它们更改的是StateGraph
        # 真正的图对象是CompiledStateGraph 所以即使给StateGraph的修改拦截放开也没用
        # StateGraph是业务抽象层 CompiledStateGraph是执行转换层 CompiledStateGraph又继承了Pregel 说明它的本质就是一个pregel的执行引擎层
        compiled = CompiledStateGraph[StateT, ContextT, InputT, OutputT](
            builder=self,
            schema_to_mapper={},
            context_schema=self.context_schema,
            nodes={},
            # 这个时候StateGraph就开始把channels里面缓存的State字段的channel类型通过channels字段构造给CompiledStateGraph了
            # 而CompiledStateGraph的构造函数又会调用父类Pregel的构造一路把channels传上去
            channels={
                **self.channels,
                **self.managed,
                START: EphemeralValue(self.input_schema),
            },
            input_channels=START, # 指定了输入channel是谁 pregel图构架好后 这个__start__的channel就是用来接收invoke时候给的输入状态数据的
            stream_mode="updates",
            output_channels=output_channels,
            stream_channels=stream_channels,
            checkpointer=checkpointer,
            interrupt_before_nodes=interrupt_before,
            interrupt_after_nodes=interrupt_after,
            auto_validate=False,
            debug=debug,
            store=store,
            cache=cache,
            node_error_handler_map=node_error_handler_map,
            name=name or "LangGraph",
            stream_transformers=transformers,
        )
```

## 3 构建pregel的Actor

```python
        # 3 构建pregel模型的actor
        # 给LangGraph不需要显式维护start跟end两个哨兵 你不干就得有人干 所以先构造start结点
        compiled.attach_node(START, None)
        for key, node in self.nodes.items():
            # 把所有注册进来的结点函数都添加到pregel模型图里面
            compiled.attach_node(key, node)
```

## 4 构建pregel的channel

```python
        # 4 各个actor怎么彼此控制 也就是有向图里面边怎么构建的 搭建控制信号的channel
        for start, end in self.edges:
            compiled.attach_edge(start, end)
```
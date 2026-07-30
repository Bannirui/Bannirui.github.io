---
title: LangGraph-0x07-add_node到底做了什么
category_bar: true
categories: LangGraph
date: 2026-07-30 20:37:39
---

看过{%post_link LangGraph/LangGraph-0x05-node函数的设计%}这个，解决了结点函数的入参类型问题之后

`add_node`函数的作用就是负责把结点函数封装起来放到dict里面，给后面构建图用

```python
        # 整个add_node的代码篇幅都在为下面内容服务 这个函数的目的仅仅是把结点缓存起来 留给构建图的时候能立马就用上
        # 所以为了检索的性能 才要保证结点名字唯一性 用dict映射
        # 函数给进来的是函数或者有__call__的对象 不管是什么 都封装成StateNodeSpec
        # 所以为什么上面这么多代码要整明白结点函数的入参类型呢 因为将来这些函数的调用是由LangGraph发起的 得知道传哪些值给函数 必须得知道类型
        if input_schema is not None:
            # 明确指定了结点函数的入参类型了
            self.nodes[node] = StateNodeSpec[NodeInputT, ContextT](
                coerce_to_runnable(action, name=node, trace=False),  # type: ignore[arg-type]
                metadata,
                input_schema=input_schema,
                retry_policy=retry_policy,
                cache_policy=cache_policy,
                error_handler_node=handler_node_name,
                ends=ends,
                defer=defer,
                timeout=timeout,
            )
```
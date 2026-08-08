---
title: LangGraph-0x0D-ends存在的意义是什么
category_bar: true
categories: LangGraph
date: 2026-07-30 21:28:14
---

```python
builder.add_node(retrieve,destinations=["generate","check"])
builder.add_node(generate)
builder.add_node(check)
```

在注册结点的时候可以通过参数`destinations`指定一些节点名字给框架的，那么这个字段干嘛用的呢

```python
        # 用户指定了当前结点可能会往那些结点上跳转
        if destinations is not None:
            # 为什么需要这么个玩意呢 因为python是解释语言 先用ends大概框定图的拓扑 真正怎么连接等解释执行到后面确定下来
            ends = destinations
```

最后在缓存结点的时候会体现在`ends`字段上

```ptyhon
            self.nodes[node] = StateNodeSpec[NodeInputT, ContextT](
                coerce_to_runnable(action, name=node, trace=False),  # type: ignore[arg-type]
                metadata,
                input_schema=input_schema,
                retry_policy=retry_policy,
                cache_policy=cache_policy,
                error_handler_node=handler_node_name,
                # 这个结点可能会跳到哪个结点 也就是这个结点在图中可能跟谁联通
                ends=ends,
                defer=defer,
                timeout=timeout,
            )
```

为什么做这个设计呢，框架的流程是客户端先注册结点，在这个时候就已经有机会提前知道这个结点将来在图中可能跟谁连通。在后面compile构建图的时候就提前知道可能拓扑，runtime决定真实路径。
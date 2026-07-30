---
title: LangGraph-0x08-为什么LangGraph支持普通函数
category_bar: true
categories: LangGraph
date: 2026-07-30 20:40:05
---

LangGraph作为框架，抽象了node这个概念，目的就是为了完成某个功能，本质就是函数

那么这个函数可能有哪些形态呢

- 普通的全局函数
  - 有可能是同步的
  - 有可能是异步的
- 类的成员函数
  - 有可能是同步的
  - 有可能是异步的
- 类的实例 这个类实现了__call__函数

如此种种，将来框架想要调度的时候就要分门别类进行判断啥类型的，与其每次调度的时候判断，不如结点往框架注册的时候就一次性判断好，然后封装成统一的结构。

这个统一的封装就是Runnable

```python
# LangGraph的结点本质而言就是函数 将来的调度是要LangGraph负责的 函数千奇百怪 为了统一调度 把函数封装成Runnable 这样就统一了API
def coerce_to_runnable(
    thing: RunnableLike, # 3种情况 普通函数 类函数 对象(这个对象实现了__call__函数)
        *, name: str | None, # 结点函数注册到LangGraph时候给这个结点起的唯一标识的名字 可能是注册时候显式命名的也可能框架用函数名命名的
        trace: bool
) -> Runnable:
    if isinstance(thing, Runnable):
        # 已经是Runnable 客户端已经完成了包装 框架就不用管了
        return thing
    elif is_async_generator(thing) or inspect.isgeneratorfunction(thing):
        # generator函数 什么叫generator函数呢 def fn(state:State): yield "hello"
        return RunnableLambda(thing, name=name)
    elif callable(thing):
        # 这里面包含两种 普通函数和类实例(实现了__call(...)__)
        if is_async_callable(thing):
            # 函数是异步函数 用了async修饰了 比如async def fn(state:State):return {}
            return RunnableCallable(None, thing, name=name, trace=trace)
        else:
            # 函数是同步函数
            return RunnableCallable(
                thing,
                wraps(thing)(partial(run_in_executor, None, thing)),  # type: ignore[arg-type]
                name=name,
                trace=trace,
            )
    elif isinstance(thing, dict):
        # 这个地方没懂啥意思
        return RunnableParallel(thing)
    else:
        ...
```
---
title: LangGraph-0x16-执行引擎层pergel模型
category_bar: true
categories: LangGraph
date: 2026-07-31 20:37:14
---

没想到底层用的竟然是Pregel模型，当我看到channel的时候我就想到了golang，没想到真的很google，网上找到的论文丢下面了

https://kowshik.github.io/JPregel/pregel_paper.pdf



## 1 channel

### 1.1 怎么给定义的State每个字段生成对应的channel

#### 1.1.1 单个字段的channel类型

```python
r"""
在给LangGraph定义State的时候 它就是定义了dict
比如
class MyState(TypedDict):
    name: str
那么就是定义了dict的key是name name这个字段的value类型是str
那么name这个字段的channel类型就是LastValue(str)
这个函数解决的就是dict单个字段的channel类型推导
:param name: dict字段的名字
:param annotation: dict字段对应value的类型
"""
def _get_channel(
    name: str, annotation: Any, *, allow_managed: bool = True
) -> BaseChannel | ManagedValueSpec:
    # Strip out Required and NotRequired wrappers
    if hasattr(annotation, "__origin__") and annotation.__origin__ in (
        Required,
        NotRequired,
    ):
        annotation = annotation.__args__[0]
    if manager := _is_field_managed_value(name, annotation):
        if allow_managed:
            return manager
        else:
            raise ValueError(f"This {annotation} not allowed in this position")
    elif channel := _is_field_channel(annotation):
        channel.key = name
        return channel
    elif channel := _is_field_binop(annotation):
        channel.key = name
        return channel
    # 比如类型是str 那么返回的就是LastValue(str)
    fallback: LastValue = LastValue(annotation)
    fallback.key = name
    return fallback
```

#### 1.1.2 State的channel类型

能拿到dict某个字段的channel，就能拿到整个State的所有字段的channel

```python
# 拿到LangGraph的State所有字段的channel 关注第1个返回值 是在pregel系统中传递消息用的
def _get_channels(
    schema: type[dict], # schema是在LangGraph里面重要的TypedDict State
) -> tuple[dict[str, BaseChannel], dict[str, ManagedValueSpec], dict[str, Any]]:
    # TypedDict是有__annotations__的 所以不会进下面的分支
    if not hasattr(schema, "__annotations__"):
        return (
            {"__root__": _get_channel("__root__", schema, allow_managed=False)},
            {},
            {},
        )

    # 拿到State这个dict的value的类型注解
    # 比如class(TypedDict): question:str 那么这个地方拿到的就是个dict={"question":str}
    type_hints = get_type_hints(schema, include_extras=True)
    # _get_channel解决了每一个字段的名字和channel类型 下面的列表推导式拿到了State这个dict所有字段的name和对应的channel类型
    all_keys = {
        name: _get_channel(name, typ)
        for name, typ in type_hints.items()
        if name != "__slots__"
    }
    # 返回值分成了3个部分 是为了将来给pergel引擎用的 按照用途分成了3类
    # 第1个返回值判断channel类型是不是BaseChannel 以内置类型来说 比如str->LastValue(str) LastValue继承了BaseChannel
    # 所以第1个返回值就是拿到了用来在pregel模型中传递消息的所有字段的channel
    return (
        {k: v for k, v in all_keys.items() if isinstance(v, BaseChannel)},
        {k: v for k, v in all_keys.items() if is_managed_value(v)},
        type_hints,
    )
```

#### 1.1.3 StateGraph构造函数做了什么

```python
        # 把State字段的channel类型缓存起来 放到channels里面
        self._add_schema(self.state_schema)
```

那么这个跟pregel有什么关系呢，这个链路是StateGraph构造->缓存好State字段的channel类型->StateGraph对象进行compile构建图->触发CompiledStateGraph构造，而CompiledStateGraph又继承自Pregel，所以也就是这个时候把channels都告诉了pregel模型

#### 1.1.4 CompiledStateGraph的构造函数

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
```

#### 1.1.4 CompiledStateGraph调用父类Pregel的构造函数

```python
    def __init__(
        self,
        *,
        builder: StateGraph[StateT, ContextT, InputT, OutputT], # 构造CompiledStateGraph会把StateGraph对象传进来
        schema_to_mapper: dict[type[Any], Callable[[Any], Any] | None],
        **kwargs: Any,
    ) -> None:
        # StateGraph对象执行compile的过程中会构造一个CompiledStateGraph执行到这 会送上来参数channels 就是State字段的channel类型
        super().__init__(**kwargs)
```

Pregel会把这个缓存起来

```python
        # StateGraph对象->compile->CompiledStateGraph构造 StateGraph对象会把自己解析好的State字段的channel类型传进来
        self.channels = channels or {}
```

## 2

## 3
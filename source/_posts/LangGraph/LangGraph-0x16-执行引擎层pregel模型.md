---
title: LangGraph-0x16-执行引擎层pergel模型
category_bar: true
categories: LangGraph
date: 2026-07-31 20:37:14
---

没想到底层用的竟然是Pregel模型，当我看到channel的时候我就想到了golang，没想到真的很google，网上找到的论文丢下面了

https://kowshik.github.io/JPregel/pregel_paper.pdf

我感觉pregel模型其实就是LangGraph整个框架的核心，弄懂了它，LangGraph自然而然就清晰了

[LangGraph对Pregel的介绍](https://reference.langchain.com/python/langgraph/pregel/main/Pregel)

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

#### 1.1.5 图里面邻边作用的channel

```python
    r"""
    从图的结构上看结点的邻接靠的边 这个边在pregel被抽象成channel
    现在需要把start->end这样的邻接关系需要的channel构造好
    注意这个地方的channel不是共享数据channel 而是控制channel
    现在图的方向是start->end 也就是说start执行完需要通知end执行 所以需要的channel就是start执行完写控制信号
    """
    def attach_edge(self, starts: str | Sequence[str], end: str) -> None:
        if isinstance(starts, str):
            # subscribe to start channel
            if end != END:
                # start->end方向 start的actor执行完写什么channel通知end可以执行
                # 写哪个channel就是branch:to:end结点名字
                self.nodes[starts].writers.append(
                    ChannelWrite(
                        (ChannelWriteEntry(_CHANNEL_BRANCH_TO.format(end), None),)
                    )
                )
```

## 2 actor

### 2.1 成员概览

这里面涉及到很多概念，所以要先概览一遍，他们的本质和作用会在下面用到的地方进行解释

```python
# 客户端丢到StateGraph的结点函数最终的形态就是在pregel模型里面结点 它是pregel引擎的真正执行单元
class PregelNode:
    """A node in a Pregel graph. This won't be invoked as a runnable by the graph
    itself, but instead acts as a container for the components necessary to make
    a PregelExecutableTask for a node."""

    # 这个结点执行的时候 需要读取那些channel 也就是这个结点函数的输入
    channels: str | list[str]
    """The channels that will be passed as input to `bound`.
    If a str, the node will be invoked with its value if it isn't empty.
    If a list, the node will be invoked with a dict of those channels' values."""

    # 哪些channel的更新后 会触发这个结点的执行
    # 为什么有了上面的channels不够还要单独用triggers来作为函数的触发信号 因为读取和触发不是一回事
    # 比如这个结点函数执行需要2个参数a和b 但是只要等待a更新就表示可以开始执行
    triggers: list[str]
    """If any of these channels is written to, this node will be triggered in
    the next step."""

    # channel里面的数据怎么转换成结点函数的输入
    # 比如结点函数的签名是def fn(state):需要的是{question:"",docs:[]}
    # 现在question channel里面的数据是"hello"
    # docs这个channel里面是["a","b"]
    # 那么mapper函数就负责把channel里面的数据组装起来成为{question:"hello",docs:["a","b"]}传给fn函数
    mapper: Callable[[Any], Any] | None
    """A function to transform the input before passing it to `bound`."""
    # 结点函数执行完需要怎么做 理解了上面的channels和triggers这个地方也就懂了
    # 什么意思 对于结点函数而言 它的数据跟控制是分离的
    # 所以现在函数执行完了 自己的输出可能就是别人需要的输入 因此对别人的数据和控制也是分离的
    # 这个writers里面就是放了2个函数 1个负责往对应的channel里面更新数据 1个负责往对应的channel里面放控制信号
    writers: list[Runnable]
    """A list of writers that will be executed after `bound`, responsible for
    taking the output of `bound` and writing it to the appropriate channels."""
    # 实际的执行对象 结点函数不会直接保存 会包装一下
    bound: Runnable[Any, Any]
    """The main logic of the node. This will be invoked with the input from 
    `channels`."""
    # 结点失败重试策略
    retry_policy: Sequence[RetryPolicy] | None
    """The retry policies to use when invoking the node."""
    # 结点缓存 什么意思呢 比如这个结点函数需要的入参name 同样输入了name="hello"之前执行过了 就直接返回缓存
    cache_policy: CachePolicy | None
```

### 2.2 结点的构造

```python
            # 在pregel模型中结点最重要的属性
            # triggers 谁告诉我该执行了
            # channels 我的入参从哪儿来
            # mapper 入参组装成实参
            # writers 我执行完要把数据更新到哪儿 要不要发个控制信号
            # bound 函数对象
            self.nodes[key] = PregelNode(
                triggers=[branch_channel], # 就看branch:to:结点函数名 这个channel里面有数据更新 说明自己需要执行了
                # read state keys and managed values
                channels=("__root__" if is_single_input else input_channels), # 结点函数要执行依赖的参数从哪个channel来 单个字段的入参特殊约定从__root__拿
                # coerce state dict to schema class (eg. pydantic model)
                mapper=mapper, # 怎么把channel里面的数据组装成自己这个函数执行的实参
                # publish to state keys
                writers=[ChannelWrite(write_entries)], # 自己执行完后给channel传自己的返回值 甚至也要用channel控制别人执行
                metadata=node.metadata,
                retry_policy=node.retry_policy,
                cache_policy=node.cache_policy,
                is_error_handler=node.is_error_handler,
                error_handler_node=node.error_handler_node,
                bound=node.runnable,  # type: ignore[arg-type] # 结点函数
                timeout=node.timeout,
            )
```

## 3 模型的搭建

对于pregel算法，重要的两个概念就是actor跟channel，通过上面明白了他们是什么之后，现在总览一下怎么构建出这个模型的

在StateGraph执行compile的链路里面

### 3.1 顶点构建

```python
        # 3 构建pregel模型的actor
        # 给LangGraph不需要显式维护start跟end两个哨兵 你不干就得有人干 所以先构造start结点
        compiled.attach_node(START, None)
        for key, node in self.nodes.items():
            # 把所有注册进来的结点函数都添加到pregel模型图里面
            compiled.attach_node(key, node)
```

### 3.2 邻边构建

```python
        # 4 各个actor怎么彼此控制 也就是有向图里面边怎么构建的 搭建控制信号的channel
        for start, end in self.edges:
            compiled.attach_edge(start, end)
```

## 4 模型的调度

至此pregel的channel跟actor都有了，模型有了，怎么让模型工作起来呢。跟其他框架一样最朴素的方式就是套一个while循环就行。

pregel为了算法的其他治理能力，对loop模型做了一些变种优化，但是本质就是一个死循环。

比较复杂的流程是第一次启动调度

### 4.1 客户端启动CompiledStateGraph

```python
init_state: Ctx = {"question": "this is my question"}
result = graph.invoke(init_state)
```

### 4.2 这个数据会更新到__start__上

#### 4.2.1 先创建channel

```python
        # 创建好channel 包括__start__这个channel
        self.channels, self.managed = channels_from_checkpoint(
            self.specs,
            self.checkpoint,
            saver=self.checkpointer,
            config=self.checkpoint_config,
        )
```


#### 4.2.1 往channel写数据

```python
        # 在CompiledStateGraph调用invoke把输入输入状态丢进来后 这个地方记录一下哪些channel被更新了
        # 标记__start__被更新了
        self.updated_channels = self._first(
            input_keys=self.input_keys, # 接收输入状态input的channel 在pregel中的初始接收invoke的channel是__start__
            updated_channels=set(self.checkpoint.get("updated_channels"))  # type: ignore[arg-type]
            if self.checkpoint.get("updated_channels")
            else None,
        )
```

### 4.3 START订阅的控制信号和数据

```python
        if key == START:
            # START结点需要特殊处理 特殊在哪儿
            # 1 本质是个哨兵 没有函数执行
            # 2 它订阅的信号channel也是特殊的 谁能驱动start工作呢 就是整个pregel首次调度的时候 在CompiledStateGraph执行invoke的时候是把input输入状态数据提交给了pregel 然后pregel把输入数据写到了__start__这个channel上 所以__start__这个channel的变化就是START Actor执行的信号
            # 3 虽然没有函数 但是逻辑上这个actor也会回调writers里面的两个函数
            # 它跟普通函数的actor的区别在于 普通actor的执行链是 input->input=proc(input)->writers(input) 因为START没有proc 所以writers收到的入参还是actor原来的input
            self.nodes[key] = PregelNode(
                tags=[TAG_HIDDEN],
                triggers=[START],
                channels=START,
                writers=[ChannelWrite(write_entries)],
            )
```

triggers和channels都是__start__，这也是为什么pregel可以loop起来的原因。

至此，pregel模型创建的时候会往__start__写启动数据，这个channel既是控制channel又是数据channel。

- 在loop里面找到了哪些channel被更新了
- 发现了__start__被更新了，订阅的Actor是START
- 看看START的参数channel也是__start__
- START这个是特殊的Actor
  - 没有proc执行函数
  - 自然也就没有mapper组装参数，直接去channel里面拿数据出来就行，因为只有__start__一个channel来源，不需要组装
- 回调writers
  - 把输入状态input的每个字段更新到channel
  - 发送START下游结点的信号channel

就这样循环起来

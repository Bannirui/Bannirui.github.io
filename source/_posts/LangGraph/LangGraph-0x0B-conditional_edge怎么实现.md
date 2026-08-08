---
title: LangGraph-0x0B-conditional edge怎么实现
category_bar: true
categories: LangGraph
date: 2026-07-30 20:45:06
---

本质而言就是，将compile前不确定的路由关系延迟到compile之后真正确定，属于是runtime信息，所以要先把规则存起来

## 1 怎么动态路由

```python
def should_continue(state: Ctx) -> str:
    # 返回值就是要连通的结点名
    return state["entry"]


# 多个结点怎么连接的
builder.add_conditional_edges(
    START,
    should_continue
)
```

## 2 你怎么保存运行时需要的函数信息

LangGraph定义了BranchSpec来记住有关路由函数的信息，方便将来调用

```python
r"""
动态路由是运行时决定的
所以要把这一套信息封装起来 等着回调的时候知道怎么调用
我不管你现在的end怎么定义的 我都转换成dict缓存起来 保证语义的一致性 将来就只拿路由函数的返回值去dict里面检索 拿到的value就是要连通的结点名
"""
class BranchSpec(NamedTuple):
    # 路由函数
    path: Runnable[Any, Hashable | list[Hashable]]
    # 根据路由函数返回值怎么选下一个连通的结点
    # 1 如果这个地方是dict 那么路由函数返回值就作key 来dict里面检索对应的value value就是要连通的结点名字
    # 2 如果这个地方是None 那么路由函数返回值就是要连通的结点名字
    ends: dict[Hashable, str] | None
    # 既然将来要回调路由函数 就得知道将来调用函数的时候怎么传实参
    # 要是定义路由函数的时候写了参数注解 就用注解的类型 def fn(arg:Arg): 将来从全局状态里面掏出来需要的字段组装成实参传给路由函数
    # 要是定义路由函数的时候没有写参数注解 也就不知道对应的参数类型了 将来回调的时候直接就把全局状态State丢给函数 交给python自己去匹配字段去
    input_schema: type[Any] | None = None

    @classmethod
    def from_path(
        cls,
        path: Runnable[Any, Hashable | list[Hashable]], # 路由函数
        path_map: dict[Hashable, str] | list[str] | None, # 3种情况 1 dict key是函数返回值 value是要连通的结点名 2 数组 这种情况会被处理成第1种情况 3 None 路由函数返回值就是要连通的结点名
        infer_schema: bool = False, # 啥意思 有人定义函数会加个类型注解 有人不加 比如def fn(arg:Arg): 所以用这个参数标识函数有形参类型注解 你就直接从注解拿参数类型 将来就知道怎么传实参了 当然没有注解也没有关系 将来你就把整个的全局状态State丢给路由函数就完事了 自己去匹配需要的字段
    ) -> BranchSpec: # 为什么需要封装成BranchSpec 因为运行时需要执行路由函数 根据路由函数返回值决定后续的结点 所以要把这一套信息封装起来
        # coerce path_map to a dictionary
        # 开始处理path_map 为什么处理 为了简化语义方便使用
        # 回忆一下这个map的情况 它可能是数组 显然数组的检索性能不如map 那就把数组转换成map
        # ["a","b"]->{"a":"a","b":"b"} 跟原来是dict的语义是一样的 函数返回值作key到dict中检索到的value就是要连通的结点名
        path_map_: dict[Hashable, str] | None = None
        try:
            if isinstance(path_map, dict):
                path_map_ = path_map.copy()
            elif isinstance(path_map, list):
                # 原来是数组这种情况特殊处理成dict
                path_map_ = {name: name for name in path_map}
            else:
                # find func
                # 就用函数的返回值作为要连通的结点名
                func: Callable | None = None
                if isinstance(path, (RunnableCallable, RunnableLambda)):
                    func = path.func or path.afunc
                if func is not None:
                    # find callable method
                    # 可能是个对象 对象的类实现了__call__方法的
                    # 也可能就是一个普通的函数
                    if (cal := getattr(path, "__call__", None)) and ismethod(cal):
                        func = cal
                    # get the return type
                    if rtn_type := get_type_hints(func).get("return"):
                        if get_origin(rtn_type) is Literal:
                            # 用路由函数的返回值构建dict
                            path_map_ = {name: name for name in get_args(rtn_type)}
        except Exception:
            pass
        # infer input schema
        # 从路由函数的形参注解确定路由函数的入参类型
        input_schema = _get_branch_path_input_schema(path) if infer_schema else None
        # create branch
        return cls(path=path, ends=path_map_, input_schema=input_schema)
```

## 3 把路由函数缓存起来

所以在`add_conditional_edges`时就是注册了动态路由函数

```python
        # 缓存动态路由函数 作用的结点名+路由函数名作两层索引
        self.branches[source][name] = BranchSpec.from_path(path, path_map, True)
```

## 4 compile阶段是怎么用的

{%post_link LangGraph/LangGraph-0x0E-compile到底发生了什么%}介绍了compile流程，在compile流程里面构建图会用到动态路由的地方

- 前置校验
- 构建channel关系

### 4.1 前置校验

#### 4.1.1 出发顶点

```python
        # 动态路由 这些结点的注册了动态路由函数的
        for start, branches in self.branches.items():
            all_sources.add(start)
```

#### 4.1.2 目的顶点

```python
        # 哪些结点是注册了动态路由函数的
        for start, branches in self.branches.items():
            for cond, branch in branches.items():
                if branch.ends is not None:
                    # 在构造BranchSpec的时候已经保证了ends肯定是dict
                    for end in branch.ends.values():
                        if end not in self.nodes and end != END:
                            raise ValueError(
                                f"At '{start}' node, '{cond}' branch found unknown target '{end}'"
                            )
                        # 动态路由里面提到的结点都是目的地结点
                        all_targets.add(end)
```

### 4.2 路由的本质

{%post_link LangGraph/LangGraph-0x0E-compile到底发生了什么%}如果真的理解了pregel模型的本质，就应该明白所谓的图的邻接是什么

真的在两个Actor结点中用物理连接了吗，它用共享内存彻底解耦了各个结点，虽然他们逻辑上是图也连通了，其实可以看作是独立的，不感知的

执行的驱动是pregel在每个loop里面找被更新的channel，然后找到branch:to:xxx这种channel，定位到哪些Actor可以执行了

所以这个时候再回过头思考什么是动态路由，其实就是Actor结点执行完后，通过动态路由函数拿到想要下一轮被驱动的结点名字，我只要往branch:to:x这些channel更新数据就行了

```python
    r"""
    创建动态路由的关系
    本质就是创建好各种branch:to:x这样的channel 然后在Actor上装上writer负责写哪个channel就行
    在pregel的loop里面pregel负责
    1 找到有更新有channel
    2 挑选出控制信号的channel 就是branch:to:x这种
    3 找到各个x就是要在这个loop执行的Actor
    """
    def attach_branch(
        self,
            start: str, # 要给哪个结点构建动态路由结点 也就是出发结点名
            name: str, # 动态路由的函数名
            branch: BranchSpec, # 动态路由函数的封装
            *, with_reader: bool = True
    ) -> None:
        # 动态路由函数执行完要更新哪些channel
        # 什么意思 动态路由和静态路由本质而言没有区别 所谓路由就是连通结点
        # 在pregel中真的有物理上的边吗 其实没有 pregel完全分离了结点 通过channel的共享内存 不是主动调用函数执行 而是函数自己订阅内存发现更新就自己执行
        # 所以什么叫动态路由 就是路由函数更新完后 还想要哪些结点actor工作 就更新branch:to:结点名字
        def get_writes(
            packets: Sequence[str | Send], static: bool = False
        ) -> Sequence[ChannelWriteEntry | Send]:
            writes = [
                (
                    ChannelWriteEntry(
                        p if p == END else _CHANNEL_BRANCH_TO.format(p), None
                    )
                    if not isinstance(p, Send)
                    else p
                )
                for p in packets
                if (True if static else p != END)
            ]
            if not writes:
                return []
            return writes

        if with_reader:
            # get schema
            # 动态路由函数的形参类型 此时拿到的input_schema可能是空的 为什么 在构造BranchSpec的时候
            # 1 如果定义的路由函数有类型注解 就明确了参数类型
            # 2 如果定义的路由函数没有类型注解 这个参数类型就放空了
            # 所以现在来处理置空的情况 既然路由函数是作用在start结点上的 就用start结点函数的参数类型 对于结点函数而言注解了就用注解的 没有注解就用全局State的结构
            schema = branch.input_schema or (
                self.builder.nodes[start].input_schema
                if start in self.builder.nodes
                else self.builder.state_schema
            )
            # 既然知道了路由函数的入参类型 就是知道了TypedDict是啥 字段掏出来就是将来实参数据的来源 从这些channel里面把LastValue拿出来一组装就是路由函数需要的实参
            channels = list(self.builder.schemas[schema])
            # get mapper
            if schema in self.schema_to_mapper:
                mapper = self.schema_to_mapper[schema]
            else:
                mapper = _pick_mapper(channels, schema)
                self.schema_to_mapper[schema] = mapper
            # create reader
            reader: Callable[[RunnableConfig], Any] | None = partial(
                ChannelRead.do_read,
                select=channels[0] if channels == ["__root__"] else channels, # 动态路由函数需要从那些channel里面拿数据作为自己的实参来源
                fresh=True,
                # coerce state dict to schema class (eg. pydantic model)
                mapper=mapper, # 数据从channel里面拿出来后怎么组装成动态路由需要的实参
            )
        else:
            reader = None

        # attach branch publisher
        # 创建动态路由的本质就是 在Actor执行后 通过路由函数的执行结果决定给哪个branch:to:x的channel上更新数据就行
        self.nodes[start].writers.append(branch.run(get_writes, reader))
```
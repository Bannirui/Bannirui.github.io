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

谈结点函数的输入输出之前，有必要了解的是State的设计。

```python
class Ctx(TypedDict):
    r"""
    State是LangGraph贯穿Graph执行生命周期的共享上下文
    保存了用户的输入 结点中间结果和最终输出
    每个Node本质是一个State->State的更新函数

    TypedDict作用是定义一个字典应该有哪些key 以及每个key对应的数据类型

    所以State本质就是一个dict 在结点流转的过程中State这个dict就是在不断扩展的数据包
    node的入参一定是State 返回值不一定是必须完整的State LangGraph会负责把node返回的部分State合并到State
    更新机制是更新 也就是覆盖掉key
    """
    # 定义合并规则 不要覆盖 要合并
    mark: Annotated[list[str], add_messages]
    question: str
    documents: list[str]
    answer: str


# 实例化的时候告诉LangGraph 我要用的State结构长什么样子
builder = StateGraph(Ctx)
```

来看看构造函数，看看咋用的这个实参

```python
    def __init__(
        self,
        # Graph运行期间共享状态的数据结构 得告诉LangGraph上下文里面都有哪些字段它才好去维护
        state_schema: type[StateT],
        ...
    ) -> None:
```

什么意思，假如有两个结点A和B

- A的函数执行需要两个参数，起个名字a_in_1和a_in_2
- A的函数执行返回a_out
- B函数执行需要一个参数b_in
- B函数执行返回b_out_1和b_out_2

每个结点函数入参和出参都不一样，咋统一调度呢，把所有的字段a_in_1、a_int_2、a_out、b_in、b_out_1、b_out_2名字都固定好，不变了，做成dict的键

每个函数执行的时候需要啥就去dict里面按照键取，每个函数返回什么，就把返回值按照名字放到dict

到这，就已经达成了LangGraph的State这个概念的共享的功能

## 1 输入是什么

通过上面，就已经厘清了一件事情，就是每个结点函数的入参、出参可能不同，但是一定都是State的子集。

那么对于函数的入参而言

- 最少的字段就是0个，也就是函数签名如`def fn():`
- 最多的字段就是State的全部字段，那么函数签名就是`def fn(state:State):`

其实大部分的实际开发中，都是每个结点函数都有自己的特定的字段，为了解耦各个函数的入参，最简单的就是给每个函数都定义自己的参数类型就行了，然后告诉框架参数类型是什么就行

下面是示例代码

```python
from typing import TypedDict, Annotated

from langgraph.graph import StateGraph, START, END
from langgraph.graph.message import add_messages


class Ctx(TypedDict):
    # 定义合并规则 不要覆盖 要合并
    mark: Annotated[list[str], add_messages]
    question: str
    documents: list[str]
    answer: str


class RetrieveArg(TypedDict):
    question: str


def retrieve(state: RetrieveArg) -> dict:
    r"""
    结点1
    查询知识库
    """
    return {
        "mark": ["结点1"],
        "documents": ["SOP资料", "RAG资料"]
    }


class GenerateArg(TypedDict):
    question: str
    documents: list[str]


def generate(state: GenerateArg) -> dict:
    r"""
    结点2
    调用LLM
    """
    return {
        "mark": ["结点2"],
        "answer": "LLM的答案"
    }


class CheckArg(TypedDict):
    question: str
    documents: list[str]
    answer: str


def check(state: CheckArg) -> dict:
    r"""
    结点3
    负责检查答案
    """
    return {
        "mark": ["结点3"],
        "answer": state["answer"] + "->已经审核过了"
    }


# 实例化的时候告诉LangGraph 我要用的State结构长什么样子
builder = StateGraph(Ctx)

builder.add_node(retrieve, input_schema=RetrieveArg)
builder.add_node(generate, input_schema=GenerateArg)
builder.add_node(check, input_schema=CheckArg)

# 多个结点怎么连接的
builder.add_edge(START, retrieve.__name__)
builder.add_edge(retrieve.__name__, generate.__name__)
builder.add_edge(generate.__name__, check.__name__)
builder.add_edge(check.__name__, END)

graph = builder.compile()

# 初始状态
init_state: Ctx = {"question": "this is my question"}
result = graph.invoke(init_state)

print(result)
```

在注册结点函数的时候`builder.add_node(retrieve, input_schema=RetrieveArg)`告诉框架这个函数的入参类型是啥，那么如果没显式告诉框架怎么办呢

### 1.1 指定了入参类型

除了input_schema，还有一种指定方式，通过input参数

```python
        # 兼容老版本的参数input传进来 就是现在的input_schema
        if (input_ := kwargs.get("input", MISSING)) is not MISSING:
            warnings.warn(
                "`input` is deprecated and will be removed. Please use `input_schema` instead.",
                category=LangGraphDeprecatedSinceV05,
            )
            if input_schema is None:
                # 拿到了结点函数的入参类型
                input_schema = cast(type[NodeInputT] | None, input_)
        timeout = coerce_timeout_policy(timeout)
```

### 1.2 没有指定

没有指定类型就要自己去推断了，怎么推断呢，拿到函数的参数列表，这个时候无非有3种情况

- 没有形参
- 恰好只有一个形参
- 有好几个形参

每个人的开发习惯不一样，有人习惯`def fn(a:A)->B:`，有个习惯`def fn(a):`，有类型注解的就好办，入参的类型就是注解的类型

```python
                # 执行到说明经过了上面3个检查 要么是对象 要么是函数 如果是对象就是有__call__函数的对象 函数就不管是普通函数还是类方法了反正是函数
                # 结点是对象的__call__函数
                # 不是有__call__函数的对象说明结点就是函数
                # 每个人开发习惯不一样 有的人会写类型注解 比如def fn(a:A)->B: 把函数的参数列表对应的类型注解拿出来
                # 参数列表的样子{'state':<class '__main__.Ctx'>, 'return': <class 'dict'>} key是形参名字 value是形参对应的类型注解
                hints := get_type_hints(getattr(action, "__call__"))
                or get_type_hints(action)

...

                    # 参数列表拿到这个结点函数的形参的注解类型
                    if input_hint := hints.get(first_parameter_name):
                        if isinstance(input_hint, type) and get_type_hints(input_hint):
                            inferred_input_schema = input_hint
```

上面的源码解决了什么问题，有类型注解的，有一个或者多个形参的，都用第一个形参的类型注解当作推断出来的形参类型。

```python
        # 如果结点函数就是不要入参的情况 在上面try里面的next函数会抛异常 执行到这
        # input_schema是空的
        # inferred_input_schema是空的
        # 那就推断结点函数的入参类型是State的结构类型
        resolved_input_schema: type[Any] = (
            input_schema or inferred_input_schema or self.state_schema
        )
```

没有给参数注解类型的，用State类型当作函数入参类型。空参数的，也用State类型当作函数入参类型。

```python
@dataclass(slots=True)
class StateNodeSpec(Generic[NodeInputT, ContextT]):
    runnable: StateNode[NodeInputT, ContextT]
    metadata: dict[str, Any] | None
    # 结点函数的入参类型 注意可能实际上这个函数不需要参数 也可能需要多个参数 现在给结点函数封装起来 所以这个类型仅仅是一个参考作用
    input_schema: type[NodeInputT]
    retry_policy: RetryPolicy | Sequence[RetryPolicy] | None
    cache_policy: CachePolicy | None
    is_error_handler: bool = False
    error_handler_node: str | None = None
    ends: tuple[str, ...] | dict[str, str] | None = EMPTY_SEQ
    defer: bool = False
    timeout: TimeoutPolicy | None = None
```

## 2 返回值是什么
## 3 返回值怎么merge

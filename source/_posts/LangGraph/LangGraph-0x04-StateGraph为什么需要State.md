---
title: LangGraph-0x04-StateGraph为什么需要State
category_bar: true
categories: LangGraph
date: 2026-07-30 20:28:03
---

我认为在LangGraph中State的作用有两个

## 1 数据共享功能

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

## 2 节点状态管理功能
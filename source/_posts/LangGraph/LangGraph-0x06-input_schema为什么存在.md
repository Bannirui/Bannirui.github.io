---
title: LangGraph-0x06-input_schema为什么存在
category_bar: true
categories: LangGraph
date: 2026-07-30 20:35:18
---

谈结点函数的输入输出之前，有必要了解的是State的设计{%post_link LangGraph/LangGraph-0x04-StateGraph为什么需要State%}

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

当用户没有告诉框架结点函数的参数类型，就要框架自己去推断了{%post_link LangGraph/LangGraph-0x09-LangGraph如何自动推断结点输入%}

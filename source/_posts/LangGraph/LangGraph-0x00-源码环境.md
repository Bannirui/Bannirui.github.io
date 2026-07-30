---
title: LangGraph-0x00-源码环境
category_bar: true
categories: LangGraph
date: 2026-07-30 10:11:26
---

## 1 源码分支

```she
# 到官方仓库fork https://github.com/langchain-ai/langgraph

# 把自己仓库克隆到本地
git clone git@github.com:Bannirui/langgraph.git

# 本地源码
cd langgraph

# 添加上游仓库 保持跟上游代码一致
git remote add upstream git@github.com:langchain-ai/langgraph.git

# 代码不要直接提交到上游 要先提交到origin 然后走PR
git remote set-url --push upstream no_push

# 保持跟上游代码一致
git fetch upstream
# master分支
git checkout main
git rebase upstream/main

# 学习分支
git checkout -b my-study
git push origin my-study
```

## 2 最小示例

```sh
# 解释器环境
python3 -m venv .venv
source .venv/bin/activate
# 安装依赖 后面要对源码注释 加参数e
pip install -e libs/langgraph
# 放自己的调试代码
mkdir my-study
touch my-study/hello_langgraph.py
# 运行自己的调试代码
python my-study/hello_langgraph.py
```

hello_langgraph的代码

```python
from typing import TypedDict

from langgraph.graph import StateGraph, START, END


class State(TypedDict):
    message: str


def hello(state: State):
    return {
        "message": state["message"] + " hello"
    }


graph = StateGraph(State)


graph.add_node(
    "hello",
    hello
)


graph.add_edge(
    START,
    "hello"
)


graph.add_edge(
    "hello",
    END
)


app = graph.compile()


result = app.invoke(
    {
        "message": "world"
    }
)


print(result)
```

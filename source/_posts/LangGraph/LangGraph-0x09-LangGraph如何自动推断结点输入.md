---
title: LangGraph-0x09-LangGraph如何自动推断结点输入
category_bar: true
categories: LangGraph
date: 2026-07-30 20:41:23
---

关于结点函数参数类型，先看{%post_link LangGraph/LangGraph-0x06-input_schema为什么存在%}

## 1 指定了入参类型

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

## 2 没有指定

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

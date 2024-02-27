---
title: Spring源码-07-Bean工厂后置处理器
date: 2023-03-11 00:26:49
tags:
- Spring@6.0.3
categories:
- Spring
---

提供了对Bean工厂中BeanDefinition的修改能力。

## 1 类图

![](Spring源码-07-Bean工厂后置处理器/202212061706549.png)

交互对象都是BeanDefinition，只是入口介质不同

* BeanFactoryPostProcessor是通过ConfigurableListableBeanFactory实例操作BeanDefinition
* BeanDefinitionRegistryPostProcessor是通过BeanDefinitionRegistry实例操作BeanDefinition

## 2 实现

| 实现                            | BeanFactoryPostProcessor抽象 | BeanDefinitionRegistryPostProcessor抽象 |
| ------------------------------- | ---------------------------- | --------------------------------------- |
| ConfigurationClassPostProcessor | &#10003;                     | &#10003;                                |
| EventListenerMethodProcessor    | &#10003;                     | &#10005;                                |


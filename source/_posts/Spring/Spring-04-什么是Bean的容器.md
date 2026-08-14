---
title: Spring-04-什么是Bean的容器
date: 2023-03-11 00:16:41
category_bar: true
categories: Spring
---

实现在DefaultListableBeanFactory，它是整个Spring的基石，刨根问底Spring要解决的问题就是自动化构造对象替代手动构造

并且为了构造对象这个饺子，Spring还准备了BeanDefinition这个醋，BeanFactory干的事情有3个

- BeanDefinition的维护
- Bean对象的构造
- Bean对象生命周期的管理

因此DefaultListableBeanFactory的能力都是围绕上面3个需求展开的
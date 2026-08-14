---
title: Spring-03-什么是BeanPostProcessor
date: 2023-03-11 00:13:56
category_bar: true
categories: Spring
---

它就是一个接口，实现了它就有两个能力，在创建Bean的过程中会去回调到方法，让你干预到Bean的创建过程

## 1 实例化前

```java
	default @Nullable Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
		return bean;
	}
```

## 2 实例化后

```java
	default @Nullable Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
		return bean;
	}
```

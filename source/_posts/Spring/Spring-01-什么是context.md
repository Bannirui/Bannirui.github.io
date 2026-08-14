---
title: Spring-01-什么是context
date: 2023-03-11 00:04:52
category_bar: true
categories: Spring
---

{%post_link Spring/Spring-04-什么是Bean的容器%}

先对BeanFactory有了了解，也就是说一个框架已经有了能力实现对Bean对象的管理，那么下一步是什么，肯定是围绕已有核心能力提供周边建设，context就是面向应用的一个，打包好的，开箱即用的一整套东西

从SpringBoot看的时候，用了AnnotationConfigApplicationContext

## 1 它有什么组件

- beanFactory 实现是DefaultListableBeanFactory
- reader 实现是AnnotatedBeanDefinitionReader
- scanner 实现是ClassPathBeanDefinitionScanner

```java
	public AnnotationConfigApplicationContext() {
		// 会隐式调用到父类GenericApplicationContext 构造一个beanFactory的DefaultListableFactory对象出来
		/**
		 * 为什么要构造下面这两个玩意 本质都是为了找到BeanDefinition 然后把BeanDefinition缓存到BeanFactory里面
		 * 将来给过来的信息可能是一个打了注解的类 也有可能是下包路径
		 * 下面两个各司其职
		 */
		this.reader = new AnnotatedBeanDefinitionReader(this);
		this.scanner = new ClassPathBeanDefinitionScanner(this);
	}
```

```java
	public GenericApplicationContext() {
		// Spring的核心
		this.beanFactory = new DefaultListableBeanFactory();
	}
```

## 2 大名鼎鼎的refresh
---
title: Spring-15-准备Bean创建过程的拦截器
category_bar: true
categories: Spring
date: 2026-08-14 17:24:23
---

{%post_link Spring/Spring-03-什么是BeanPostProcessor%}

## 1 什么时候创建好BeanPostProcessor

```java
				/**
				 * 6 BeanPostProcessor作用时机是Bean实例化过程中 操作对象是Bean对象 在实例创建过程中进行干预
				 * 为什么要先注册BeanPostProcessor呢 因为后面会真正创建Bean 所以一定要在创建业务Bean的前面提前把BeanPostProcessor实例缓存好 到时候拿起来就用
				 * @Autowired AOP等基础设施准备
				 * 准备Bean创建过程中的拦截器
				 *   - 从BeanFactory的beanDefinitionMap中把BeanPostProcessor类型的BeanDefinition找出来
				 *   - 把这些BeanDefinition创建成Bean
				 *   - 把这些Bean缓存到BeanFactory的beanPostProcessors里面 为后面创建Bean做准备
				 */
				registerBeanPostProcessors(beanFactory);
```

## 2 缓存起来

```java
		// 把创建好的BeanPostProcessor的Bean对象缓存到BeanFactory的beanPostProcessors里面 等着后面创建业务Bean的时候对他们的创建过程进行干预
		registerBeanPostProcessors(beanFactory, priorityOrderedPostProcessors);
```
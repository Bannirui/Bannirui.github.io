---
title: SpringBoot-06-启动类的BeanDefinition缓存起来
category_bar: true
categories: SpringBoot
date: 2026-08-14 13:24:45
---

在refresh之前还有一个重要的事情，把启动类的BeanDefinition缓存到beanFactory里面

```java
			/**
			 * spring boot会把很多东西给AnnotationConfigApplicationContext
			 *   - 往AnnotationConfigApplicationContext的beanFactory的1级缓存放了点东西
			 *   - 把启动类的BeanDefinition缓存到了beanFactory的beanDefinitionMap里面 refresh要用
			 *   - 用spring boot的事件机制发布ApplicationContextInitializedEvent转到spring framework
			 *   - 用spring boot的事件机制发布ApplicationPreparedEvent转到spring framework
			 */
			prepareContext(bootstrapContext, context, environment, listeners, applicationArguments, printedBanner);
```

```java
			// SpringBoot启动类被封装成BeanDefinition放到BeanFactory的这个缓存里面
			this.beanDefinitionMap.put(beanName, beanDefinition);
```
---
title: Spring-14-开始大规模解析BeanDefinition
category_bar: true
categories: Spring
date: 2026-08-14 17:19:52
---

整个invokeBeanFactoryPostProcessors核心步骤有两个

- 1 尝试创建新的BeanDefinition
- 2 尝试修改BeanDefinition

在此就要先熟悉一下所谓的BeanFactoryPostProcessor了 {%post_link Spring/Spring-07-所谓的BeanFactoryPostProcessor%}

## 1 怎么创建BeanDefinition

### 1.1 怎么处理优先级的

#### 1.1.1 最高优先级

```java
			/**
	 		 * 从BeanFactory的beanDefinitionMap里面找看看有没有BeanDefinitionRegistryPostProcessor
			 * 这个时候会把ConfigurationClassPostProcessor的BeanDefinition找出来 它是实现了PriorityOrdered的
			 *
			 * 下面的逻辑可以看到
			 *   - 1 优先级是按照PriorityOrdered>Ordered
			 *   - 2 为什么在处理Ordered优先级的时候又要从BeanFactory拿一次beanDefinitionMap 因为实现了BeanDefinitionRegistryPostProcessor的postProcessor能力更强 它有创建BeanDefinition的能力 也就是说处理完PriorityOrdered之后可能BeanFactory已经额外缓存了一些新的BeanDefinition
			 */
			String[] postProcessorNames =
					beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
			for (String ppName : postProcessorNames) {
				if (beanFactory.isTypeMatch(ppName, PriorityOrdered.class)) {
					// 用这些BeanDefinitionRegistryPostProcessor的BeanDefinition创造Bean
					currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
					processedBeans.add(ppName);
				}
			}
			sortPostProcessors(currentRegistryProcessors, beanFactory);
			registryProcessors.addAll(currentRegistryProcessors);
			/**
			 * BeanDefinitionRegistryPostProcessor这种postProcessor是有创造BeanDefinition能力的
			 * ConfigurationClassPostProcessor的postProcessBeanDefinitionRegistry会被回调到
			 * 因为这个方法的执行 BeanFactory可能因此多了一些新的BeanDefinition
			 */
			invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry, beanFactory.getApplicationStartup());
			currentRegistryProcessors.clear();
```

#### 1.1.2 次高优先级

```java
			// 这就是为什么要重新从BeanFactory的beanDefinitionMap检索一次 因为经过上面 现在的beanDefinitionMap可能已经多了一些BeanDefinition
			postProcessorNames = beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
			for (String ppName : postProcessorNames) {
				if (!processedBeans.contains(ppName) && beanFactory.isTypeMatch(ppName, Ordered.class)) {
					currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
					processedBeans.add(ppName);
				}
			}
			sortPostProcessors(currentRegistryProcessors, beanFactory);
			registryProcessors.addAll(currentRegistryProcessors);
			invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry, beanFactory.getApplicationStartup());
			currentRegistryProcessors.clear();
```

#### 1.1.3 没有优先级

```java
			// 上面已经处理了PriorityOrdered和Ordered的优先级 剩下来BeanFactory的beanDefinitionMap里面可能还有一些BeanDefinitionRegistryPostProcessor 如果有的话就要继续掏出来创建成Bean然后回调它的postProcessBeanDefinitionRegistry 当然可能会因为这个方法的执行产生了新的BeanDefinition 那就循环往复下去
			boolean reiterate = true;
			while (reiterate) {
				reiterate = false;
				postProcessorNames = beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
				for (String ppName : postProcessorNames) {
					if (!processedBeans.contains(ppName)) {
						currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
						processedBeans.add(ppName);
						reiterate = true;
					}
				}
				sortPostProcessors(currentRegistryProcessors, beanFactory);
				registryProcessors.addAll(currentRegistryProcessors);
				invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry, beanFactory.getApplicationStartup());
				currentRegistryProcessors.clear();
			}

			// Now, invoke the postProcessBeanFactory callback of all processors handled so far.
			invokeBeanFactoryPostProcessors(registryProcessors, beanFactory);
			invokeBeanFactoryPostProcessors(regularPostProcessors, beanFactory);
```

### 1.2 看看最重要的类

{%post_link Spring/Spring-08-ConfigurationClassPostProcessor根据注解创建新BeanDefinition%}

## 2 怎么修改BeanDefinition

这个地方跟上面如出一辙，也是优先级回调BeanFactoryPostProcessor的方法
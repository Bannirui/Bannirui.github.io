---
title: Spring-02-怎么根据启动类找到所有BeanDefinition的
category_bar: true
categories: Spring
date: 2026-08-14 20:18:09
---

{%post_link Spring/Spring-01-什么是context%}讲到了会构造一个AnnotatedBeanDefinitionReader

## 1 构造context的时候就已经往BeanFactory放了一个重要的BeanDefinition

```java
	public AnnotatedBeanDefinitionReader(BeanDefinitionRegistry registry, Environment environment) {
		Assert.notNull(registry, "BeanDefinitionRegistry must not be null");
		Assert.notNull(environment, "Environment must not be null");
		this.registry = registry;
		this.conditionEvaluator = new ConditionEvaluator(registry, environment, null);
		// ConfigurationClassPostProcessor这个重要的BeanDefinition会被缓存到BeanFactory的beanDefinitionMap
		AnnotationConfigUtils.registerAnnotationConfigProcessors(this.registry);
	}
```

```java
		if (!registry.containsBeanDefinition(CONFIGURATION_ANNOTATION_PROCESSOR_BEAN_NAME)) {
			RootBeanDefinition def = new RootBeanDefinition(ConfigurationClassPostProcessor.class);
			def.setSource(source);
			// 会把ConfigurationClassPostProcessor这个BeanDefinition缓存到BeanFactory的beanDefinitionMap 在refresh的invokeBeanFactoryPostProcessors会掏出来创建成Bean 然后从启动类注解开始找到所有的BeanDefinition
			beanDefs.add(registerPostProcessor(registry, def, CONFIGURATION_ANNOTATION_PROCESSOR_BEAN_NAME));
		}
```

## 2 什么是BeanDefinitionRegistryPostProcessor

```java
public class ConfigurationClassPostProcessor implements BeanDefinitionRegistryPostProcessor,
		BeanRegistrationAotProcessor, BeanFactoryInitializationAotProcessor, PriorityOrdered,
		ResourceLoaderAware, ApplicationStartupAware, BeanClassLoaderAware, EnvironmentAware {
```

```java
/**
 * Extension to the standard {@link BeanFactoryPostProcessor} SPI, allowing for
 * the registration of further bean definitions <i>before</i> regular
 * BeanFactoryPostProcessor detection kicks in. In particular,
 * BeanDefinitionRegistryPostProcessor may register further bean definitions
 * which in turn define BeanFactoryPostProcessor instances.
 *
 * @author Juergen Hoeller
 * @since 3.0.1
 * @see org.springframework.context.annotation.ConfigurationClassPostProcessor
 */
// 从注释就明白了 BeanFactoryPostProcessor的能力是改造现有的BeanDefinition 而BeanDefinitionRegistryPostProcessor是BeanFactoryPostProcessor的加强版 还有直接创建BeanDefinition的能力
public interface BeanDefinitionRegistryPostProcessor extends BeanFactoryPostProcessor {
```

## 3 它是怎么发挥作用的

它的作用就是拿着SpringBoot启动时候缓存的启动类，根据注解找到所有的Java类包装成BeanDefinition缓存到BeanFactory

{%post_link Spring/Spring-14-开始大规模解析BeanDefinition%}

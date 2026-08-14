---
title: Spring-07-所谓的BeanFactoryPostProcessor
date: 2023-03-11 00:26:49
category_bar: true
categories: Spring
---

## 1 BeanFactoryPostProcessor

```java
@FunctionalInterface
public interface BeanFactoryPostProcessor {

	/**
	 * Modify the application context's internal bean factory after its standard
	 * initialization. All bean definitions will have been loaded, but no beans
	 * will have been instantiated yet. This allows for overriding or adding
	 * properties even to eager-initializing beans.
	 * @param beanFactory the bean factory used by the application context
	 * @throws org.springframework.beans.BeansException in case of errors
	 */
	// 提供了修改BeanFactory中的BeanDefinition的能力
	void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException;

}
```

## 2 BeanDefinitionRegistryPostProcessor

```java
// 从注释就明白了 BeanFactoryPostProcessor的能力是改造现有的BeanDefinition 而BeanDefinitionRegistryPostProcessor是BeanFactoryPostProcessor的加强版 还有直接创建BeanDefinition的能力
public interface BeanDefinitionRegistryPostProcessor extends BeanFactoryPostProcessor {

	/**
	 * Modify the application context's internal bean definition registry after its
	 * standard initialization. All regular bean definitions will have been loaded,
	 * but no beans will have been instantiated yet. This allows for adding further
	 * bean definitions before the next post-processing phase kicks in.
	 * @param registry the bean definition registry used by the application context
	 * @throws org.springframework.beans.BeansException in case of errors
	 */
	// 不仅有修改BeanDefinition的能力 还有创建新的BeanDefinition的能力
	void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) throws BeansException;

	/**
	 * Empty implementation of {@link BeanFactoryPostProcessor#postProcessBeanFactory}
	 * since custom {@code BeanDefinitionRegistryPostProcessor} implementations will
	 * typically only provide a {@link #postProcessBeanDefinitionRegistry} method.
	 * @since 6.1
	 */
	// 修改BeanDefinition的能力
	@Override
	default void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
	}

}
```

## 3 典型的创建BeanDefinition的类

{%post_link Spring/Spring-08-ConfigurationClassPostProcessor根据注解创建新BeanDefinition%}

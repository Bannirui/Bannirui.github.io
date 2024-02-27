---
title: Spring源码-05-容器refresh之invokeBeanFactoryPostProcessors方法
date: 2023-03-11 00:20:59
tags:
- Spring@6.0.3
categories:
- Spring
---

ConfigurationClassPostProcessor作用的时机 扫描注册用户BeanDefinition到Bean工厂。

## 1 Bean工厂后置处理器

```java
// AbstractApplicationContext.java
protected void invokeBeanFactoryPostProcessors(ConfigurableListableBeanFactory beanFactory) {
    /**
		 * ConfigurationClassPostProcessor作用的时机
		 */
    PostProcessorRegistrationDelegate.invokeBeanFactoryPostProcessors(beanFactory, this.getBeanFactoryPostProcessors());

    // Detect a LoadTimeWeaver and prepare for weaving, if found in the meantime
    // (e.g. through an @Bean method registered by ConfigurationClassPostProcessor)
    if (!NativeDetector.inNativeImage() && beanFactory.getTempClassLoader() == null && beanFactory.containsBean(LOAD_TIME_WEAVER_BEAN_NAME)) {
        beanFactory.addBeanPostProcessor(new LoadTimeWeaverAwareProcessor(beanFactory));
        beanFactory.setTempClassLoader(new ContextTypeMatchClassLoader(beanFactory.getBeanClassLoader()));
    }
}
```

```java
// PostProcessorRegistrationDelegate.java
/**
	 * 容器初始化后最多注册了如下后置处理器
	 *     - ConfigurationClassPostProcessor
	 *     - AutowiredAnnotationBeanPostProcessor
	 *     - CommonAnnotationBeanPostProcessor
	 *     - InitDestroyAnnotationBeanPostProcessor
	 *     - PersistenceAnnotationBeanPostProcessor
	 *     - EventListenerMethodProcessor
	 *     - DefaultEventListenerFactory
	 *
	 * 从已经注册的BeanDefinition中
	 *     - 找到BeanDefinitionRegistryPostProcessor类型
	 *         - 优先级1 实现了PriorityOrdered接口的实例排序后依次执行
	 *         - 优先级2 实现了Ordered接口的实例排序后依次执行
	 *         - 优先级3 剩余没执行过的依次执行
	 *     - 找到BeanFactoryPostProcessor类型
	 *         - 优先级1 实现了PriorityOrdered接口的实例排序后依次执行
	 *         - 优先级2 实现了Ordered接口的实例排序后依次执行
	 *         - 优先级3 没有实现PriorityOrdered接口和Ordered接口的依次执行
	 * 实际产生作用的就两个后置处理器
	 *     - ConfigurationClassPostProcessor第一优先级
	 *         - 是BeanDefinitionRegistryPostProcessor类型
	 *         - 实现了PriorityOrdered接口的实例
	 *     - EventListenerMethodProcessor
	 *         - 实现了BeanFactoryPostProcessor
	 *         - 没有实现排序接口
	 */
public static void invokeBeanFactoryPostProcessors(
    ConfigurableListableBeanFactory beanFactory, List<BeanFactoryPostProcessor> beanFactoryPostProcessors) {

    // WARNING: Although it may appear that the body of this method can be easily
    // refactored to avoid the use of multiple loops and multiple lists, the use
    // of multiple lists and multiple passes over the names of processors is
    // intentional. We must ensure that we honor the contracts for PriorityOrdered
    // and Ordered processors. Specifically, we must NOT cause processors to be
    // instantiated (via getBean() invocations) or registered in the ApplicationContext
    // in the wrong order.
    //
    // Before submitting a pull request (PR) to change this method, please review the
    // list of all declined PRs involving changes to PostProcessorRegistrationDelegate
    // to ensure that your proposal does not result in a breaking change:
    // https://github.com/spring-projects/spring-framework/issues?q=PostProcessorRegistrationDelegate+is%3Aclosed+label%3A%22status%3A+declined%22

    // Invoke BeanDefinitionRegistryPostProcessors first, if any.
    Set<String> processedBeans = new HashSet<>(); // 缓存着已经执行过的实例名称 避免重复执行

    if (beanFactory instanceof BeanDefinitionRegistry registry) {
        List<BeanFactoryPostProcessor> regularPostProcessors = new ArrayList<>();
        List<BeanDefinitionRegistryPostProcessor> registryProcessors = new ArrayList<>();

        for (BeanFactoryPostProcessor postProcessor : beanFactoryPostProcessors) {
            if (postProcessor instanceof BeanDefinitionRegistryPostProcessor registryProcessor) {
                registryProcessor.postProcessBeanDefinitionRegistry(registry);
                registryProcessors.add(registryProcessor);
            }
            else {
                regularPostProcessors.add(postProcessor);
            }
        }

        // Do not initialize FactoryBeans here: We need to leave all regular beans
        // uninitialized to let the bean factory post-processors apply to them!
        // Separate between BeanDefinitionRegistryPostProcessors that implement
        // PriorityOrdered, Ordered, and the rest.
        List<BeanDefinitionRegistryPostProcessor> currentRegistryProcessors = new ArrayList<>();

        /**
			 * 容器初始化后最多注册了如下后置处理器
			 *     - ConfigurationClassPostProcessor
			 *     - AutowiredAnnotationBeanPostProcessor
			 *     - CommonAnnotationBeanPostProcessor
			 *     - InitDestroyAnnotationBeanPostProcessor
			 *     - PersistenceAnnotationBeanPostProcessor
			 *     - EventListenerMethodProcessor
			 *     - DefaultEventListenerFactory
			 *
			 * 从已经注册的BeanDefinition中
			 *     - 找到BeanDefinitionRegistryPostProcessor类型
			 *         - 优先级1 实现了PriorityOrdered接口的实例排序后依次执行
			 *         - 优先级2 实现了Ordered接口的实例排序后依次执行
			 *         - 优先级3 剩余没执行过的依次执行
			 *
			 * ConfigurationClassPostProcessor
			 *     - 是BeanDefinitionRegistryPostProcessor类型
			 *     - 实现了PriorityOrdered接口的实例
			 */
        // First, invoke the BeanDefinitionRegistryPostProcessors that implement PriorityOrdered.
        String[] postProcessorNames =
            beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
        for (String ppName : postProcessorNames) {
            if (beanFactory.isTypeMatch(ppName, PriorityOrdered.class)) {
                currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class)); // 获取Bean实例
                processedBeans.add(ppName);
            }
        }
        sortPostProcessors(currentRegistryProcessors, beanFactory); // 排序
        registryProcessors.addAll(currentRegistryProcessors);
        invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry, beanFactory.getApplicationStartup()); // 依次执行
        currentRegistryProcessors.clear();

        // Next, invoke the BeanDefinitionRegistryPostProcessors that implement Ordered.
        postProcessorNames = beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
        for (String ppName : postProcessorNames) {
            if (!processedBeans.contains(ppName) && beanFactory.isTypeMatch(ppName, Ordered.class)) {
                currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
                processedBeans.add(ppName);
            }
        }
        sortPostProcessors(currentRegistryProcessors, beanFactory); // 排序
        registryProcessors.addAll(currentRegistryProcessors);
        invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry, beanFactory.getApplicationStartup()); // 依次执行
        currentRegistryProcessors.clear();

        // Finally, invoke all other BeanDefinitionRegistryPostProcessors until no further ones appear.
        boolean reiterate = true;
        while (reiterate) {
            reiterate = false;
            postProcessorNames = beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
            for (String ppName : postProcessorNames) {
                if (!processedBeans.contains(ppName)) { // 已经执行过的跳过
                    currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
                    processedBeans.add(ppName);
                    reiterate = true;
                }
            }
            /**
				 * 上面BeanDefinitionRegistryPostProcessor类型的处理器已经有执行
				 * 可能向Bean工厂注册了新的BeanDefinition
				 * 因此此时再从Bean工厂获取BeanDefinitionRegistryPostProcessor的还没执行的Bean
				 *     - 新添加 实现了PriorityOrdered接口
				 *     - 新添加 实现了Ordered接口
				 *     - 新添加 没实现PriorityOrdered和Ordered接口
				 *     - 以前添加 没实现PriorityOrdered和Ordered接口
				 */
            sortPostProcessors(currentRegistryProcessors, beanFactory);
            registryProcessors.addAll(currentRegistryProcessors);
            invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry, beanFactory.getApplicationStartup()); // 依次执行
            currentRegistryProcessors.clear();
        }

        // Now, invoke the postProcessBeanFactory callback of all processors handled so far.
        invokeBeanFactoryPostProcessors(registryProcessors, beanFactory);
        invokeBeanFactoryPostProcessors(regularPostProcessors, beanFactory);
    }

    else {
        // Invoke factory processors registered with the context instance.
        invokeBeanFactoryPostProcessors(beanFactoryPostProcessors, beanFactory);
    }

    /**
		 * 从已经注册的BeanDefinition中
		 *     - 找到BeanFactoryPostProcessor类型
		 *         - 优先级1 实现了PriorityOrdered接口的实例排序后依次执行
		 *         - 优先级2 实现了Ordered接口的实例排序后依次执行
		 *         - 优先级3 没有实现PriorityOrdered接口和Ordered接口的依次执行
		 */
    // Do not initialize FactoryBeans here: We need to leave all regular beans
    // uninitialized to let the bean factory post-processors apply to them!
    String[] postProcessorNames =
        beanFactory.getBeanNamesForType(BeanFactoryPostProcessor.class, true, false);

    // Separate between BeanFactoryPostProcessors that implement PriorityOrdered,
    // Ordered, and the rest.
    List<BeanFactoryPostProcessor> priorityOrderedPostProcessors = new ArrayList<>(); // 缓存实现了PriorityOrdered的实例
    List<String> orderedPostProcessorNames = new ArrayList<>(); // 缓存实现了Ordered接口的名称
    List<String> nonOrderedPostProcessorNames = new ArrayList<>(); // 缓存没有实现PriorityOrdered和Ordered接口的名称
    for (String ppName : postProcessorNames) {
        if (processedBeans.contains(ppName)) {
            // skip - already processed in first phase above
        }
        else if (beanFactory.isTypeMatch(ppName, PriorityOrdered.class)) { // 实现了PriorityOrdered接口
            priorityOrderedPostProcessors.add(beanFactory.getBean(ppName, BeanFactoryPostProcessor.class));
        }
        else if (beanFactory.isTypeMatch(ppName, Ordered.class)) { // 实现了Ordered接口
            orderedPostProcessorNames.add(ppName);
        }
        else {
            nonOrderedPostProcessorNames.add(ppName);
        }
    }

    // First, invoke the BeanFactoryPostProcessors that implement PriorityOrdered.
    sortPostProcessors(priorityOrderedPostProcessors, beanFactory); // 排序
    invokeBeanFactoryPostProcessors(priorityOrderedPostProcessors, beanFactory); // 依次执行

    // Next, invoke the BeanFactoryPostProcessors that implement Ordered.
    List<BeanFactoryPostProcessor> orderedPostProcessors = new ArrayList<>(orderedPostProcessorNames.size()); // 缓存实现了Ordered的实例
    for (String postProcessorName : orderedPostProcessorNames) {
        orderedPostProcessors.add(beanFactory.getBean(postProcessorName, BeanFactoryPostProcessor.class));
    }
    sortPostProcessors(orderedPostProcessors, beanFactory); // 排序
    invokeBeanFactoryPostProcessors(orderedPostProcessors, beanFactory); // 依次执行

    // Finally, invoke all other BeanFactoryPostProcessors.
    List<BeanFactoryPostProcessor> nonOrderedPostProcessors = new ArrayList<>(nonOrderedPostProcessorNames.size());
    for (String postProcessorName : nonOrderedPostProcessorNames) {
        nonOrderedPostProcessors.add(beanFactory.getBean(postProcessorName, BeanFactoryPostProcessor.class)); // 没有顺序优先级要求的
    }
    invokeBeanFactoryPostProcessors(nonOrderedPostProcessors, beanFactory); // 执行

    // Clear cached merged bean definitions since the post-processors might have
    // modified the original metadata, e.g. replacing placeholders in values...
    beanFactory.clearMetadataCache();
}
```

## 2 {% post_link Spring源码-06-Bean工厂之getBean方法 getBean方法 %}

## 3 {% post_link Spring源码-07-Bean工厂后置处理器 Bean工厂后置处理器回调 %}

## 4 {% post_link Spring源码-08-后置处理器ConfigurationClassPostProcessor ConfigurationClassPostProcessor后置处理器回调 %}


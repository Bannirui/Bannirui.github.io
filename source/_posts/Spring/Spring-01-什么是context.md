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

```java
	@Override
	public void refresh() throws BeansException, IllegalStateException {
		this.startupShutdownLock.lock();
		try {
			this.startupShutdownThread = Thread.currentThread();

			StartupStep contextRefresh = this.applicationStartup.start("spring.context.refresh");

			// Prepare this context for refreshing.
			// 1 准备context
			prepareRefresh();

			// Tell the subclass to refresh the internal bean factory.
			// 2 从context中把BeanFactory对象拿出来 DefaultListableBeanFactory
			ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

			// Prepare the bean factory for use in this context.
			// 3 增强BeanFactory context给BeanFactory准备一些基础设施
			prepareBeanFactory(beanFactory);

			try {
				// Allows post-processing of the bean factory in context subclasses.
				// 4 context的一个扩展点 默认是空实现 预留的口子 想做一些增强操作的就重写这个方法
				postProcessBeanFactory(beanFactory);
				StartupStep beanPostProcess = this.applicationStartup.start("spring.context.beans.post-process");
				// Invoke factory processors registered as beans in the context.
				/**
				 * 5 让BeanFactoryPostProcessor修改BeanDefinition
				 * SpringBoot启动的时候只往BeanFactory里面缓存了一个启动类的BeanDefinition 在这个地方就要开始围绕这个启动类的BeanDefinition找到枝枝蔓蔓
				 * BeanFactoryPostProcessor作用时机是在Bean实例化之前 操作对象是BeanDefinition
				 */
				invokeBeanFactoryPostProcessors(beanFactory);
				// Register bean processors that intercept bean creation.
				/**
				 * 6 BeanPostProcessor作用时机是Bean实例化过程中 操作对象是Bean对象 在实例创建过程中进行干预
				 * 为什么要先注册BeanPostProcessor呢 因为后面会真正创建Bean
				 */
				registerBeanPostProcessors(beanFactory);
				beanPostProcess.end();

				// Initialize message source for this context.
				// 7 国际化
				initMessageSource();

				// Initialize event multicaster for this context.
				// 8 构造事件发布器
				initApplicationEventMulticaster();

				// Initialize other special beans in specific context subclasses.
				// 9 给具体的ApplicationContext扩展
				onRefresh();

				// Check for listener beans and register them.
				// 10 注册ApplicationListener
				registerListeners();

				// Instantiate all remaining (non-lazy-init) singletons.
				// 11 真正创建Bean
				finishBeanFactoryInitialization(beanFactory);

				// Last step: publish corresponding event.
				// 12 所有主要的Bean都创建完成了 对context做一些最终的工作
				finishRefresh();
			}

			catch (RuntimeException | Error ex) {
				if (logger.isWarnEnabled()) {
					logger.warn("Exception encountered during context initialization - " +
							"cancelling refresh attempt: " + ex);
				}

				// Stop already started Lifecycle beans to avoid dangling resources.
				if (this.lifecycleProcessor != null && this.lifecycleProcessor.isRunning()) {
					try {
						this.lifecycleProcessor.stop();
					}
					catch (Throwable ex2) {
						logger.warn("Exception thrown from LifecycleProcessor on cancelled refresh", ex2);
					}
				}

				// Destroy already created singletons to avoid dangling resources.
				destroyBeans();

				// Reset 'active' flag.
				cancelRefresh(ex);

				// Propagate exception to caller.
				throw ex;
			}

			finally {
				contextRefresh.end();
			}
		}
		finally {
			this.startupShutdownThread = null;
			this.startupShutdownLock.unlock();
		}
	}
```

我会把核心的步骤单独成一个篇章

- 1 准备context
- 2 从context中把BeanFactory对象拿出来
- 3 增强BeanFactory {%post_link Spring/Spring-13-增强BeanFactory%}
- 4 扩展点
- 5 让BeanFactoryPostProcessor修改BeanDefinition {%post_link Spring/Spring-14-开始大规模解析BeanDefinition%}
- 6 让BeanPostProcessor修改Bean {%post_link Spring/Spring-15-准备Bean创建过程的拦截器%}
- 7 国际化
- 8 构造事件发布器
- 9 扩展点
- 10 注册ApplicationListener
- 11 真正创建Bean {%post_link Spring/Spring-16-真正创建Bean%}
- 12 Bean完成创建

---
title: Spring-13-增强BeanFactory
category_bar: true
categories: Spring
date: 2026-08-14 17:13:36
---

```java
	/**
	 * 刚把DefaultListableBeanFactory从context中拿出来
	 * 现在的BeanFactory还不知道当前ApplicationContext的环境 ClassLoader Aware回调 事件发布器 这些都是context才特有的能力
	 * context把这些能力赋予BeanFactory
	 *   - 配置基础运行环境
	 *   - 安装BeanPostProcessor
	 *   - 告诉BeanFactory有些Aware接口的Bean不要按照普通的依赖处理
	 *   - 注册特殊的可解析依赖
	 *   - 注册Spring基础对象
	 */
	protected void prepareBeanFactory(ConfigurableListableBeanFactory beanFactory) {
		// Tell the internal bean factory to use the context's class loader etc.
		// BeanFactory
		// jvm中的代码都是.class字节码 没法直接运行 都是需要一个ClassLoader的 BeanFactory的工作中需要根据路径找到java类 拿着java类反射创建对象等都需要一个ClassLoader
		beanFactory.setBeanClassLoader(getClassLoader());
		// 负责Spring表达式的解析 比如@Value("#{...}")
		beanFactory.setBeanExpressionResolver(new StandardBeanExpressionResolver(beanFactory.getBeanClassLoader()));
		beanFactory.addPropertyEditorRegistrar(new ResourceEditorRegistrar(this, getEnvironment()));

		// Configure the bean factory with context callbacks.
		/**
		 * ApplicationContextAwareProcessor是一个BeanPostProcessor
		 * 如果某个Bean实现了ApplicationContextAware接口 那么在创建Bean的过程中 这个BeanPostProcessor会挥作用 回调这个Aware接口的setApplicationContext方法
		 */
		beanFactory.addBeanPostProcessor(new ApplicationContextAwareProcessor(this));
		// 下面的几个Aware接口的实现类 不要当成普通的依赖解析蛸
		beanFactory.ignoreDependencyInterface(EnvironmentAware.class);
		beanFactory.ignoreDependencyInterface(EmbeddedValueResolverAware.class);
		beanFactory.ignoreDependencyInterface(ResourceLoaderAware.class);
		beanFactory.ignoreDependencyInterface(ApplicationEventPublisherAware.class);
		beanFactory.ignoreDependencyInterface(MessageSourceAware.class);
		beanFactory.ignoreDependencyInterface(ApplicationContextAware.class);
		beanFactory.ignoreDependencyInterface(ApplicationStartupAware.class);

		// BeanFactory interface not registered as resolvable type in a plain factory.
		// MessageSource registered (and found for autowiring) as a bean.
		// 如果用@Autowired注入下面几个类型 就用给定的实例对象
		beanFactory.registerResolvableDependency(BeanFactory.class, beanFactory);
		beanFactory.registerResolvableDependency(ResourceLoader.class, this);
		beanFactory.registerResolvableDependency(ApplicationEventPublisher.class, this);
		beanFactory.registerResolvableDependency(ApplicationContext.class, this);

		// Register early post-processor for detecting inner beans as ApplicationListeners.
		// 为Spring事件机制做准备 Spring在创建Bean的时候发现某个Bean是实现了ApplicationListener接口的时候 就把这个Bean注册到ApplicationContext
		beanFactory.addBeanPostProcessor(new ApplicationListenerDetector(this));

		// Detect a LoadTimeWeaver and prepare for weaving, if found.
		if (!NativeDetector.inNativeImage() && beanFactory.containsBean(LOAD_TIME_WEAVER_BEAN_NAME)) {
			beanFactory.addBeanPostProcessor(new LoadTimeWeaverAwareProcessor(beanFactory));
			// Set a temporary ClassLoader for type matching.
			beanFactory.setTempClassLoader(new ContextTypeMatchClassLoader(beanFactory.getBeanClassLoader()));
		}

		// Register default environment beans.
		// 对于Spring而言 并不是所有的Bean都通过BeanFactory用BeanDefinition来创建的 下面这几个直接放到BeanFactory的1级缓存里面
		if (!beanFactory.containsLocalBean(ENVIRONMENT_BEAN_NAME)) {
			beanFactory.registerSingleton(ENVIRONMENT_BEAN_NAME, getEnvironment());
		}
		if (!beanFactory.containsLocalBean(SYSTEM_PROPERTIES_BEAN_NAME)) {
			beanFactory.registerSingleton(SYSTEM_PROPERTIES_BEAN_NAME, getEnvironment().getSystemProperties());
		}
		if (!beanFactory.containsLocalBean(SYSTEM_ENVIRONMENT_BEAN_NAME)) {
			beanFactory.registerSingleton(SYSTEM_ENVIRONMENT_BEAN_NAME, getEnvironment().getSystemEnvironment());
		}
		if (!beanFactory.containsLocalBean(APPLICATION_STARTUP_BEAN_NAME)) {
			beanFactory.registerSingleton(APPLICATION_STARTUP_BEAN_NAME, getApplicationStartup());
		}
	}
```
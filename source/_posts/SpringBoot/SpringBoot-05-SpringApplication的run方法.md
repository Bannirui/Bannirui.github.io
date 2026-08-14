---
title: SpringBoot-05-SpringApplication的run方法
category_bar: true
categories: SpringBoot
date: 2026-08-14 10:42:59
---

```java
	public ConfigurableApplicationContext run(String... args) {
		Startup startup = Startup.create();
		if (this.properties.isRegisterShutdownHook()) {
			SpringApplication.shutdownHook.enableShutdownHookAddition();
		}
		DefaultBootstrapContext bootstrapContext = createBootstrapContext();
		ConfigurableApplicationContext context = null;
		configureHeadlessProperty();
		// 会拿到EventPublishingRunListener 配置在了spring.factories里面 启动时候会加载进来
		SpringApplicationRunListeners listeners = getRunListeners(args);
		// 1 spring boot的事件机制发布ApplicationStartingEvent转到spring framework
		listeners.starting(bootstrapContext, this.mainApplicationClass);
		try {
			ApplicationArguments applicationArguments = new DefaultApplicationArguments(args);
			// 2 spring boot的事件机制发布ApplicationEnvironmentPreparedEvent转到spring framework
			ConfigurableEnvironment environment = prepareEnvironment(listeners, bootstrapContext, applicationArguments);
			Banner printedBanner = printBanner(environment);
			// 创建spring的容器 创建好后才拥有spring的事件发布机制 在此之前的时间发布靠的是spring boot实现的另一套事件机制
			/**
			 * 构造spring的context
			 * 有两种方式
			 *   - 1 在spring.factories配置文件里面指定ApplicationContextFactory的实现
			 *   - 2 没有配置文件里面显式指定就会用默认的AnnotationConfigApplicationContext
			 * 这个时候构造出来的context很干净 只有
			 *   - reader
			 *   - scanner
			 *   - DefaultListableBeanFactory的beanFactory对象
			 */
			context = createApplicationContext();
			context.setApplicationStartup(this.applicationStartup);
			/**
			 * spring boot会把很多东西给AnnotationConfigApplicationContext
			 * 3 用spring boot的事件机制发布ApplicationContextInitializedEvent转到spring framework
			 * 4 用spring boot的事件机制发布ApplicationPreparedEvent转到spring framework
			 * 
			 * 往AnnotationConfigApplicationContext的beanFactory的1级缓存放了点东西
			 */
			prepareContext(bootstrapContext, context, environment, listeners, applicationArguments, printedBanner);
			// 进入到spring framework的refresh 执行完之后会拥有spring的事件发布机制 两套机制共存
			refreshContext(context);
			afterRefresh(context, applicationArguments);
			Duration timeTakenToStarted = startup.started();
			if (this.properties.isLogStartupInfo()) {
				new StartupInfoLogger(this.mainApplicationClass, environment).logStarted(getApplicationLog(), startup);
			}
			// 5 用spring boot的事件机制发布ApplicationStartedEvent转到spring framework
			listeners.started(context, timeTakenToStarted);
			callRunners(context, applicationArguments);
		}
		catch (Throwable ex) {
			// 6 ApplicationFailedEvent属于特殊 跟正常的生命周期事件不一样处理
			throw handleRunFailure(context, ex, listeners);
		}
		try {
			if (context.isRunning()) {
				// 7 用spring boot的事件机制发布ApplicationReadyEvent转到spring framework
				listeners.ready(context, startup.ready());
			}
		}
		catch (Throwable ex) {
			throw handleRunFailure(context, ex, null);
		}
		return context;
	}
```

其实就两套东西

- 1 spring boot依赖SPI加载了EventPublishingRunListener来通知自己扩展的生命周期事件 {%post_link SpringBoot/SpringBoot-01-SpringBoot的生命周期怎么控制的%}
- 2 构造了spring的context AnnotationConfigureApplicationContext 这个context里面很干净 只有
  - reader
  - scanner
  - DefaultListableBeanFactory
  - 又往里面加了自己构造的Environment

生命周期事件已经看过了，所以还是回到了spring的原理{%post_link Spring/Spring-00-环境搭建%}

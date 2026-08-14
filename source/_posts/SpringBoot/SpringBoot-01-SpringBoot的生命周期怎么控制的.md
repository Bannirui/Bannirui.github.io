---
title: SpringBoot-01-SpringBoot的生命周期怎么控制的
category_bar: true
categories: SpringBoot
date: 2026-08-13 20:14:14
---

如果要二开SpringBoot，本质就是利用SpringBoot的生命周期事件，在不同的时间节点会收到对应的通知，然后干自己想干的事情，这就是二开。

那么SpringBoot是怎么设计自己的生命周期的

## 1 有哪些生命周期

spring体系的ApplicationEvent派生出spring boot体系的SpringApplicationEvent

在此基础上我按照从先到后的顺序，spring boot定义了生命周期

- 1 ApplicationStartingEvent
- 2 ApplicationEnvironmentPreparedEvent
- 3 ApplicationContextInitializedEvent
- 4 ApplicationPreparedEvent
- 5 ApplicationStartedEvent
- 6 ApplicationFailedEvent
- 7 ApplicationReadyEvent

这7大事件本质都是spring framework的事件体系，那么spring boot是怎么处理事件的呢

看过{%post_link Spring/Spring源码-03-容器refresh%}就应该清楚在执行完refresh后就拥有了发布事件能力

- 第1 spring boot在refresh之前是完全没有建立spring framework的事件发布能力的
- 第2 自始至终 这几个事件的发布spring boot都是用自己建设的机制完成的

## 2 EventPublishingRunListener

spring boot把这个类注册在了spring.factories里面在启动过程中会扫描加载出来

{%post_link SpringBoot/SpringBoot-03-SpringBoot的SPI%}

```java
		// 会拿到EventPublishingRunListener 配置在了spring.factories里面 启动时候会加载进来
		SpringApplicationRunListeners listeners = getRunListeners(args);
```

```java
	/**
	 * 这个类配置在了spring.factories里面了
	 * 为什么需要把SpringApplication给过来 重点是要为了application里面的listeners缓存了EventPublishingRunListener
	 */
	EventPublishingRunListener(SpringApplication application, String[] args) {
		this.application = application;
		this.args = args;
		// 这个是核心 负责发布spring boot的生命周期事件
		this.initialMulticaster = new SimpleApplicationEventMulticaster();
	}
```

生命周期事件的发布就全靠它了，它用的实现就是{%post_link Spring/Spring-11-事件传播器%}

## 3 模板+策略的设计

这些事件的发布流程都是一样的，此时就用到了模板

```java
	/**
	 * 用EventPublishingRunListener发布spring boot的生命周期事件
	 * @param stepName
	 * @param listenerAction 函数式编程 就是一个函数对象 EventPublishingRunListener对象会实现所有的方法
	 * @param stepAction
	 */
	private void doWithListeners(String stepName, Consumer<SpringApplicationRunListener> listenerAction,
			@Nullable Consumer<StartupStep> stepAction) {
		StartupStep step = this.applicationStartup.start(stepName);
		// listeners里面缓存了EventPublishingRunListener对象 只要执行它的的listenerAction这个方法就行
		this.listeners.forEach(listenerAction);
		if (stepAction != null) {
			stepAction.accept(step);
		}
		step.end();
	}
```

那么只要在发布不同的事件时候丢一个不同的lambda过来就行，然后给转到事件发布器就行

```java
	private void multicastInitialEvent(ApplicationEvent event) {
		refreshApplicationListeners();
		// 通过SimpleApplicationEventMulticaster回调到springframework里面的ApplicationListener的onApplicationEvent方法
		this.initialMulticaster.multicastEvent(event);
	}
```

## 4 不同的事件

先看一下spring boot在整个启动过程中什么节点发送事件的

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
			context = createApplicationContext();
			context.setApplicationStartup(this.applicationStartup);
			/**
			 * spring boot会把很多东西给spring framewor
			 * 3 用spring boot的事件机制发布ApplicationContextInitializedEvent转到spring framework
			 * 4 用spring boot的事件机制发布ApplicationPreparedEvent转到spring framework
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

### 4.1 ApplicationStartingEvent

```java
	void starting(ConfigurableBootstrapContext bootstrapContext, @Nullable Class<?> mainApplicationClass) {
		// 执行EventPublishingRunListener的starting方法
		doWithListeners("spring.boot.application.starting", (listener) -> listener.starting(bootstrapContext),
				(step) -> {
					if (mainApplicationClass != null) {
						step.tag("mainApplicationClass", mainApplicationClass.getName());
					}
				});
	}
```

```java
	@Override
	public void starting(ConfigurableBootstrapContext bootstrapContext) {
		multicastInitialEvent(new ApplicationStartingEvent(bootstrapContext, this.application, this.args));
	}
```

### 4.2 ApplicationEnvironmentPreparedEvent

```java
	@Override
	public void environmentPrepared(ConfigurableBootstrapContext bootstrapContext,
			ConfigurableEnvironment environment) {
		multicastInitialEvent(
				new ApplicationEnvironmentPreparedEvent(bootstrapContext, this.application, this.args, environment));
	}
```

### 4.3 ApplicationContextInitializedEvent

```java
	@Override
	public void contextPrepared(ConfigurableApplicationContext context) {
		multicastInitialEvent(new ApplicationContextInitializedEvent(this.application, this.args, context));
	}
```

### 4.4 ApplicationPreparedEvent

```java
	@Override
	public void contextLoaded(ConfigurableApplicationContext context) {
		for (ApplicationListener<?> listener : this.application.getListeners()) {
			if (listener instanceof ApplicationContextAware contextAware) {
				contextAware.setApplicationContext(context);
			}
			context.addApplicationListener(listener);
		}
		multicastInitialEvent(new ApplicationPreparedEvent(this.application, this.args, context));
	}
```

### 4.5 ApplicationStartedEvent

```java
	@Override
	public void started(ConfigurableApplicationContext context, @Nullable Duration timeTaken) {
		context.publishEvent(new ApplicationStartedEvent(this.application, this.args, context, timeTaken));
		AvailabilityChangeEvent.publish(context, LivenessState.CORRECT);
	}
```

### 4.6 ApplicationReadyEvent

```java
	@Override
	public void ready(ConfigurableApplicationContext context, @Nullable Duration timeTaken) {
		context.publishEvent(new ApplicationReadyEvent(this.application, this.args, context, timeTaken));
		AvailabilityChangeEvent.publish(context, ReadinessState.ACCEPTING_TRAFFIC);
	}
```
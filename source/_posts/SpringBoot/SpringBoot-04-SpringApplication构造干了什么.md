---
title: SpringBoot-04-SpringApplication构造干了什么
category_bar: true
categories: SpringBoot
date: 2026-08-14 10:42:43
---

构造SpringApplication就是利用SPI缓存了一些实现类，其他的逻辑都在run方法里面

```java
	public SpringApplication(@Nullable ResourceLoader resourceLoader, Class<?>... primarySources) {
		this.resourceLoader = resourceLoader;
		Assert.notNull(primarySources, "'primarySources' must not be null");
		// 启动类
		this.primarySources = new LinkedHashSet<>(Arrays.asList(primarySources));
		this.properties.setWebApplicationType(WebApplicationType.deduce());
		// spring.factories 没有配置
		this.bootstrapRegistryInitializers = new ArrayList<>(
				getSpringFactoriesInstances(BootstrapRegistryInitializer.class));
		// spring.factories 找到ApplicationContextInitializer的实现缓存到initializers
		setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));
		// spring.factories 找到ApplicationListener的实现缓存到listeners
		setListeners((Collection) getSpringFactoriesInstances(ApplicationListener.class));
		this.mainApplicationClass = deduceMainApplicationClass();
	}
```
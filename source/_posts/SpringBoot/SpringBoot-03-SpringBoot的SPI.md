---
title: SpringBoot-03-SpringBoot的SPI
category_bar: true
categories: SpringBoot
date: 2026-08-14 10:29:25
---

当框架还没有启动的时候或者启动的初期，是没有能力提供完善功能的，因此需要一个机制提供初期的简陋的功能扩展，就是变种的SPI

## 1 约定配置文件路径

```java
	public static final String FACTORIES_RESOURCE_LOCATION = "META-INF/spring.factories";
```

## 2 扫描配置文件

```java
	/**
	 * jvm里面跑着的是.class字节码 所以运行这些字节码本身需要载体 就是classLoader
	 * 让classLoader去找所有的resourceLocation路径 spring.factories文件
	 * @param classLoader 启动类的加载类是谁就是谁
	 * @param resourceLocation 要找的classpath路径 就是META-INF/spring.factories
	 * @return key=接口全路径 value=所有的实现全路径
	 */
	protected static Map<String, List<String>> loadFactoriesResource(ClassLoader classLoader, String resourceLocation) {
		Map<String, List<String>> result = new LinkedHashMap<>();
		try {
			// 找到所有的spring.factories文件
			Enumeration<URL> urls = classLoader.getResources(resourceLocation);
			while (urls.hasMoreElements()) {
				UrlResource resource = new UrlResource(urls.nextElement());
				// 读spring.factories文件内容
				Properties properties = PropertiesLoaderUtils.loadProperties(resource);
				// 里面的内容就是接口=实现1,实现2...
				properties.forEach((name, value) -> {
					// 所有的实现类
					String[] factoryImplementationNames = StringUtils.commaDelimitedListToStringArray((String) value);
					// 缓存起来 key=接口全路径 value=所有的实现类全路径
					List<String> implementations = result.computeIfAbsent(((String) name).trim(),
							key -> new ArrayList<>(factoryImplementationNames.length));
					Arrays.stream(factoryImplementationNames).map(String::trim).forEach(implementations::add);
				});
			}
			result.replaceAll(SpringFactoriesLoader::toDistinctUnmodifiableList);
		}
		catch (IOException ex) {
			throw new IllegalArgumentException("Unable to load factories from location [" + resourceLocation + "]", ex);
		}
		return Collections.unmodifiableMap(result);
	}
```

## 3 拿着接口找实现

```java
	// 从spring.factories里面找接口有哪些实现
	private <T> List<T> getSpringFactoriesInstances(Class<T> type) {
		return getSpringFactoriesInstances(type, null);
	}
```
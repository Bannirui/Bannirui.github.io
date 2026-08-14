---
title: Spring-06-用BeanDefinition创建Bean
category_bar: true
categories: Spring
date: 2026-08-15 00:20:52
---

## 1 有依赖的时候

```java
	// 记录Bean创建过程中存在的依赖关系 要双向关系有记录 用来检索是不是存在循环依赖
	/** Map between dependent bean names: bean name to Set of dependent bean names. */
	// 依赖我的有谁
	private final Map<String, Set<String>> dependentBeanMap = new ConcurrentHashMap<>(64);

	/** Map between depending bean names: bean name to Set of bean names for the bean's dependencies. */
	// 我依赖哪些人
	private final Map<String, Set<String>> dependenciesForBeanMap = new ConcurrentHashMap<>(64);
```

```java
	/**
	 * dependentBeanName依赖beanName
	 * 第二个参数依赖第一个参数
	 * 维护双向关系 后面用来检测是不是有循环依赖
	 */
	public void registerDependentBean(String beanName, String dependentBeanName) {
		String canonicalName = canonicalName(beanName);

		// 依赖我的有谁
		synchronized (this.dependentBeanMap) {
			Set<String> dependentBeans =
					this.dependentBeanMap.computeIfAbsent(canonicalName, key -> new LinkedHashSet<>(8));
			if (!dependentBeans.add(dependentBeanName)) {
				return;
			}
		}
		// 我依赖谁
		synchronized (this.dependenciesForBeanMap) {
			Set<String> dependenciesForBean =
					this.dependenciesForBeanMap.computeIfAbsent(dependentBeanName, key -> new LinkedHashSet<>(8));
			dependenciesForBean.add(canonicalName);
		}
	}
```

## 2

AbstractBeanFactory 273行 doGetBean方法
---
title: Spring-16-真正创建Bean
category_bar: true
categories: Spring
date: 2026-08-14 17:26:48
---

在Spring启动过程中，仅仅会把符合要求的业务Bean创建出来，并不是所有的Bean

- 不是抽象类
- 单例的
- 不是懒加载的

## 1 并发创建Bean

```java
			for (String beanName : beanNames) {
				// 拿到BeanDefinition
				RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
				if (!mbd.isAbstract() && mbd.isSingleton()) {
					// 在Spring启动过程中只创建单例的Bean
					CompletableFuture<?> future = preInstantiateSingleton(beanName, mbd);
					if (future != null) {
						futures.add(future);
					}
				}
			}
```

执行的链路是

### 1.1 preInstantiateSingleton

```java
		if (!mbd.isLazyInit()) {
			try {
				// 不是懒加载 符合在Spring启动过程中需要创建Bean的要求 现在就创建它
				instantiateSingleton(beanName);
			}
			catch (BeanCurrentlyInCreationException ex) {
				logger.info("Bean '" + beanName + "' marked for pre-instantiation (not lazy-init) " +
						"but currently initialized by other thread - skipping it in mainline thread");
			}
		}
```
### 1.2 instantiateSingleton

```java
	private void instantiateSingleton(String beanName) {
		if (isFactoryBean(beanName)) {
			// 是FactoryBean 就按照约定名字加上&前缀 也就是说如果是FactoryBean就先调用getBean方法触发FactoryBean的创建 再调用getBean方法会触发FactoryBean创建需要的Bean
			Object bean = getBean(FACTORY_BEAN_PREFIX + beanName);
			if (bean instanceof SmartFactoryBean<?> smartFactoryBean && smartFactoryBean.isEagerInit()) {
				getBean(beanName);
			}
		}
		else {
			// 普通Bean
			getBean(beanName);
		}
	}
```

### 1.3 getBean

```java
	/**
	 * 对于普通的Bean没有歧义
	 * 对于FactoryBean有语义规定
	 *   - name 是拿FactoryBean的getObject方法创建的对象
	 *   - &name 带&前缀的名字是拿FactoryBean
	 *
	 * 这个函数的语义不仅拿 还会创建
	 * 1 从缓存中能拿到
	 *   - 一级缓存有现成的单例对象
	 *   - 二级缓存有半成品
	 *   - 三级缓存有ObjectFactory对象 用ObjectFactory的getObject方法创建一个对象放到二级缓存
	 * 2 缓存中没有就用BeanDefinition构造对象
	 */
	@Override
	public Object getBean(String name) throws BeansException {
		return doGetBean(name, null, null, false);
	}
```

### 1.4 取缓存的逻辑

```java
	/**
	 * 到缓存里面取
	 *   - 先到一级缓存拿全乎的单例Bean
	 *   - 再到二级缓存拿半成品的Bean
	 *   - 还是没有说明可能因为循环依赖 看看三级缓存有没有ObjectFactory对象 用ObjectFactory.getObject创建半成品Bean再丢到二级缓存去
	 * @param allowEarlyReference 控制什么的 一级跟二级缓存都没有情况 允许用三级缓存的ObjectFactory生产一个早期暴露的Bean出来
	 */
	protected @Nullable Object getSingleton(String beanName, boolean allowEarlyReference) {
		// Quick check for existing instance without full singleton lock.
		// 先去一级缓存中拿 有的话说明已经是创建好的Bean了
		Object singletonObject = this.singletonObjects.get(beanName);
		if (singletonObject == null && isSingletonCurrentlyInCreation(beanName)) {
			// 到二级缓存中拿实例化好但是还没完全初始化好的
			singletonObject = this.earlySingletonObjects.get(beanName);
			if (singletonObject == null && allowEarlyReference) {
				// 二级缓存中没有
				if (!this.singletonLock.tryLock()) {
					// Avoid early singleton inference outside of original creation thread.
					return null;
				}
				try {
					// 下面就属于上锁后的double check了 再从一级二级找一遍看看能不能找到 防止上锁期间已经创建好了
					// Consistent creation of early reference within full singleton lock.
					singletonObject = this.singletonObjects.get(beanName);
					if (singletonObject == null) {
						singletonObject = this.earlySingletonObjects.get(beanName);
						if (singletonObject == null) {
							// 二级缓存还没有 那就有可能是因为循环依赖 在三级缓存里面放了个ObjectFactory
							ObjectFactory<?> singletonFactory = this.singletonFactories.get(beanName);
							if (singletonFactory != null) {
								// 用三级缓存里面的ObjectFactory对象调用getObject方法创建个半成品Bean对象放到二级缓存去
								singletonObject = singletonFactory.getObject();
								// Singleton could have been added or removed in the meantime.
								if (this.singletonFactories.remove(beanName) != null) {
									// 把FactoryBean创建出来的Bean作为半成品放到二级缓存
									this.earlySingletonObjects.put(beanName, singletonObject);
								}
								else {
									singletonObject = this.singletonObjects.get(beanName);
								}
							}
						}
					}
				}
				finally {
					this.singletonLock.unlock();
				}
			}
		}
		return singletonObject;
	}
```

### 1.5 用BeanDefinition创建Bean

过程比较复杂，单独开一篇{%post_link Spring/Spring-06-用BeanDefinition创建Bean%}

## 2 创建好后执行通知

执行SmartInitializingSingleton通知

```java
		// 上面已经把所有的非抽象的 单例的 不是懒加载的Bean都创建好了 现在要在这些创建好的Bean里面找哪些是实现了SmartInitializingSingleton接口的 触发回调
		for (String beanName : beanNames) {
			Object singletonInstance = getSingleton(beanName, false);
			if (singletonInstance instanceof SmartInitializingSingleton smartSingleton) {
				StartupStep smartInitialize = getApplicationStartup().start("spring.beans.smart-initialize")
						.tag("beanName", beanName);
				smartSingleton.afterSingletonsInstantiated();
				smartInitialize.end();
			}
		}
```
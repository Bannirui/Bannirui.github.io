---
title: dubbo-0x03-URL
category_bar: true
date: 2025-05-14 16:54:23
categories: dubbo
---

为什么URL的优先级这么高，因为原计划看一下`RegistryFactory`的工厂模式创建实例的{% post_link dubbo/dubbo-0x04-注册中心工厂模式 %}，但是发现依赖URL，也就是说在dubbo架构中，URL扮演的角色含义已经远远超出url的字面意思，还承载了配置的作用。

```java
Registry getRegistry(URL url);
```
---
title: Spring源码-09-配置类解析器ConfigurationClassParser
date: 2023-03-11 00:30:50
tags:
- Spring@6.0.3
categories:
- Spring源码
---

解析配置类。

```java
// ConfigurationClassParser.java
public void parse(Set<BeanDefinitionHolder> configCandidates) {
    for (BeanDefinitionHolder holder : configCandidates) {
        BeanDefinition bd = holder.getBeanDefinition();
        try {
            if (bd instanceof AnnotatedBeanDefinition) {
                this.parse(((AnnotatedBeanDefinition) bd).getMetadata(), holder.getBeanName());
            }
            else if (bd instanceof AbstractBeanDefinition && ((AbstractBeanDefinition) bd).hasBeanClass()) {
                this.parse(((AbstractBeanDefinition) bd).getBeanClass(), holder.getBeanName());
            }
            else {
                parse(bd.getBeanClassName(), holder.getBeanName());
            }
        }
        catch (BeanDefinitionStoreException ex) {
            throw ex;
        }
        catch (Throwable ex) {
            throw new BeanDefinitionStoreException(
                "Failed to parse configuration class [" + bd.getBeanClassName() + "]", ex);
        }
    }

    /**
		 * 处理延迟ImportSelector
		 */
    this.deferredImportSelectorHandler.process();
}
```

```java
// ConfigurationClassParser.java
protected void processConfigurationClass(ConfigurationClass configClass, Predicate<String> filter) throws IOException {
    if (this.conditionEvaluator.shouldSkip(configClass.getMetadata(), ConfigurationPhase.PARSE_CONFIGURATION)) {
        return;
    }

    ConfigurationClass existingClass = this.configurationClasses.get(configClass);
    if (existingClass != null) {
        if (configClass.isImported()) {
            if (existingClass.isImported()) {
                existingClass.mergeImportedBy(configClass);
            }
            // Otherwise ignore new imported config class; existing non-imported class overrides it.
            return;
        }
        else {
            // Explicit bean definition found, probably replacing an import.
            // Let's remove the old one and go with the new one.
            this.configurationClasses.remove(configClass);
            this.knownSuperclasses.values().removeIf(configClass::equals);
        }
    }

    // Recursively process the configuration class and its superclass hierarchy.
    SourceClass sourceClass = asSourceClass(configClass, filter);
    /**
		 * 显式继承场景
		 *     - 配置类没有父类 返回null
		 *     - 配置类有父类 返回父类 递归解析父类
		 */
    do {
        sourceClass = this.doProcessConfigurationClass(configClass, sourceClass, filter);
    }
    while (sourceClass != null);

    this.configurationClasses.put(configClass, configClass);
}
```

```java
// ConfigurationClassParser.java
@Nullable
protected final SourceClass doProcessConfigurationClass(
    ConfigurationClass configClass, SourceClass sourceClass, Predicate<String> filter)
    throws IOException {

    /**
		 * @Configuration是组合注解
		 *     - @Component
		 */
    if (configClass.getMetadata().isAnnotated(Component.class.getName())) {
        // Recursively process any member (nested) classes first
        /**
			 * 配置的内部类
			 *     - 内部类也是配置类 dfs解析下去
			 */
        this.processMemberClasses(configClass, sourceClass, filter);
    }

    // Process any @PropertySource annotations
    /**
		 * 配置类上的@PropertySource解析
		 *     - 单个@PropertySource
		 *     - 多个@PropertySource
		 *     - @PropertySources定义的多个@PropertySource
		 * for轮询中处理每个@PropertySource
		 * 将@PrepertySource指定的配置文件解析加载到Environment中
		 */
    for (AnnotationAttributes propertySource : AnnotationConfigUtils.attributesForRepeatable(
        sourceClass.getMetadata(), PropertySources.class,
        org.springframework.context.annotation.PropertySource.class)) {
        if (this.propertySourceRegistry != null) {
            this.propertySourceRegistry.processPropertySource(propertySource); // 处理每个@PropertySource
        }
        else {
            logger.info("Ignoring @PropertySource annotation on [" + sourceClass.getMetadata().getClassName() +
                        "]. Reason: Environment must implement ConfigurableEnvironment");
        }
    }

    // Process any @ComponentScan annotations
    /**
		 * 配置类上的@ComponentScan注解解析
		 *     - 单个@CompoentScan
		 *     - 多个@ComponentScan
		 *     - @ComponentScans定义的多个@ComponentScan
		 * - 扫包路径下@Component/类@Component的类封装BeanDefinition注册进Bean工厂
		 * - 扫描到的配置类递归继续解析
		 */
    Set<AnnotationAttributes> componentScans = AnnotationConfigUtils.attributesForRepeatable(
        sourceClass.getMetadata(), ComponentScans.class, ComponentScan.class);
    if (!componentScans.isEmpty() &&
        !this.conditionEvaluator.shouldSkip(sourceClass.getMetadata(), ConfigurationPhase.REGISTER_BEAN)) {
        for (AnnotationAttributes componentScan : componentScans) {
            // The config class is annotated with @ComponentScan -> perform the scan immediately
            /**
				 * 扫包路径下符合要求的类被封装成ScannedGenericBeanDefinition
				 *     - @Component/类@Component注解标识的类
				 */
            Set<BeanDefinitionHolder> scannedBeanDefinitions =
                this.componentScanParser.parse(componentScan, sourceClass.getMetadata().getClassName()); // 配置类名称
            // Check the set of scanned definitions for any further config classes and parse recursively if needed
            for (BeanDefinitionHolder holder : scannedBeanDefinitions) { // 扫包出来的BeanDefinition可能本身也是配置类
                BeanDefinition bdCand = holder.getBeanDefinition().getOriginatingBeanDefinition();
                if (bdCand == null) {
                    bdCand = holder.getBeanDefinition();
                }
                if (ConfigurationClassUtils.checkConfigurationClassCandidate(bdCand, this.metadataReaderFactory)) { // 扫到的类也是配置类就继续递归解析下去
                    this.parse(bdCand.getBeanClassName(), holder.getBeanName());
                }
            }
        }
    }

    // Process any @Import annotations
    /**
		 * @Import注解的配置类
		 * getImports(...)找出配置类上通过@Import注解导入的的所有类
		 * 解析@Import注解导入的类 根据导入的类进行不同的策略处理
		 *     - ImportSelector的实现
		 *         - selectImports(...)定义的类按照Import类递归解析
		 *     - ImportBeanDefinitionRegistrar的实现
		 *         - 将ImportBeanDefinitionRegistrar缓存到配置类的importBeanDefinitionRegistrars
		 *     - 没有实现ImportSelector和ImportBeanDefinitionRegistry接口的类
		 *         - 配置类就递归解析下去
		 *         - 普通类就缓存到imports哈希表中
		 *             - 不发生注册Bean工厂
		 */
    this.processImports(configClass, sourceClass, this.getImports(sourceClass), filter, true);

    // Process any @ImportResource annotations
    /**
		 * @ImportResource引入的配置文件
		 * 将@ImportResource指定的配置文件资源缓存在配置类的importedResources中
		 */
    AnnotationAttributes importResource =
        AnnotationConfigUtils.attributesFor(sourceClass.getMetadata(), ImportResource.class); // 配置上的@ImportResource注解对象
    if (importResource != null) {
        String[] resources = importResource.getStringArray("locations"); // 指定的配置文件路径
        Class<? extends BeanDefinitionReader> readerClass = importResource.getClass("reader");
        for (String resource : resources) {
            String resolvedResource = this.environment.resolveRequiredPlaceholders(resource);
            configClass.addImportedResource(resolvedResource, readerClass); // 缓存在配置类的importedResources中
        }
    }

    // Process individual @Bean methods
    /**
		 * @Bean注解的方法
		 * 将@Bean注解的方法缓存在配置类的beanMethods中
		 */
    Set<MethodMetadata> beanMethods = retrieveBeanMethodMetadata(sourceClass); // 配置类被@Bean标识的方法
    for (MethodMetadata methodMetadata : beanMethods) {
        configClass.addBeanMethod(new BeanMethod(methodMetadata, configClass)); // 缓存在配置类的beanMethods中
    }

    // Process default methods on interfaces
    processInterfaces(configClass, sourceClass);

    // Process superclass, if any
    if (sourceClass.getMetadata().hasSuperClass()) {
        String superclass = sourceClass.getMetadata().getSuperClassName();
        if (superclass != null && !superclass.startsWith("java") &&
            !this.knownSuperclasses.containsKey(superclass)) {
            this.knownSuperclasses.put(superclass, configClass);
            // Superclass found, return its annotation metadata and recurse
            return sourceClass.getSuperClass();
        }
    }

    // No superclass -> processing is complete
    return null;
}
```

### 1 内部类

配置中的内部类也是配置类就递归下去

```java
// ConfigurationClassParser.java
/**
			 * 配置的内部类
			 *     - 内部类也是配置类 dfs解析下去
			 */
this.processMemberClasses(configClass, sourceClass, filter);
```

```java
// ConfigurationClassParser.java
private void processMemberClasses(ConfigurationClass configClass, SourceClass sourceClass,
                                  Predicate<String> filter) throws IOException {

    Collection<SourceClass> memberClasses = sourceClass.getMemberClasses(); // 配置类的内部类
    if (!memberClasses.isEmpty()) {
        List<SourceClass> candidates = new ArrayList<>(memberClasses.size());
        for (SourceClass memberClass : memberClasses) {
            if (ConfigurationClassUtils.isConfigurationCandidate(memberClass.getMetadata()) &&
                !memberClass.getMetadata().getClassName().equals(configClass.getMetadata().getClassName())) {
                candidates.add(memberClass); // 内部类也是配置类 缓存起来
            }
        }
        OrderComparator.sort(candidates);
        for (SourceClass candidate : candidates) {
            if (this.importStack.contains(configClass)) {
                this.problemReporter.error(new CircularImportProblem(configClass, this.importStack));
            }
            else {
                this.importStack.push(configClass); // 入栈出栈解决多层嵌套内部类场景
                try {
                    this.processConfigurationClass(candidate.asConfigClass(configClass), filter); // 解析配置类
                }
                finally {
                    this.importStack.pop();
                }
            }
        }
    }
}
```

### 2 @PropertySource

将资源文件中的配置加载到Environment中

* @PropertySource
* @PropertySources

```java
// ConfigurationClassParser.java
this.propertySourceRegistry.processPropertySource(propertySource); // 处理每个@PropertySource
```

```java
// PropertySourceRegistry.java
void processPropertySource(AnnotationAttributes propertySource) throws IOException { // 读取@PropertySource注解元素中的值
    String name = propertySource.getString("name"); // @PropertySource的name值
    if (!StringUtils.hasLength(name)) {
        name = null;
    }
    String encoding = propertySource.getString("encoding"); // @PropertySource的encoding值
    if (!StringUtils.hasLength(encoding)) {
        encoding = null;
    }
    String[] locations = propertySource.getStringArray("value"); // @PropertySource的locations值 配置文件路径
    Assert.isTrue(locations.length > 0, "At least one @PropertySource(value) location is required");
    boolean ignoreResourceNotFound = propertySource.getBoolean("ignoreResourceNotFound");

    Class<? extends PropertySourceFactory> factoryClass = propertySource.getClass("factory");
    Class<? extends PropertySourceFactory> factorClassToUse =
        (factoryClass != PropertySourceFactory.class ? factoryClass : null);
    PropertySourceDescriptor descriptor = new PropertySourceDescriptor(Arrays.asList(locations), ignoreResourceNotFound, name,
                                                                       factorClassToUse, encoding); // 封装@PropertySource注解元素中的值
    this.propertySourceProcessor.processPropertySource(descriptor);
    this.descriptors.add(descriptor);
}
```

```java
// PropertySourceRegistry.java
public void processPropertySource(PropertySourceDescriptor descriptor) throws IOException {
    String name = descriptor.name();
    String encoding = descriptor.encoding();
    List<String> locations = descriptor.locations();
    Assert.isTrue(locations.size() > 0, "At least one @PropertySource(value) location is required");
    boolean ignoreResourceNotFound = descriptor.ignoreResourceNotFound();
    PropertySourceFactory factory = (descriptor.propertySourceFactory() != null
                                     ? instantiateClass(descriptor.propertySourceFactory())
                                     : DEFAULT_PROPERTY_SOURCE_FACTORY);

    for (String location : locations) { // 配置在@PropertySource中的配置文件路径
        try {
            String resolvedLocation = this.environment.resolveRequiredPlaceholders(location);
            Resource resource = this.resourceLoader.getResource(resolvedLocation);
            this.addPropertySource(factory.createPropertySource(name, new EncodedResource(resource, encoding))); // 配置文件配置项加载到Environment中
        }
        catch (IllegalArgumentException | FileNotFoundException | UnknownHostException | SocketException ex) {
            // Placeholders not resolvable or resource not found when trying to open it
            if (ignoreResourceNotFound) {
                if (logger.isInfoEnabled()) {
                    logger.info("Properties location [" + location + "] not resolvable: " + ex.getMessage());
                }
            }
            else {
                throw ex;
            }
        }
    }
}
```

```java
// PropertySourceProcessor.java
private void addPropertySource(org.springframework.core.env.PropertySource<?> propertySource) {
    String name = propertySource.getName();
    MutablePropertySources propertySources = this.environment.getPropertySources(); // 将配置文件中的配置加载到environment中

    if (this.propertySourceNames.contains(name)) {
        // We've already added a version, we need to extend it
        org.springframework.core.env.PropertySource<?> existing = propertySources.get(name);
        if (existing != null) {
            PropertySource<?> newSource = (propertySource instanceof ResourcePropertySource ?
                                           ((ResourcePropertySource) propertySource).withResourceName() : propertySource);
            if (existing instanceof CompositePropertySource) {
                ((CompositePropertySource) existing).addFirstPropertySource(newSource);
            }
            else {
                if (existing instanceof ResourcePropertySource) {
                    existing = ((ResourcePropertySource) existing).withResourceName();
                }
                CompositePropertySource composite = new CompositePropertySource(name);
                composite.addPropertySource(newSource);
                composite.addPropertySource(existing);
                propertySources.replace(name, composite);
            }
            return;
        }
    }

    if (this.propertySourceNames.isEmpty()) {
        propertySources.addLast(propertySource);
    }
    else {
        String firstProcessed = this.propertySourceNames.get(this.propertySourceNames.size() - 1);
        propertySources.addBefore(firstProcessed, propertySource);
    }
    this.propertySourceNames.add(name);
}
```

### 3 @ComponentScan

定义扫包路径

* @ComponentScan
* @ComponentScans

筛选出符合过滤规则(类Component)的类注册Bean工厂，配置类递归解析

#### 3.1 扫包路径下类Component

```java
// ConfigurationClassParser.java
/**
				 * 扫包路径下符合要求的类被封装成ScannedGenericBeanDefinition
				 *     - @Component/类@Component注解标识的类
				 */
Set<BeanDefinitionHolder> scannedBeanDefinitions =
    this.componentScanParser.parse(componentScan, sourceClass.getMetadata().getClassName()); // 配置类名称
```

```java
// ComponentScanAnnotationParser.java
public Set<BeanDefinitionHolder> parse(AnnotationAttributes componentScan, String declaringClass) {
    ClassPathBeanDefinitionScanner scanner = new ClassPathBeanDefinitionScanner(this.registry,
                                                                                componentScan.getBoolean("useDefaultFilters"), this.environment, this.resourceLoader);

    Class<? extends BeanNameGenerator> generatorClass = componentScan.getClass("nameGenerator");
    boolean useInheritedGenerator = (BeanNameGenerator.class == generatorClass);
    scanner.setBeanNameGenerator(useInheritedGenerator ? this.beanNameGenerator :
                                 BeanUtils.instantiateClass(generatorClass));

    ScopedProxyMode scopedProxyMode = componentScan.getEnum("scopedProxy");
    if (scopedProxyMode != ScopedProxyMode.DEFAULT) {
        scanner.setScopedProxyMode(scopedProxyMode);
    }
    else {
        Class<? extends ScopeMetadataResolver> resolverClass = componentScan.getClass("scopeResolver");
        scanner.setScopeMetadataResolver(BeanUtils.instantiateClass(resolverClass));
    }

    scanner.setResourcePattern(componentScan.getString("resourcePattern"));

    for (AnnotationAttributes includeFilterAttributes : componentScan.getAnnotationArray("includeFilters")) {
        List<TypeFilter> typeFilters = TypeFilterUtils.createTypeFiltersFor(includeFilterAttributes, this.environment,
                                                                            this.resourceLoader, this.registry);
        for (TypeFilter typeFilter : typeFilters) {
            scanner.addIncludeFilter(typeFilter);
        }
    }
    for (AnnotationAttributes excludeFilterAttributes : componentScan.getAnnotationArray("excludeFilters")) {
        List<TypeFilter> typeFilters = TypeFilterUtils.createTypeFiltersFor(excludeFilterAttributes, this.environment,
                                                                            this.resourceLoader, this.registry);
        for (TypeFilter typeFilter : typeFilters) {
            scanner.addExcludeFilter(typeFilter);
        }
    }

    boolean lazyInit = componentScan.getBoolean("lazyInit");
    if (lazyInit) {
        scanner.getBeanDefinitionDefaults().setLazyInit(true);
    }

    Set<String> basePackages = new LinkedHashSet<>();
    String[] basePackagesArray = componentScan.getStringArray("basePackages"); // @ComponentScan中定义的扫包路径
    for (String pkg : basePackagesArray) {
        String[] tokenized = StringUtils.tokenizeToStringArray(this.environment.resolvePlaceholders(pkg),
                                                               ConfigurableApplicationContext.CONFIG_LOCATION_DELIMITERS);
        Collections.addAll(basePackages, tokenized);
    }
    for (Class<?> clazz : componentScan.getClassArray("basePackageClasses")) {
        basePackages.add(ClassUtils.getPackageName(clazz));
    }
    if (basePackages.isEmpty()) {
        basePackages.add(ClassUtils.getPackageName(declaringClass));
    }

    scanner.addExcludeFilter(new AbstractTypeHierarchyTraversingFilter(false, false) {
        @Override
        protected boolean matchClassName(String className) {
            return declaringClass.equals(className);
        }
    });
    return scanner.doScan(StringUtils.toStringArray(basePackages)); // 扫描指定扫包路径 @Component/类@Component标识的类封装成BeanDefnition注册到Bean工厂
}
```

```java
// ClassPathBeanDefinitionScanner.java
protected Set<BeanDefinitionHolder> doScan(String... basePackages) {
    Assert.notEmpty(basePackages, "At least one base package must be specified");
    Set<BeanDefinitionHolder> beanDefinitions = new LinkedHashSet<>();
    for (String basePackage : basePackages) {
        Set<BeanDefinition> candidates = findCandidateComponents(basePackage); // 定义的扫包路径下被@Component标识的类被封装成ScannedGenericBeanDefinition
        for (BeanDefinition candidate : candidates) {
            ScopeMetadata scopeMetadata = this.scopeMetadataResolver.resolveScopeMetadata(candidate);
            candidate.setScope(scopeMetadata.getScopeName());
            String beanName = this.beanNameGenerator.generateBeanName(candidate, this.registry);
            if (candidate instanceof AbstractBeanDefinition) {
                postProcessBeanDefinition((AbstractBeanDefinition) candidate, beanName);
            }
            if (candidate instanceof AnnotatedBeanDefinition) {
                AnnotationConfigUtils.processCommonDefinitionAnnotations((AnnotatedBeanDefinition) candidate);
            }
            if (checkCandidate(beanName, candidate)) {
                BeanDefinitionHolder definitionHolder = new BeanDefinitionHolder(candidate, beanName);
                definitionHolder =
                    AnnotationConfigUtils.applyScopedProxyMode(scopeMetadata, definitionHolder, this.registry);
                beanDefinitions.add(definitionHolder);
                registerBeanDefinition(definitionHolder, this.registry); // BeanDefinition注册到Bean工厂
            }
        }
    }
    return beanDefinitions;
}
```

##### 3.1.1 @Component/类@Component注解的类

```java
// ClassPathBeanDefinitionScanner.java
Set<BeanDefinition> candidates = super.findCandidateComponents(basePackage); // 定义的扫包路径下被@Component标识的类被封装成ScannedGenericBeanDefinition
```

```java
// ClassPathScanningCandidateComponentProvider.java
public Set<BeanDefinition> findCandidateComponents(String basePackage) {
    if (this.componentsIndex != null && indexSupportsIncludeFilters()) {
        return addCandidateComponentsFromIndex(this.componentsIndex, basePackage);
    }
    else {
        return this.scanCandidateComponents(basePackage);
    }
}
```

```java
// ClassPathScanningCandidateComponentProvider.java
private Set<BeanDefinition> scanCandidateComponents(String basePackage) {
    Set<BeanDefinition> candidates = new LinkedHashSet<>();
    try {
        String packageSearchPath = ResourcePatternResolver.CLASSPATH_ALL_URL_PREFIX +
            resolveBasePackage(basePackage) + '/' + this.resourcePattern;
        Resource[] resources = getResourcePatternResolver().getResources(packageSearchPath);
        boolean traceEnabled = logger.isTraceEnabled();
        boolean debugEnabled = logger.isDebugEnabled();
        for (Resource resource : resources) {
            String filename = resource.getFilename();
            if (filename != null && filename.contains(ClassUtils.CGLIB_CLASS_SEPARATOR)) {
                // Ignore CGLIB-generated classes in the classpath
                continue;
            }
            if (traceEnabled) {
                logger.trace("Scanning " + resource);
            }
            try {
                MetadataReader metadataReader = getMetadataReaderFactory().getMetadataReader(resource);
                if (this.isCandidateComponent(metadataReader)) { // 扫包路径下的@Component或者类@Component标识的类才会被封装成Definition
                    ScannedGenericBeanDefinition sbd = new ScannedGenericBeanDefinition(metadataReader); // BeanDefinition的实现标识是扫描出来的类封装的
                    sbd.setSource(resource);
                    if (isCandidateComponent(sbd)) {
                        if (debugEnabled) {
                            logger.debug("Identified candidate component class: " + resource);
                        }
                        candidates.add(sbd);
                    }
                    else {
                        if (debugEnabled) {
                            logger.debug("Ignored because not a concrete top-level class: " + resource);
                        }
                    }
                }
                else {
                    if (traceEnabled) {
                        logger.trace("Ignored because not matching any filter: " + resource);
                    }
                }
            }
            catch (FileNotFoundException ex) {
                if (traceEnabled) {
                    logger.trace("Ignored non-readable " + resource + ": " + ex.getMessage());
                }
            }
            catch (Throwable ex) {
                throw new BeanDefinitionStoreException(
                    "Failed to read candidate component class: " + resource, ex);
            }
        }
    }
    catch (IOException ex) {
        throw new BeanDefinitionStoreException("I/O failure during classpath scanning", ex);
    }
    return candidates;
}
```

##### 3.1.2 BeanDefinition注册Bean工厂

```java
// ClassPathBeanDefinitionScanner.java
registerBeanDefinition(definitionHolder, this.registry); // BeanDefinition注册到Bean工厂
```

#### 3.2 递归解析配置类

```java
// ConfigurationClassParser.java
if (ConfigurationClassUtils.checkConfigurationClassCandidate(bdCand, this.metadataReaderFactory)) { // 扫到的类也是配置类就继续递归解析下去
    this.parse(bdCand.getBeanClassName(), holder.getBeanName());
}
```

### 4 @Import

```java
// ConfigurationClassParser.java
/**
		 * @Import注解的配置类
		 * getImports(...)找出配置类上通过@Import注解导入的的所有类
		 * 解析@Import注解导入的类 根据导入的类进行不同的策略处理
		 *     - ImportSelector的实现
		 *         - selectImports(...)定义的类按照Import类递归解析
		 *     - ImportBeanDefinitionRegistrar的实现
		 *         - 将ImportBeanDefinitionRegistrar缓存到配置类的importBeanDefinitionRegistrars
		 *     - 没有实现ImportSelector和ImportBeanDefinitionRegistry接口的类
		 *         - 配置类就递归解析下去
		 *         - 普通类就缓存到imports哈希表中
		 *             - 不发生注册Bean工厂
		 */
this.processImports(configClass, sourceClass, this.getImports(sourceClass), filter, true);
```

```java
// ConfigurationClassParser.java
/**
	 * @Import进来的类
	 *     - 实现了ImportSelector
	 *         - 递归解析通过selectImports(...)进来的所有类
	 *     - 实现了ImportBeanDefinitionRegistrar
	 *         - 将ImportBeanDefinitionRegistrar缓存到importBeanDefinitionRegistrars
	 *     - 没有实现ImportSelector ImportBeanDefinitionRegistry
	 *         - 当成配置类贪心解析一次
	 *             - 如果仅仅是一个普通类 不会发生注册Bean工厂
	 */
private void processImports(ConfigurationClass configClass, SourceClass currentSourceClass,
                            Collection<SourceClass> importCandidates, Predicate<String> exclusionFilter,
                            boolean checkForCircularImports) {

    if (importCandidates.isEmpty()) {
        return;
    }

    if (checkForCircularImports && isChainedImportOnStack(configClass)) {
        this.problemReporter.error(new CircularImportProblem(configClass, this.importStack));
    }
    else {
        this.importStack.push(configClass); // 递归栈 import进来的类本身又有@Import
        try {
            for (SourceClass candidate : importCandidates) { // import的类
                if (candidate.isAssignable(ImportSelector.class)) { // ImportSelector接口的实现
                    // Candidate class is an ImportSelector -> delegate to it to determine imports
                    Class<?> candidateClass = candidate.loadClass();
                    ImportSelector selector = ParserStrategyUtils.instantiateClass(candidateClass, ImportSelector.class,
                                                                                   this.environment, this.resourceLoader, this.registry); // 实现类对ImportSelector声明的方法具体实现
                    Predicate<String> selectorFilter = selector.getExclusionFilter();
                    if (selectorFilter != null) {
                        exclusionFilter = exclusionFilter.or(selectorFilter);
                    }
                    if (selector instanceof DeferredImportSelector) {
                        this.deferredImportSelectorHandler.handle(configClass, (DeferredImportSelector) selector);
                    }
                    else {
                        String[] importClassNames = selector.selectImports(currentSourceClass.getMetadata()); // selectImports(...)方法的返回值
                        Collection<SourceClass> importSourceClasses = asSourceClasses(importClassNames, exclusionFilter);
                        this.processImports(configClass, currentSourceClass, importSourceClasses, exclusionFilter, false); // 递归解析ImportSelector定义的所有的类
                    }
                }
                else if (candidate.isAssignable(ImportBeanDefinitionRegistrar.class)) { // ImportBeanDefinitionRegistrar接口的实现
                    // Candidate class is an ImportBeanDefinitionRegistrar ->
                    // delegate to it to register additional bean definitions
                    Class<?> candidateClass = candidate.loadClass();
                    ImportBeanDefinitionRegistrar registrar =
                        ParserStrategyUtils.instantiateClass(candidateClass, ImportBeanDefinitionRegistrar.class,
                                                             this.environment, this.resourceLoader, this.registry);
                    configClass.addImportBeanDefinitionRegistrar(registrar, currentSourceClass.getMetadata()); // 将ImportBeanDefinitionRegistrar缓存到importBeanDefinitionRegistrars
                }
                else { // 把它当成配置类再解析一次 如果仅仅是import了普通类 并不会发生注册Bean工厂
                    // Candidate class not an ImportSelector or ImportBeanDefinitionRegistrar ->
                    // process it as an @Configuration class
                    this.importStack.registerImport(
                        currentSourceClass.getMetadata(), candidate.getMetadata().getClassName());
                    this.processConfigurationClass(candidate.asConfigClass(configClass), exclusionFilter); // 当成配置类进行解析 在配置类的imported中缓存主动import的类 记录当前类是被谁import进来的
                }
            }
        }
        catch (BeanDefinitionStoreException ex) {
            throw ex;
        }
        catch (Throwable ex) {
            throw new BeanDefinitionStoreException(
                "Failed to process import candidates for configuration class [" +
                configClass.getMetadata().getClassName() + "]: " + ex.getMessage(), ex);
        }
        finally {
            this.importStack.pop();
        }
    }
}
```

对import的类进行解析

* ImportSelector实现
* ImportBeanDefinitionRegistry实现
* 普通类

#### 4.1 ImportSelector的实现

```java
// ConfigurationClassParser.java
this.processImports(configClass, currentSourceClass, importSourceClasses, exclusionFilter, false); // 递归解析ImportSelector定义的所有的类
```

#### 4.2 ImportBeanDefinitionRegistrar的实现

```java
// ConfigurationClassParser.java
configClass.addImportBeanDefinitionRegistrar(registrar, currentSourceClass.getMetadata()); // 将ImportBeanDefinitionRegistrar缓存到importBeanDefinitionRegistrars
```

#### 4.3 没有实现ImportSelector和ImportBeanDefinitionRegistrar

```java
// ConfigurationClassParser.java
this.processConfigurationClass(candidate.asConfigClass(configClass), exclusionFilter); // 当成配置类进行解析 在配置类的imported中缓存主动import的类 记录当前类是被谁import进来的
```

### 5 @ImportResource

```java
// ConfigurationClassParser.java
/**
		 * @ImportResource引入的配置文件
		 * 将@ImportResource指定的配置文件资源缓存在配置类的importedResources中
		 */
AnnotationAttributes importResource =
    AnnotationConfigUtils.attributesFor(sourceClass.getMetadata(), ImportResource.class); // 配置上的@ImportResource注解对象
if (importResource != null) {
    String[] resources = importResource.getStringArray("locations"); // 指定的配置文件路径
    Class<? extends BeanDefinitionReader> readerClass = importResource.getClass("reader");
    for (String resource : resources) {
        String resolvedResource = this.environment.resolveRequiredPlaceholders(resource);
        configClass.addImportedResource(resolvedResource, readerClass); // 缓存在配置类的importedResources中
    }
}
```

```java
// ConfigurationClass.java
void addImportedResource(String importedResource, Class<? extends BeanDefinitionReader> readerClass) {
    this.importedResources.put(importedResource, readerClass);
}
```

### 6 @Bean

```java
// ConfigurationClassParser.java
/**
		 * @Bean注解的方法
		 * 将@Bean注解的方法缓存在配置类的beanMethods中
		 */
Set<MethodMetadata> beanMethods = retrieveBeanMethodMetadata(sourceClass); // 配置类被@Bean标识的方法
for (MethodMetadata methodMetadata : beanMethods) {
    configClass.addBeanMethod(new BeanMethod(methodMetadata, configClass)); // 缓存在配置类的beanMethods中
}
```

```java
// ConfigurationClass.java
void addBeanMethod(BeanMethod method) {
    this.beanMethods.add(method);
}
```


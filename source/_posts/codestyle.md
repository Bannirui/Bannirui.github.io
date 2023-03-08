---
title: codestyle
date: 2023-02-28 09:32:26
tags:
- 代码规范
categories:
- 工具
---

IDEA设置code style，通过format方式格式化代码，并设置配套的check style进行规范检查。



## 1 文件下载

### 1.1 code style

从[GitHub](https://github.com/google/styleguide.git)下载文件intellij-java-google-style.xml

### 1.2 check style

从[GitHub](https://github.com/checkstyle/checkstyle.git)下载google-checks.xml

## 2 根据自己风格修改对应配置项

## 3 配置code style

![](codestyle/20230228094509570.png)

`IntelliJ IDEA code style xml`选项卡导入intellij-java-google-style.xml

`Checkstyle configuration`选项卡导入google-checks.xml

## 4 配置check style

### 4.1 插件下载

下载插件CheckStyle-IDEA

### 4.2 配置插件

如下配置项：

org.checkstyle.google.suppressionfilter.config = checkstyle-suppressions.xml

org.checkstyle.google.suppressionxpathfilter.config = checkstyle-xpath-suppressions.xml

![](codestyle/20230228095201528.png )

### 4.3 使用插件

![](codestyle/20230228095406830.png)

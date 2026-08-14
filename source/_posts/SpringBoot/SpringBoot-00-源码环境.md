---
title: SpringBoot-00-源码环境
category_bar: true
categories: SpringBoot
date: 2026-08-13 19:47:56
---

## 1 源码

```sh
# github repository
git clone git@github.com:Bannirui/spring-boot.git

cd spring-boot

git remote add upstream git@github.com:spring-projects/spring-framework.git
git remote set-url --push upstrem no_push

git fetch upstream
git checkout -b x-study upstrem/main
git push origin x-study

# install jdk
sudo apt install openjdk-21-jdk
```

## 2 对spring framework的依赖

遇到个小问题 {%post_link Spring/Spring-00-环境搭建%} 我用的spring版本是6.0.3

现在spring boot依赖的版本是7.1.0，所以要把spring framework的710分支切出来，并且spring boot依赖到本地的spring framework，这样就可以在调试spring boot的时候直接做笔记

```sh
git branch -r | grep -E 'upstream/(7\.1|main)'
git show upstream/main:gradle.properties | grep '^version='
git switch -c x-study-710 upstream/main
git push origin x-study-710

sudo apt install openjdk-25-jdk
```

在根目录下的settings.gradle里面`includeBuild("gradle/plugins")`的下面添加

```gradle
	includeBuild("/home/dingrui/MyDev/java/spring-framework")
```

然后执行

```sh
./gradlew :core:spring-boot:dependencyInsight \
  --dependency spring-context \
  --configuration runtimeClasspath
```
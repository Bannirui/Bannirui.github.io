---
title: Spring-Boot-00-源码环境
category_bar: true
categories: SpringBoot
date: 2026-08-13 19:47:56
---

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
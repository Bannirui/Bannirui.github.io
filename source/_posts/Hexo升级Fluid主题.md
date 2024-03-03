---
title: Hexo升级Fluid主题
date: 2023-11-08 21:42:46
categories: [ Hexo ]
tags: [ Fluid主题升级 ]
---

我之前的Fluid主题是通过git将[Fluid源码](https://github.com/fluid-dev/hexo-theme-fluid)克隆在`博客根目录/themes/`下的，这样的方式跟源码耦合，对升级不友好。

先将Hexo和Fluid的配置文件托管在[github](https://github.com/Bannirui/os_script.git)，然后在项目下通过`ln -s`软链接方式使用配置文件。

1 删除项目下Fluid源码
---

将`博客根目录/themes/fluid`删除。

2 安装Fluid主题
---

在博客根目录下执行`npm install --save hexo-theme-fluid`即可，这时候将Fluid的版本作为了博客项目的依赖进行管理，以后升级也很简单`npm update --save hexo-theme-fluid`。

3 配置文件
---

```shell
ln ~/MyDev/env/os_script/hexo/_config.yml ~/MyDev/doc/Bannirui.github.io/_config.yml

ln ~/MyDev/env/os_script/hexo/theme/fluid/_config.yml ~/MyDev/doc/Bannirui.github.io/_config.fluid.yml
```

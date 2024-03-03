---
title: yay常用命令
date: 2023-12-11 16:34:29
category_bar: true
categories: Linux
---

在archlinux常常依赖yay管理软件。

- yay <包名>: 在终端交互式进行软件搜索和下载

- yay: 同步并更新所有来自仓库和 AUR 的软件包

- yay -Sua: 只同步和更新AUR软件包

- yay -S <软件包>: 从仓库和AUR中安装一个新的软件包

- yay -Ss <包名>: 从仓库和 AUR 中搜索软件包数据库中的关键词

- yay -Ps: 显示已安装软件包和系统健康状况的统计数据

- yay -Syy {包名}: 强制更新，安装软件包

- yay -R {包名}: 删除包名

- yay -Rns {包名}: 删除包，并且删除不需要的依赖项

- yay {-Q --query}: 安装列表

- yay {-Q --query} {包名}: 是否已经安装某个包
---
title: WSL环境
category_bar: true
date: 2026-03-29 14:23:07
categories: 笔记
---

我现在的Linux的开发环境都是按照{%post_link Note/Ubuntu环境%}，现在换到windows+wsl，配置方面需要一点点的适配

## 1 关于代理

之前的代理配置都是用的`127.0.0.1`，要换成宿主机也就是windows的ip就行

## 2 键位映射

习惯了多年的mac键位和vim键位，好在windows上有个软件AutoHotKey

### 2.1 键位脚本

在`C:\Users\banni\Documents\AutoHotkey`上创建个脚本`my_keymap.ahk`

```shell
; Ctrl 和Alt互换
Ctrl::Alt
Alt::Ctrl

; 默认关闭 CapsLock
SetCapsLockState("AlwaysOff")
CapsLock::Shift
```

### 2.2 创建快捷方式

- 选择上面的脚本文件
- 右键
- 创建快捷方式

此时在当前目录就会生成一个快捷方式

### 2.2 开机自启动

- windows+R
- 输入`shell:startup` 回车唤出目录
- 把上面的快捷方式拖到这个目录

### 2.3 AHK的版本

我安装的这个软件里面包含两个版本v1和v2，所以运行脚本的时候会让选择用v1还是v2运行

- 右键脚本
- 打开方式，找到我的安装路径`C:\MyApp\AutoHotkey\v2`
- 始终使用此应用打开

至此，开机/重启之后AHK脚本会自动运行
---
title: emacs配置
category_bar: true
categories: Note
date: 2026-04-03 17:08:07
---

## 1 安装

```shell
brew install --cask emacs
```

## 2 Doom Emacs

### 2.1安装依赖

```shell
brew install git ripgrep fd
```

### 2.2 Doom Emacs克隆

```shell
git clone https://github.com/doomemacs/doomemacs ~/.emacs.d
```

### 2.3 初始化

```shell
~/.emacs.d/bin/doom install
```

## 3 启用模块

修改配置文件 放开注释或者添加对应的模块

```shell
vim ~/.doom.d/init.el
```

- :tools下面添加lsp
- :lang放开注释支持cpp (cc +lsp)

在环境变量中添加`export PATH="$HOME/.emacs.d/bin:$PATH"`然后执行`doom sync`

## 4 安装clangd

```shell
brew install llvm

clangd --version
```

## 5 使用

```shell
emacs . -nw
```


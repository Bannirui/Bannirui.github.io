---
title: vim禁用markdown语法隐藏
date: 2023-11-08 10:58:12
category_bar: true
categories: [ vim ]
tags: [ vim插件 ]
---

1 vimrc配置
---

vimrc文件托管在了[git上](https://github.com/Bannirui/os_script.git)。

不仅仅是vim配置，所有的工具链配置都写成了脚本托管在了git上，但是其中涉及到个人token或者密钥等隐私信息，因此仓库是private。

2 vim写md
---

之前我是长期使用的typora，并且也非常喜欢这个软件。但是可能是因为即时渲染的性能开销，当编辑的文件过大或者其中插图过多，会存在着明显的卡顿现象。对于编辑md而言，我觉得这是本末倒置了，重点应该是在编辑而不是在渲染，渲染对于编辑而言是锦上添花的存在。

因此，我开始转用vim编辑md，对于vim的使用，我更多的经验是在编码coding上，因此对于md的插件以及配置不是很熟悉，使用一段时间之后存在两个痛点：

- vim中```这个符号是个特殊符号，但是我经常需要在md文件中插入代码片段，因此还是个高频使用的符号
- 对于代码片段和网址链接(以及图片链接)都会被隐藏

所以我需要解决上面两个问题，让md的编写更加丝滑和效率。

3 vim键位映射
---

vim强大的键位映射功能，既可以用来指定快捷键，也可以规避特殊符号输入繁琐的问题。

```shell
" 标题
" 1级标题=,1+标题名字+,f
" 2级标题=,2+标题名字+,f
" 3级标题=,3+标题名字+,f
autocmd Filetype markdown inoremap <leader>f <Esc>/<++><CR>:nohlsearch<CR>i<Del><Del><Del><Del>
autocmd Filetype markdown inoremap <leader>1 <ESC>o#<Space><Enter><++><Esc>kA
autocmd Filetype markdown inoremap <leader>2 <ESC>o##<Space><Enter><++><Esc>kA
autocmd Filetype markdown inoremap <leader>3 <ESC>o###<Space><Enter><++><Esc>kA
autocmd Filetype markdown inoremap <leader>4 <ESC>o####<Space><Enter><++><Esc>kA
autocmd Filetype markdown inoremap <leader>5 <ESC>o#####<Space><Enter><++><Esc>kA
autocmd Filetype markdown inoremap <leader>6 <ESC>o######<Space><Enter><++><Esc>kA
" 代码片段
" 行内代码=,s+代码内容+,f
" 代码片段=,c+语言类型+,f+代码内容+,f
autocmd Filetype markdown inoremap <leader>c ```<Enter><++><Enter>```<Enter><++><Enter><Esc>4kA
autocmd Filetype markdown inoremap <leader>s ``<++><Esc>F`i
```

4 md语法隐藏
---

默认情况下vim会隐藏markdown的语法，比如链接（网址链接和图片链接）、代码段。

只需要添加[vim-markdown](https://github.com/preservim/vim-markdown)的插件支持，然后按照README简单配置即可放开语法隐藏。

```shell
" tabular必须在vim-markdown之前
Plugin 'godlygeek/tabular'
Plugin 'preservim/vim-markdown'
" 取消md文件中所有的语法隐藏
" 在vim中放开所有的md源码(包括了网址链接和图片链接)
let g:vim_markdown_conceal = 0
" 代码格式需要单独指定配置
let g:vim_markdown_conceal_code_blocks = 0
```

5 渲染
---

有时可能在编辑的同时需要渲染的功能，[vim-instant-markdown](https://github.com/instant-markdown/vim-instant-markdown)这个插件非常好用。

但是这个插件需要在本机安装额外的nodejs服务instant-markdown-d，安装也很简单`npm -g install instant-markdown-d`。

```shell
❯ npm list -g
/usr/local/lib
├── hexo-cli@4.3.1
├── instant-markdown-d@0.3.0
├── markdown-preview@1.0.1
├── npm@9.8.0
├── semver@7.5.4
└── vsc-leetcode-cli@2.8.0
```

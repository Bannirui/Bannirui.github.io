#!/bin/bash

# 创建文章

POST_DIR="java"
POST_PREFIX="jvm"

# 博客文章名
POST_NAME="${POST_PREFIX}-16-Java对象的表示oop"

# hexo new post
hexo new post "${POST_NAME}" -p "/${POST_DIR}/${POST_NAME}.md"
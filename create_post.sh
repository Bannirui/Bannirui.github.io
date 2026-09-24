#!/bin/bash

# 创建文章

POST_DIR="java"
POST_PREFIX="javac"

# 博客文章名
POST_NAME="${POST_PREFIX}-00-javac源码环境"

# hexo new post
hexo new post "${POST_NAME}" -p "/${POST_DIR}/${POST_NAME}.md"
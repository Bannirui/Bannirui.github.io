#!/bin/bash

# 创建文章

POST_DIR="java"
POST_PREFIX="jvm"

# 博客文章名
POST_NAME="${POST_PREFIX}-14-表示java_lang_ClassLoader类的InstanceClassLoaderKlass"

# hexo new post
hexo new post "${POST_NAME}" -p "/${POST_DIR}/${POST_NAME}.md"
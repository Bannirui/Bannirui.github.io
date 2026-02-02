<div align="center">

# BANNIRUI.GITHUB.IO

Build a blog site via `GitHub Pages` and `Hexo`, also putting them into an archive.

</div>

<p align="center">
<img alt="GitHub License" src="https://img.shields.io/github/license/Bannirui/Bannirui.github.io">
<img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/bannirui/bannirui.github.io">
<img alt="GitHub commit activity (branch)" src="https://img.shields.io/github/commit-activity/w/Bannirui/Bannirui.github.io/hexo">
<img alt="GitHub last commit (branch)" src="https://img.shields.io/github/last-commit/Bannirui/Bannirui.github.io/hexo">
</p>

<p align="center">
<a href="INTRODUCE.md">介绍</a>
</p>

### 1 Quick Start

- 1.1 执行cmake配置

    ```sh
    chmod +x ./configure.sh
    ./configure.sh
    ```
- 1.2 安装node依赖 执行make目标npm_install

- 1.3 新建文章 执行make目标hexo_new

- 1.4 本地服务 执行make目标hexo_server

- 1.5 站点发布 执行make目标hexo_deploy

### 2 Build In Docker

#### 2.1 make image

```sh
docker buildx build \
  -t my-blog-dev ./docker --platform linux/amd64
```

#### 2.2 container

```sh
docker run \
--ulimit nofile=65535:65535 \
--security-opt seccomp=unconfined \
--rm -it \
--privileged \
--name my-blog-dev \
-v /etc/localtime:/etc/localtime:ro \
-v $PWD:/home/dev \
-p 4000:4000 \
- e GITHUB_TOKEN_FOR_HEXO=$GITHUB_TOKEN_FOR_HEXO \
my-blog-dev
```

#### 2.3 install npm package

```sh
npm install
```

#### 2.4 start server

```sh
hexo s -i 0.0.0.0
```

or `hexo s`

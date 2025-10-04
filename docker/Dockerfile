FROM --platform=linux/amd64 ubuntu:22.04

# 设置非交互模式 避免安装过程中阻塞
ENV DEBIAN_FRONTEND=noninteractive

# 更新源并安装所需工具
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*


# 设置工作目录
WORKDIR /home/dev

RUN npm install -g hexo-cli
RUN npm install -g hexo-plugin-gitalk

EXPOSE 4000

VOLUME /home/dev

# 容器启动后保持交互shell
CMD ["/bin/bash"]

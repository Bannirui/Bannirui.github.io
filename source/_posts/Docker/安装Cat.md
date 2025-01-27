---
title: 安装Cat
category_bar: true
date: 2024-11-26 19:20:17
categories: Docker
tags: Cat
---

[官网地址](https://github.com/dianping/cat)

### 1 下载源码

```sh
git clone https://github.com/dianping/cat.git
```

3.0版本的提交还停留在6年前，4.0的版本是2年前，部署文档还是老版本，我简单尝试了4.0版本的部署发现启动都存在问题，所以针对3.1版本进行部署

```sh
git checkout -b docker-deploy-v3.0.0 origin/v3.0.0
```

### 2 初始化数据库

cat V3.1只支持mysql v5.7版本，不支持v8.0。在mysql中创建好cat库，然后建立下面的表

[sql脚本](./安装Cat/cat.sql)

### 3 配置文件

docker目录下xxx.xml是配置文件

- 服务端使用
  - datasources.sh 根据docker镜像的环境参数动态替换datasources.xml
  - datasources.xml cat-server服务端启动要连接的mysql数据库信息 xml标签
- 客户端使用
  - client.xml cat-client接入服务端时要指定连接信息

### 4 构建镜像

进入到源码根目录

```sh
cp ./docker/Dockerfile ./
```

根据自己的需求编写调整Dockerfile，本地编译代码一直有问题，修改了maven仓库地址也拉不到包，如果一直不成功就直接下载[官网下载链接](https://github.com/dianping/cat/releases)，我下载的是v3.1.0版本`wget -P ~/MyDev/code/java/cat https://github.com/dianping/cat/releases/download/3.1.0/cat-home.war`

Dockerfile文件如下

```Dockerfile
# 构建
#FROM maven:3.8.4-openjdk-8 as builder
#WORKDIR /app
#COPY cat-alarm cat-alarm
#COPY cat-consumer cat-consumer
#COPY cat-hadoop cat-hadoop
#COPY cat-client cat-client
#COPY cat-core cat-core
#COPY cat-home cat-home
#COPY pom.xml pom.xml
#RUN mvn clean package -DskipTests

# 运行
FROM tomcat:8.5.84-jre8
ENV TZ=Asia/Shanghai
#COPY --from=builder /app/cat-home/target/cat-home.war /usr/local/tomcat/webapps/cat.war
COPY cat-home.war /usr/local/tomcat/webapps/cat.war
# cat-server的数据源配置
COPY docker/datasources.xml /data/appdatas/cat/datasources.xml
COPY docker/datasources.sh datasources.sh
# tomcat的端口替换为8085
RUN sed -i "s/port=\"8080\"/port=\"8085\"\ URIEncoding=\"utf-8\"/g" $CATALINA_HOME/conf/server.xml && chmod +x datasources.sh
# 暴露端口
EXPOSE 8085 2280
# cat-server依赖的目录权限
RUN mkdir -p /data/appdatas/cat
RUN mkdir -p /data/applogs/cat 
RUN chmod 777 /data/appdatas/cat 
RUN chmod 777 /data/applogs/cat
# 启动tomcat
CMD ["/bin/sh", "-c", "./datasources.sh && catalina.sh run"]
```

构建镜像

```sh
docker build -f Dockerfile -t my-cat:v1 .
```

### 5 启动容器

```sh
docker run \
    -p 8085:8085 \
    -p 2280:2280 \
    -v /Users/dingrui/MyDev/code/java/cat/docker:/data/appdatas/cat/ \
    -e MYSQL_URL=host.docker.internal \
    -e MYSQL_PORT=3306 \
    -e MYSQL_USERNAME=dingrui \
    -e MYSQL_PASSWD=19920308 \
    -e MYSQL_SCHEMA=cat \
    -d \
    --name my-cat \
    my-cat:v1
```

### 5 后台页面

- 网址 http://127.0.0.1:8085/cat/s/config?op=projects
- 账号 admin
- 密码 admin

![](./安装Cat/1735121114.png)

### 6 修改服务端配置

http://127.0.0.1:8085/cat/s/config?op=serverConfigUpdate

```xml
<?xml version="1.0" encoding="utf-8"?>
<server-config>
   <server id="default">
      <properties>
         <property name="local-mode" value="false"/>
         <property name="job-machine" value="true"/>
         <property name="send-machine" value="true"/>
         <property name="alarm-machine" value="true"/>
         <property name="hdfs-enabled" value="false"/>
         <property name="remote-servers" value="127.0.0.1:8085"/>
      </properties>
      <storage local-base-dir="/data/appdatas/cat/bucket/" max-hdfs-storage-time="15" local-report-storage-time="2" local-logivew-storage-time="1" har-mode="true" upload-thread="5">
         <hdfs id="dump" max-size="128M" server-uri="hdfs://127.0.0.1/" base-dir="/user/cat/dump"/>
         <harfs id="dump" max-size="128M" server-uri="har://127.0.0.1/" base-dir="/user/cat/dump"/>
         <properties>
            <property name="hadoop.security.authentication" value="false"/>
            <property name="dfs.namenode.kerberos.principal" value="hadoop/dev80.hadoop@testserver.com"/>
            <property name="dfs.cat.kerberos.principal" value="cat@testserver.com"/>
            <property name="dfs.cat.keytab.file" value="/data/appdatas/cat/cat.keytab"/>
            <property name="java.security.krb5.realm" value="value1"/>
            <property name="java.security.krb5.kdc" value="value2"/>
         </properties>
      </storage>
      <consumer>
         <long-config default-url-threshold="1000" default-sql-threshold="100" default-service-threshold="50">
            <domain name="cat" url-threshold="500" sql-threshold="500"/>
            <domain name="OpenPlatformWeb" url-threshold="100" sql-threshold="500"/>
         </long-config>
      </consumer>
   </server>
   <server id="127.0.0.1">
      <properties>
         <property name="job-machine" value="true"/>
         <property name="send-machine" value="true"/>
         <property name="alarm-machine" value="true"/>
      </properties>
   </server>
</server-config>
```

配置好后重启容器

### 7 客户端路由配置

http://127.0.0.1:8085/cat/s/config?op=routerConfigUpdate

客户端路配置有两个注意点
- 要接入的cat-client
- 要连接的服务端ip不要写127.0.0.1，要写本机真实的ip

```xml
<?xml version="1.0" encoding="utf-8"?>
<router-config backup-server="10.181.137.245" backup-server-port="2280">
   <default-server id="10.181.137.245" weight="1.0" port="2280" enable="true"/>
   <network-policy id="default" title="默认" block="false" server-group="default_group">
   </network-policy>
   <server-group id="default_group" title="default-group">
      <group-server id="10.181.137.245"/>
   </server-group>
   <domain id="cat">
      <group id="default">
         <server id="10.181.137.245" port="2280" weight="1.0"/>
      </group>
   </domain>
   <domain id="msb">
      <group id="default">
         <server id="10.181.137.245" port="2280" weight="1.0"/>
      </group>
   </domain>
</router-config>

```

### 8 应用接入cat-client

#### 8.1 AppName

/resources/META-INF/app.properties

```properties
app.id=SampleApp
```

#### 8.2 client.xml

/resources/META-INF/cat/client.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<config mode="client">
    <servers>
        # cat-client要连接的服务端
        <server ip="127.0.0.1" port="2280" http-port="8085"/>
    </servers>
    # 客户端配置
    <domain id="msb" enabled="true" />
</config>
```

#### 8.3 日志看板

![](./安装Cat/1736245718.png)
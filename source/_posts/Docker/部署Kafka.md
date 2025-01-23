---
title: 部署Kafka
category_bar: true
date: 2025-01-13 10:23:07
categories: Docker
tags: Kafka
---

### 1 docker-compose

到`/Users/dingrui/MyApp/docker-app/Kafka`新建docker-compose.yml文件

```yml
services:
  kafka1:
    image: wurstmeister/kafka
    container_name: kafka1
    ports:
      - 9091:9091
    environment:
      HOSTNAME: kafka1
      KAFKA_BROKER_ID: 0
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka1:9091
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9091
      KAFKA_ZOOKEEPER_CONNECT: host.docker.internal:2181/kafka
    # 容器中hosts映射
    extra_hosts:
      - host.docker.internal:host-gateway

  kafka2:
    image: wurstmeister/kafka
    container_name: kafka2
    ports:
      - 9092:9092
    environment:
      HOSTNAME: kafka2
      KAFKA_BROKER_ID: 1
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka2:9092
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092
      KAFKA_ZOOKEEPER_CONNECT: host.docker.internal:2181/kafka
    extra_hosts:
      - host.docker.internal:host-gateway

  kafka3:
    image: wurstmeister/kafka
    container_name: kafka3
    ports:
      - 9093:9093
    environment:
      HOSTNAME: kafka3
      KAFKA_BROKER_ID: 2
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka3:9093
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9093
      KAFKA_ZOOKEEPER_CONNECT: host.docker.internal:2181/kafka
    extra_hosts:
      - host.docker.internal:host-gateway
```

### 2 启动集群

```sh
docker-compose up -d
```
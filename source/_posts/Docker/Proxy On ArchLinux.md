---
title: Proxy On ArchLinux
category_bar: true
date: 2025-10-04 21:14:44
categories: Docker
---

A couple of days ago, i installed a new Linux distribution called `omarchy`, it's pretty cool. But, it can only configure under the `.config` and forbid users to config system through Settings like ubuntu or debian.

And, it provides builtin docker, native docker, instead of docker desktop.

So, it cannot work cause of the network proxy, the host could work via clash, but docker failed.

### 1 host ip

```sh
ip address
```

look for the host ip, to overwrite the clash config

### 2 clash config

the config path is `~/.config/clash` or `~/.config/clash/profiles`, it depends on u

```sh
Allow LAN: true
Bind Address: 0.0.0.0
```

then restart the clash service

### 3 docker proxy

create or modify the file `/etc/systemd/system/docker.service.d/proxy.conf`, as below, replace the ip with above step

```sh
[Service]
Environment="HTTP_PROXY=http://192.168.x.x:7890"
Environment="HTTPS_PROXY=http://192.x.x.168:7890"
Environment="NO_PROXY=localhost,127.0.0.1,::1"
```

### 4 restart docker

```sh
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 5 check docker Environment

```sh
sudo systemctl show docker --property=Environment
```

---
title: systemctl命令
date: 2024-01-25 09:40:46
categories: Linux
---

1 格式
---

```shell
systemctl [OPTIONS...] COMMAND ...
```

即`systemctl 参数 动作 服务名``

2 参数
---

|opton|remark|
|---|---|
|-a|显示所有单位|
|-f|覆盖任何冲突的符号连接|
|-H|设置要连接的主机名|
|-M|设置要连接的容器名|
|-n|设置要显示的日志行数|
|-o|设置要显示的日志格式|
|-q|静默执行模式|
|-r|显示本地容器的单位|
|-s|设置要发送的进程信号|
|-t|设置单元类型|
|-help|显示帮助信息|
|-version|显示版本信息|

3 动作
---

|opton|remark|
|---|---|
|start|启动服务|
|stop|停止服务|
|restart|重启服务|
|enable|设置服务开机自启|
|disable|取消服务开机自启|
|status|查看服务状态|
|list|现实所有已启动服务|
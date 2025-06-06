---
title: etcd-0x06-怎么跟客户端通信
category_bar: true
date: 2025-06-06 16:34:45
categories: etcd
---

etcd用了严格的REST API风格，GET对应查，PUT对应写，所以只看这两个就行

### 1 HTTP服务器

```go
// serveHTTPKVAPI starts a key-value server with a GET/PUT API and listens.
// 开启一个http服务器监听在指定端口上 等待客户端的rest api
// @Param kv 键值对数据库组件 httpKVAPI组件组合了kv store 所以收到了客户端请求后就可以操作kv store进行读写
// @Param port 开放给客户端的端口
// @Param errorC raft给的channel 在httpKVAPI组件里面订阅 raft异常了这边也终止
func serveHTTPKVAPI(kv *kvstore, port int, confChangeC chan<- raftpb.ConfChange, errorC <-chan error) {
	srv := http.Server{
		Addr: ":" + strconv.Itoa(port),
		// httpKVAPI实现了接口Handler 有请求进来后httpKVAPI::ServeHTTP会被调用
		Handler: &httpKVAPI{
			store:       kv,
			confChangeC: confChangeC,
		},
	}
	go func() {
		// 监听在port端口等待客户端请求
		if err := srv.ListenAndServe(); err != nil {
			log.Fatal(err)
		}
	}()

	// exit when raft goes down
	if err, ok := <-errorC; ok {
		// raft组件给的error channel raft一旦异常了 httpKVAPI也终止掉
		log.Fatal(err)
	}
}
```

那么怎么指定服务端口呢

```go
	// 集群共识算法通信端口
	cluster := flag.String("cluster", "http://127.0.0.1:9021", "comma separated cluster peers")
	// 节点标识
	id := flag.Int("id", 1, "node ID")
	// 客户端端口
	kvport := flag.Int("port", 9121, "key-value server port")
	join := flag.Bool("join", false, "join an existing cluster")
	flag.Parse()
```

```go
// 负责对客户端请求的处理 相当于Spring MVC的Controller 实现了Handler 这个接口就一个方法ServeHTTP 客户端有请求进来后ServeHTTP方法会被回调
type httpKVAPI struct {
	// 在httpKVAPI组件中组合了kvstore 一旦有客户端请求过来就可以操作kvstore组件
	store       *kvstore
	confChangeC chan<- raftpb.ConfChange
}
```

### 2 客户端读

```go
	case http.MethodGet:
		// 客户端get数据
		if v, ok := h.store.Lookup(key); ok {
			w.Write([]byte(v))
		} else {
			http.Error(w, "Failed to GET", http.StatusNotFound)
		}
```

### 3 客户端写

```go
	case http.MethodPut:
		// 客户端put数据
		v, err := io.ReadAll(r.Body)
		if err != nil {
			log.Printf("Failed to read on PUT (%v)\n", err)
			http.Error(w, "Failed on PUT", http.StatusBadRequest)
			return
		}
		// 请求转给kvstore 还没有真正的进行存储 先封装成键值对 然后通过propose channel通知raft进行日志决议和提交 再通过commit channel通知给kvstore进行存储
		h.store.Propose(key, string(v))

		// Optimistic-- no waiting for ack from raft. Value is not yet
		// committed so a subsequent GET on the key may return old value
		w.WriteHeader(http.StatusNoContent)
```
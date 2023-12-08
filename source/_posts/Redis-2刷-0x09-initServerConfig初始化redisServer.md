---
title: Redis-2刷-0x09-initServerConfig初始化redisServer
date: 2023-11-24 10:56:31
categories: Redis
tags: 2刷Redis
---

这个方法的体量很大，作用是对`redisServer`结构体成员进行初始化赋值，通篇大部分都是重复性劳动，比较有意思的是`initConfigValues()`这个函数。这个函数体现了C语言的封装和多态的实现方式，在正式看源码之前先做一些前置性铺垫。

1 结构体成员赋值
---

结构体中的成员可以在实例化的时候指定要初始化的值，也可以只实例化不做初始化动作。指定初始化的时候可以指定要进行初始化的成员，一个或者多个成员都可以。

```c
#include <stdio.h>

typedef struct user {
	unsigned int id;
	unsigned int age;
} user;

#define PRINT(x) \
    do{             \
        printf(#x" id=%d, age=%d\n", x.id, x.age); \
    }while(0);

int main()
{
  user u1;
  PRINT(u1)
  user u2 = {0, 1};
  PRINT(u2)
  user u3 = {.id=1, .age=2};
  PRINT(u3)
  user u4 = {.id=2};
  PRINT(u4)
  user u5 = {.age=5};
  PRINT(u5)
  user u6 = {.age=6, .id=6};
  PRINT(u6)
  return 0;
}
```

2 封装
---

封装是有目的的，一般是为了:

- 组织代码结构
- 屏蔽某些成员
- 开放某些成员

如果要实现继承，我能想到的方式有2种:

- 在结构体内存地址底部划分一块区域存放跟基类一样的成员，通过强转指针类型方式访问基类成员
- 在结构体中定义基类指针类型成员

```c
#include <stdio.h>

typedef struct person {
	unsigned int id;
	unsigned int age;
} person;

typedef struct male {
	unsigned int id;
	unsigned int age;
	int male_uniq;
} male;

typedef struct female {
	unsigned int id;
	unsigned int age;
	int female_uniq;
} female;

#define PRINT(x, id) \
    do{             \
        printf("person%d: id=%d, age=%d\n",id, x.id, x.age); \
    }while(0);

void person_fn(person *p, int id)
{
  PRINT((*p), id)
}

int main()
{
  person *p;
  male m1 = {.id=1, .age=1, .male_uniq=1};
  p = (person *) (&m1);
  person_fn(p, 1);
  female f1 = {.id=2, .age=2, .female_uniq=2};
  p = (person *) (&f1);
  person_fn(p, 2);
  return 0;
}
```

3 多态
---

基于封装，实现运行时行为变化。

```c
#include <stdio.h>

// 前向声明
typedef struct male male;
typedef struct female female;

// 类型不能是结构体 只有前向声明 不知道结构体的成员
// 只能定义为结构体指针
typedef union data {
	male *m;
	female *f;
} data;

typedef struct male {
	int id;
	int age;
	int male_uniq;
} male;

void male_fn(union data *d)
{
  printf("male: id=%d, age=%d, uniq=%d\n", d->m->id, d->m->age, d->m->male_uniq);
}

typedef struct female {
	int id;
	int age;
	int female_uniq;
} female;


void female_fn(union data *d)
{
  printf("female: id=%d, age=%d, uniq=%d\n", d->f->id, d->f->age, d->f->female_uniq);
}

typedef struct person {
	data *data;

	void (*interface)(data *);
} person;

int main(int argc, char **argv)
{
  // male
  int id1 = 111;
  int age1 = 111;
  male m = {.id=id1, .age=age1, .male_uniq=id1};
  data data1 = {.m=&m};
  person p1 = {.data=&data1, .interface=&male_fn};
  p1.interface(p1.data);

  int id2 = 222;
  int age2 = 222;
  female f = {.id=id2, .age=age2, .female_uniq=id2};
  data data2 = {.f=&f};
  person p2 = {.data=&data2, .interface=&female_fn};
  p2.interface(p2.data);
  return 0;
}
```

4 initConfigValues
---

有了上面内容的铺垫，再来看一下redis中`initConfigValues`方法的多态实现。

### 4.1 configs数组

```c
standardConfig configs[];
```

```c
typedef struct standardConfig {
    const char *name; /* The user visible name of this config */
    const char *alias; /* An alias that can also be used for this config */
    const unsigned int flags; /* Flags for this specific config */
    typeInterface interface; /* The function pointers that define the type interface */
    typeData data; /* The type specific data exposed used by the interface */
} standardConfig;
```

声明了数组，数组元素类型是`standardConfig`，其中成员重要的是`typeInterface`和`typeData`，`typeData`定义了多态实例下的数据，`typeInterface`定义了多态实例的行为。

### 4.2 api

```c
// 实例的方法 函数指针 真正实现后面创建实例的时候指定 高级语言的getter/setter
typedef struct typeInterface {
    /* Called on server start, to init the server with default value */
    void (*init)(typeData data);
    /* Called on server startup and CONFIG SET, returns 1 on success, 0 on error
     * and can set a verbose err string, update is true when called from CONFIG SET */
    int (*set)(typeData data, sds value, int update, const char **err);
    /* Called on CONFIG GET, required to add output to the client */
    void (*get)(client *c, typeData data);
    /* Called on CONFIG REWRITE, required to rewrite the config state */
    void (*rewrite)(typeData data, const char *name, struct rewriteConfigState *state);
} typeInterface;
```

### 4.3 实例数据类型

```c
// union共用内存布局 实现多态的关键
typedef union typeData {
    boolConfigData yesno;
    stringConfigData string;
    sdsConfigData sds;
    enumConfigData enumd;
    numericConfigData numeric;
} typeData;
```

目前一共定义了5种类型的数据，也就意味着需要定义5种数据结构，以及与之配套的api。

数据类型

- boolConfigData
- stringConfigData
- sdsConfigData
- enumConfigData
- numericConfigData

行为

- init
- set
- get
- rewrite

以后如果在此基础上扩展的话就很简单
- 首先在`typeData`这个结构体定义中增加数据类型
- 其次定义配套的api

### 4.4 以`boolConfigData`为例的执行流程

#### 4.4.1 `configs`数组初始化

```c
standardConfig configs[] = {
    /* Bool configs */
    createBoolConfig("rdbchecksum", NULL, IMMUTABLE_CONFIG, server.rdb_checksum, 1, NULL, NULL),
    ...
    }
```

#### 4.4.2 为每种类型提供适配的创建方法`createxxxConfig`

- createBoolConfig
- createStringConfig
- createSDSConfig
- createEnumConfig
- createIntConfig
- createUIntConfig
- createULongConfig
- createLongLongConfig
- createULongLongConfig
- createSizeTConfig
- createTimeTConfig
- createOffTConfig

上述方法的本质就是通过宏定义初始化结构体

```c
/**
 * 宏定义函数初始化standardConfig结构体
 */
#define createBoolConfig(name, alias, flags, config_addr, default, is_valid, update) { \
    /* standardConfig中name alias flags这3个成员赋值 */ \
    embedCommonConfig(name, alias, flags) \
    /* 数据实例的方法 对standardConfig中interface成员赋值 */ \
    embedConfigInterface(boolConfigInit, boolConfigSet, boolConfigGet, boolConfigRewrite) \
    /* 数据实例 对standardConfig中data成员赋值 */ \
    .data.yesno = { \
        .config = &(config_addr), \
        .default_value = (default), \
        .is_valid_fn = (is_valid), \
        .update_fn = (update), \
    } \
}
```

#### 4.4.3 多态执行

之后就是轮询数组中的`standardConfig`元素进行多态执行。

```c
void initConfigValues() {
    for (standardConfig *config = configs; config->name != NULL; config++) {
	    // 实现多态调用
        config->interface.init(config->data);
    }
}
```

#### 4.4.4 init方法

上面的方法调用，之后就会根据实际的数据类型，调用绑定的方法。
以`boolConfig`为例:

```c
/* Bool Configs */
// 给redisServer中成员赋值
static void boolConfigInit(typeData data) {
    *data.yesno.config = data.yesno.default_value;
}
```
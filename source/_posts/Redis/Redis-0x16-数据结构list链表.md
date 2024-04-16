---
title: Redis-0x16-数据结构list链表
category_bar: true
index_img: /img/Redis-0x16-数据结构list链表.png
date: 2024-04-16 13:15:25
categories: Redis
---

redis中对双链表的实现没有特别之处，链表应该是redis数据结构最简单的一种了。一样地，除了数据阈，额外维护前驱和后继指针。

1 创建实例
---

```c
/**
 * 链表实例化
 * @return 双链表实例
 */
list *listCreate(void)
{
    struct list *list;

    // 申请内存空间 申请48 bytes
    if ((list = zmalloc(sizeof(*list))) == NULL)
        return NULL;
    // 初始化操作
    list->head = list->tail = NULL;
    list->len = 0;
    list->dup = NULL; // 节点复制函数
    list->free = NULL; // 节点释放函数
    list->match = NULL; // 节点匹配函数
    return list;
}
```

2 新增
---

### 2.1 头插

```c
/**
 * 新增 头插
 * <ul>
 *   <li>空链表的时候直接初始化为头</li>
 *   <li>头插法</li>
 * </ul>
 */
list *listAddNodeHead(list *list, void *value)
{
    listNode *node;
    // 列表节点内存申请 大小为24字节
    if ((node = zmalloc(sizeof(*node))) == NULL)
        return NULL;
	// 节点的值 value字段
    node->value = value;
    if (list->len == 0) {
	    /**
	     * 空链表
	     * 加进来的这个几点就是当头节点的
	     * 初始化两个哨兵指针
	     */
        list->head = list->tail = node;
        node->prev = node->next = NULL;
    } else {
	    /**
	     * 新节点头插到现成的链表上当头
	     */
        node->prev = NULL;
        node->next = list->head;
        list->head->prev = node;
        list->head = node;
    }
	// 链表节点计数
    list->len++;
    return list;
}
```

### 2.2 尾插

```c
/**
 * 新增 尾插
 * <ul>
 *   <li>空链表的时候初始化为节点</li>
 *   <li>尾插法</li>
 * </ul>
 */
list *listAddNodeTail(list *list, void *value)
{
    listNode *node;

    // 申请内存24字节
    if ((node = zmalloc(sizeof(*node))) == NULL)
        return NULL;
    // 节点的value字段
    node->value = value;
    if (list->len == 0) {
	    // 空链表 初始化尾节点
        list->head = list->tail = node;
        node->prev = node->next = NULL;
    } else {
	    // 尾插法
        node->prev = list->tail;
        node->next = NULL;
        list->tail->next = node;
        list->tail = node;
    }
    // 链表节点计数
    list->len++;
    return list;
}
```

3 读取数据
---

一般的数据集合或者容器的实现都会配套迭代器来进行数据的遍历读取。

```c
/**
 * 使用迭代器进行遍历
 */
listNode *listNext(listIter *iter)
{
    // 遍历出来的链表节点
    listNode *current = iter->next;

    if (current != NULL) {
	    /**
	     * 根据迭代器的迭代方向找链表节点的前驱和后继节点
	     * <ul>
	     *   <li>迭代器方向是0 标识从头到尾 就找后继节点</li>
	     *   <li>迭代器方向是1 标识从尾到头 就找前驱节点</li>
	     * </ul>
	     * 更新好next指针指向的链表节点 为下一次遍历做准备
	     */
        if (iter->direction == AL_START_HEAD)
            iter->next = current->next;
        else
            iter->next = current->prev;
    }
    return current;
}
```
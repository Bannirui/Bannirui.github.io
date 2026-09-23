---
title: jvm-09-Klass
category_bar: true
categories: jvm
date: 2026-09-24 00:40:47
---

HotSpot采用oop-Klass模型表示Java的对象，oop指向对象，Klass表示对象的具体类型

为了不想每个对象都含有vtable，就把对象模型一拆为二

- oop中不包含任何虚函数，自然就没有了虚函数表
- Klass中含有虚函数表，进行方法的分发

Klass就是Java对象的具体类型

因为普通的Java类和数组的内存布局方式不同，所以体系派生出两类

- {%post_link java/jvm-10-普通类型InstanceKlass%}
- {%post_link java/jvm-11-数组类型ArrayKlass%}

## 1 layout_helper

快速判断是普通类型还是数组类型

```cpp
  /**
   * 数组类型时 _layout_helper的最高位是1 说明是负数
   * 对象类型时 _layout_helper的最高位是0 说明是正数
   * 只要判断_layout_helper就可以区分数组和对象
   */
  jint        _layout_helper;
```

## 2 继承体系

### 2.1 继承链

按照根类到当前类的严格顺序放在primary_suppers数组

```cpp
    // 记录直接父类
    set_super(k);
    Klass* sup = k;
    // 父类的继承深度
    int sup_depth = sup->super_depth();
    // 限制_primary_suppers数组只能放8个类
    juint my_depth  = MIN2(sup_depth + 1, (int)primary_super_limit());
    if (!can_be_primary_super_slow())
      my_depth = primary_super_limit();
    for (juint i = 0; i < my_depth; i++) {
      // 把直接父类的继承链放到自己的primary_suppers数组 再补充上自己这个类就完整了
      _primary_supers[i] = sup->_primary_supers[i];
    }
    Klass* *super_check_cell;
    if (my_depth < primary_super_limit()) {
      // 类的继承深度没有超过8个 _primary_suppers能放得下
      _primary_supers[my_depth] = this;
      super_check_cell = &_primary_supers[my_depth];
    }
```

### 2.2 实现了哪些接口

```cpp
  // 首先这个数组里面是要存储当前类的所有实现接口的包括直接和间接实现的接口 其次当类的继承深度太长超过8个时 会把_primary_suppers里面放不下的类也放到这个数组里面
  Array<Klass*>* _secondary_supers;
```

### 2.3 兄弟链

```cpp
void Klass::append_to_sibling_list() {
  if (Universe::is_fully_initialized()) {
    assert_locked_or_safepoint(Compile_lock);
  }
  debug_only(verify();)
  // add ourselves to superklass' subklass list
  InstanceKlass* super = superklass();
  // 什么时候才会有兄弟链的情况 大家都是派生于一个直接父类的时候
  if (super == nullptr) return;     // special case: class Object
  assert((!super->is_interface()    // interfaces cannot be supers
          && (super->superklass() == nullptr || !is_interface())),
         "an interface can only be a subklass of Object");

  // Make sure there is no stale subklass head
  super->clean_subklass();

  for (;;) {
    // 兄弟链上的第一个 也就是单链表的表头
    Klass* prev_first_subklass = Atomic::load_acquire(&_super->_subklass);
    if (prev_first_subklass != nullptr) {
      // set our sibling to be the superklass' previous first subklass
      assert(prev_first_subklass->is_loader_alive(), "May not attach not alive klasses");
      set_next_sibling(prev_first_subklass);
    }
    // Note that the prev_first_subklass is always alive, meaning no sibling_next links
    // are ever created to not alive klasses. This is an important invariant of the lock-free
    // cleaning protocol, that allows us to safely unlink dead klasses from the sibling list.
    if (Atomic::cmpxchg(&super->_subklass, prev_first_subklass, this) == prev_first_subklass) {
      return;
    }
  }
  debug_only(verify();)
}
```
---
title: jvm-10-普通类型InstanceKlass
category_bar: true
categories: jvm
date: 2026-09-24 00:49:46
---

内存布局情况

```cpp
  // InstanceKlass本身占用的内存空间
  static int header_size()            { return sizeof(InstanceKlass)/wordSize; }

  /**
   * 普通Java类型的内存布局
   *   - InstanceKlass本身占用的内存
   *   - vtable
   *   - itable
   *   - nonstatic_oop_map
   *   - 接口的实现类
   * @param vtable_length vtable占用的内存空间
   * @param itable_length itable占用的内存空间
   * @param nonstatic_oop_map_size OopMapBlock占用的内存空间
   * @param is_interface
   */
  static int size(int vtable_length, int itable_length,
                  int nonstatic_oop_map_size,
                  bool is_interface) {
    return align_metadata_size(header_size() +
           vtable_length +
           itable_length +
           nonstatic_oop_map_size +
           (is_interface ? (int)sizeof(Klass*)/wordSize : 0));
  }
```

![](./jvm-10-普通类型InstanceKlass/1790257710.png)

InstanceKlass总共有3个直接派生子类

- {%post_link java/jvm-12-表示Java引用类型的InstanceRefKlass%}
- {%post_link java/jvm-13-表示java_lang_Class类的InstanceMirrorKlass%}
- {%post_link java/jvm-14-表示java_lang_ClassLoader类的InstanceClassLoaderKlass%}
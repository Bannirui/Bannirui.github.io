---
title: OpenGL-0x07-EBO
category_bar: true
categories: OpenGL
date: 2026-06-01 16:37:18
---

什么是EBO，element buffer object，见名知义，也是映射显存的一片空间。

## 1 EBO的结构

```cpp
/**
 * 封装EBO
 * EBO本质也是让OpenGL在显存上开辟一块空间buffer 这块空间放的就是VBO顶点的索引值
 * VBO里面的顶点首先会有多个attribute 每个attribute还有对应的值
 * 如果每需要一个顶点都要定义占用的内存 显存 以及内存往显存拷贝 都是开销
 * 为了利用重复的顶点信息 就有了这样一个机制
 *   - 用VBO告诉OpenGL有哪些顶点 对应的数据在显存哪儿
 *   - 用EBO告诉OpenGL怎么组合这些顶点
 */
class IndexBuffer {
public:
    virtual ~IndexBuffer() = default;

    virtual void Bind() const = 0;
    virtual void Unbind() const = 0;

    // how many vertex in the index array
    virtual uint32_t GetCount() const = 0;

    /**
     * 创建EBO
     * @param indices EBO里面要放的数据 这些数据在内存上的位置 内存地址 把这些内存上数据复制到显存上
     * @param count 要往显存上发送多少个索引顶点 每个索引是一个整数 很容易计算出来内存要复制多少个字节到显存
     */
    static X::Ref<IndexBuffer> Create(uint32_t* indices, uint32_t count);
};
```

## 2 申请显存空间

```cpp
/**
 * 在显存上开辟上buffer空间 OpenGL分配个唯一id引用它
 * 把内存上的EBO索引数组拷贝到显存上
 * @param indices VBO的顶点索引数组在内存的什么位置 内存地址
 * @param count 多少个顶点索引值
 */
OpenGLIndexBuffer::OpenGLIndexBuffer(uint32_t *indices, uint32_t count) : m_count(count)
{
    X_PROFILE_FUNCTION();
    // OpenGL在显存上申请块空间 用唯一id引用它
    glGenBuffers(1, &m_rendererID);
    // 激活OpenGL的Array_Buffer插槽 准备发数据到显存
    glBindBuffer(GL_ARRAY_BUFFER, m_rendererID);
    // 索引值都是整数 很容易计算出来要往显存发送多少字节的内容
    glBufferData(GL_ARRAY_BUFFER, count * sizeof(uint32_t), indices, GL_STATIC_DRAW);
}
```

## 3 告诉VAO

真正规划怎么取VBO数据还是需要VAO出手，GPU会拿着VAO给的信息进行取数，所以EBO需要把点的索引方式给VAO

```cpp
void OpenGLVertexArray::SetIndexBuffer(const X::Ref<IndexBuffer>& indexBuffer) {
    X_PROFILE_FUNCTION();
    // 激活VAO在OpenGL的插槽
    glBindVertexArray(m_rendererID);
    // 激活EBO在OpenGL的插槽
    indexBuffer->Bind();
    m_indexBuffer = indexBuffer;
}
```

## 4 GPU是怎么用这个索引信息的呢

```cpp

```
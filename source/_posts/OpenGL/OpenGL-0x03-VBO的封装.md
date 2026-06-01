---
title: OpenGL-0x03-VBO的封装
category_bar: true
categories: OpenGL
date: 2026-06-01 11:11:56
---

OpenGL抽象了VBO、VAO、EBO、UBO以及shader等，都是Object概念，在项目里面，对于这些Object都进行再一次封装，原因有两个

- 为了OO的编程范式
- 便于以后更换OpenGL为其他的渲染引擎

## 1 VBO抽象定义

```cpp
/**
 * VBO(vertex buffer object)
 * 在显存上内存空间 OpenGL会生成唯一id标识object
 * OpenGL有很多我buffer类型 VBO对应的buffer类型是GL_ARRAY_BUFFER OpenGL提供了API用为绑定buffer object的类型
 * buffer object的作用是作为媒介用来在内存到显存传数据
 * 拷贝数据的时候根据应用场景选择合适的类型
 *   - GL_STREAM_DRAW 数据不变 GPU用的少
 *   - GL_STATIC_DRAW 数据不变 GPU用的多
 *   - GL_DYNAMIC_DRAW 数据经常变 GPU用的多
 */
class VertexBuffer {
public:
    virtual ~VertexBuffer() = default;

    virtual void Bind() const = 0;
    virtual void Unbind() const = 0;

    virtual const BufferLayout& GetLayout() const = 0;
    virtual void SetLayout(const BufferLayout& layout) = 0;

    /**
     * 把顶点信息从CPU侧的内存灌给GPU侧显存
     * @param data 要灌的数据在内存什么位置 内存地址
     * @param size 要传多少数据 字节
     */
    virtual void SetData(const void* data, uint32_t size) = 0;

    /**
     * 创建VBO(vertex buffer object)
     * 本质就是一片连续的显存空间
     * @param vertices VBO里面放的数据 这些数据在CPU侧内存位置 内存地址
     * @param size 需要多大的显存空间 多少个字节
     */
    static X::Ref<VertexBuffer> Create(float* vertices, uint32_t size);
    /**
     * 创建VBO
     * 只要分配空的显存 暂时不放数据
     * @param size 需要多大的显存 字节
     */
    static X::Ref<VertexBuffer> Create(uint32_t size);
};
```

## 2 显存空间的开辟

VBO的本质是显存的一片连续空间

```cpp
/**
 * 创建VBO(vertex buffer object)
 * GPU显存上开辟连续的空间用来放顶点数据
 * @param vertices VBO要放的顶点数据 在内存上的地址
 * @param size 要在显存上开辟多大空间 多少个字节
 */
OpenGLVertexBuffer::OpenGLVertexBuffer(float *vertices, uint32_t size)
{
    X_PROFILE_FUNCTION();
    // 从显存申请个buffer object 就是VBO
    glGenBuffers(1, &m_rendererID);
    // 绑定buffer类型 VBO的类型是array buffer
    glBindBuffer(GL_ARRAY_BUFFER, m_rendererID);
    /**
     * 把内存数据拷贝到显存
     *   - 参数1 显存buffer类型 VBO绑定的是array buffer
     *   - 参数2 要传多大的数据 字节
     *   - 参数3 要传的数据 就是数据的内存地址
     *   - 参数4 希望GPU怎么管理这些数据
     *     - GL_STREAM_DRAW 数据只会传一次 GPU用的次数也少
     *     - GL_STATIC_DRAW 数据只会传一次 但是GPU要经常使用
     *     - GL_DYNAMIC_DRAW 数据要反复多次传过去 GPU也会高频使用
     */
    glBufferData(GL_ARRAY_BUFFER, size, vertices, GL_STATIC_DRAW);
}
```

## 3 内存拷贝到显存

VBO的作用是把内存数据传输到显存

```cpp
void OpenGLVertexBuffer::Bind() const
{
    X_PROFILE_FUNCTION();
    glBindBuffer(GL_ARRAY_BUFFER, m_rendererID);
}
```

## 4 顶点属性

为了渲染，还得告诉OpenGL这些顶点信息的布局情况，映射shader的attribute

### 4.1 Attribute的封装

```cpp
/**
 * VBO的布局情况
 * VBO里面就是1个或多个顶点
 * 每个顶点由1个或多个分量组成
 *   - pos
 *   - color
 *   - normal
 *   - ...
 * 这么多个分量是什么顺序 每个分量多少个数字 每个数字是什么类型
 * BufferElement就表达一个分量也就是对应shader里面的attribute
 */
struct BufferElement {
    /**
     * 这个分量对应着色器里面location的名字
     *   - a_Position
     *   - a_Color
     *   - ...
     */
    std::string name;
    /**
     * 这个分量有什么数据类型表达的
     *   - pos用3个float
     *   - color用4个float
     */
    ShaderDataType type;
    // 这个分量的数据多少个字节
    uint32_t size;
    /**
     * 每个分量在顶点的偏移是多少
     * 假设顶点      pos            color
     *          x    y    z    r    g    b   a
     *        0.1f 0.2f 0.3f 0.1f 0.2f 0.3f 0.4f
     * 那么
     *   - pos这个分量在顶点的偏移是0
     *   - color这个分量在顶点的偏移是3个float=24字节
     */
    size_t offset;
    // 数据是不是归一化的
    bool normalized;

    BufferElement() = default;

    /**
     * 顶点的分量
     * @param type 分量用的什么数据表达的 比如pos用3个float color用4个float
     * @param name 这个分量对应shader着色器glsl代码里面的变量名 比如a_Position a_Color
     * @param normalized 数据是不是归一化的
     */
    BufferElement(ShaderDataType type, const std::string& name, bool normalized = false)
        : name(name), type(type), size(ShaderDataTypeSize(type)), offset(0), normalized(normalized) {}

    /**
     * 每个分量都由1个或多个数据组成 比如
     *   - pos有3个float xyz
     *   - color有4个float rgba
     *   - ...
     * @return 分量有几个数据
     */
    uint32_t GetComponentCount() const {
        switch (type) {
            case ShaderDataType::kNone: {
                return 0;
            }
            case ShaderDataType::kFloat: {
                return 1;
            }
            case ShaderDataType::kFloat2: {
                return 2;
            }
            case ShaderDataType::kFloat3: {
                return 3;
            }
            case ShaderDataType::kFloat4: {
                return 4;
            }
            case ShaderDataType::kMat3: {
                return 3;  // 3*float3
            }
            case ShaderDataType::kMat4: {
                return 4;  // 4*float4
            }
            case ShaderDataType::kInt: {
                return 1;
            }
            case ShaderDataType::kInt2: {
                return 2;
            }
            case ShaderDataType::kInt3: {
                return 3;
            }
            case ShaderDataType::kInt4: {
                return 4;
            }
            case ShaderDataType::kBool: {
                return 1;
            }
        }
        X_CORE_ASSERT(false, "Unknown ShaderDataType!");
        return 0;
    }
};
```

### 4.2 多个attribute怎么放的

```cpp
/**
 * VBO的多个attribute布局情况
 * VBO里面就是1个或多个顶点
 * 每个顶点由1个或多个分量组成
 *   - pos
 *   - color
 *   - normal
 *   - ...
 * 这么多个分量是什么顺序 每个分量多少个数字 每个数字是什么类型
 */
class BufferLayout {
public:
    BufferLayout() {}

    BufferLayout(const std::initializer_list<BufferElement>& elements) : m_elements(elements) {
        calculateOffsetsAndStride();
    }

    uint32_t GetStride() const {
        return m_stride;
    }

    const std::vector<BufferElement>& GetElements() const {
        return m_elements;
    }

    std::vector<BufferElement>::iterator begin() {
        return m_elements.begin();
    }

    std::vector<BufferElement>::iterator end() {
        return m_elements.end();
    }

    std::vector<BufferElement>::const_iterator begin() const {
        return m_elements.begin();
    }

    std::vector<BufferElement>::const_iterator end() const {
        return m_elements.end();
    }

private:
    void calculateOffsetsAndStride() {
        size_t offset = 0;
        // 统计顶点数据多少字节 就是顶点里面所有分量大小加起来
        m_stride = 0;
        for (auto& element : m_elements) {
            // 顶点分量在顶点的偏移
            element.offset = offset;
            offset += element.size;
            // 每个分量大小求和
            m_stride += element.size;
        }
    }

private:
    // 一个顶点的分量 放在vector就顺序性就是每个分量的顺序
    std::vector<BufferElement> m_elements;
    // 一个顶点的步长 也就是一个顶点数据多少字节 VBO是GPU显存上一个连续内存空间 一连串的数据
    // GPU不知道这些数据哪些是顶点A 哪些是顶点B 这个步长就是负责告诉GPU每个顶点数据是怎么划分的
    uint32_t m_stride = 0;
};
```

### 4.3 VBO得知道attribute的布局

```cpp
    void SetLayout(const BufferLayout& layout) override {
        m_bufferLayout = layout;
    }
```
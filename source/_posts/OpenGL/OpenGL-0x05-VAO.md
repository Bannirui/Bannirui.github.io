---
title: OpenGL-0x05-VAO
category_bar: true
categories: OpenGL
date: 2026-06-01 14:53:40
---

## 1 VAO概念

先看{% post_link OpenGL/OpenGL-0x03-VBO的封装 %}，VAO也是OpenGL在显存开辟一片连续内存空间，存着的信息是告诉OpenGL显存上的VBO怎么去理解

```cpp
/**
 * 封装VAO(vertex array object)
 * 跟VBO一样也是OpenGL抽象的状态 会在显存上开辟空间存储一堆数据 OpenGL会分配唯一的id引用它
 * VAO的本质就是让shader的attribute知道怎么用VBO
 */
class VertexArray {
public:
    virtual ~VertexArray() = default;

    virtual void Bind() const = 0;
    virtual void Unbind() const = 0;

    virtual void AddVertexBuffer(const X::Ref<VertexBuffer>& vertexBuffer) = 0;
    /**
     * 把EBO告诉VAO 让VAO知道取哪些顶点的索引
     * @param indexBuffer EBO
     */
    virtual void SetIndexBuffer(const X::Ref<IndexBuffer>& indexBuffer) = 0;

    virtual const std::vector<X::Ref<VertexBuffer>>& GetVertexBuffers() const = 0;
    virtual const X::Ref<IndexBuffer>& GetIndexBuffer() const = 0;

    static X::Ref<VertexArray> Create();
};
```

## 2 申请显存

```cpp
OpenGLVertexArray::OpenGLVertexArray() {
    X_PROFILE_FUNCTION();
    // 让OpenGL在显存开辟空间作为vertex array object 用id引用
    glGenVertexArrays(1, &m_rendererID);
}
```

## 3 把VBO告诉shader的attribute

这是VAO真正的使命，VBO就在显存中实打实地把顶点数据放在那儿，VAO得让shader着色器知道attribute的各个变量在VBO一整片显存的具体位置，这个信息就是VAO告诉GPU

```cpp
/**
 * 把VBO告诉VAO 让VAO知道
 *   - 具体的顶点数据
 *   - 这些顶点数据怎么布局的 pos占多少 color占多少 法线占多少
 * VAO属性绑定
 * 负责告诉OpenGL怎么把VBO里面的数据解释成着色器shader的各个属性
 *   - 把VBO绑定到VAO
 *   - 然后遍历VBO的顶点布局信息 对每个属性逐一处理 让OpenGL建立显存中每段字节->着色器attribute location的映射
 * 所以配置而言配置的就是让shader的attribute知道怎么使用VBO
 * @param vertexBuffer VBO VBO里面不仅有多个顶点的数据信息 还有这些每个顶点的有多少个分量
 */
void OpenGLVertexArray::AddVertexBuffer(const X::Ref<VertexBuffer>& vertexBuffer) {
    X_PROFILE_FUNCTION();
    // 必须得有布局 VBO中不仅需要顶点数据 还要有这些顶点数据是怎么布局的
    X_CORE_ASSERT(vertexBuffer->GetLayout().GetElements().size(), "Vertex Buffer has no layout!");
    // VAO插槽
    glBindVertexArray(m_rendererID);
    // VBO插槽
    vertexBuffer->Bind();

    // OpenGL就是个状态机 绑定VAO插槽和VBO插槽 后面才知道哪个VBO的attribute怎么解释
    const auto& layout = vertexBuffer->GetLayout();
    // for循环保证了分量的遍历顺序 跟shader的GLSL里面的location对应起来 比如依次是a_Position a_Color...
    for (const auto& element : layout) {
        switch (element.type) {
            case ShaderDataType::kFloat:
            case ShaderDataType::kFloat2:
            case ShaderDataType::kFloat3:
            case ShaderDataType::kFloat4: {
                glEnableVertexAttribArray(m_vertexBufferIndex);
                // 告诉OpenGL怎么理解顶点数据
                glVertexAttribPointer(
                    m_vertexBufferIndex,          // 对应着色器的location 比如0,1,2...就对应着色器location 0,1,2...
                    element.GetComponentCount(),  // 顶点的这个分量有多少个数据
                    ShaderDataTypeToOpenGLBaseType(element.type),                      // 数据类型
                    element.normalized ? GL_TRUE : GL_FALSE,                           // 是否归一化
                    layout.GetStride(), reinterpret_cast<const void*>(element.offset)  // 这个顶点分量在顶点中的偏移
                );
                // 比如参数依次是0 3 GL_FLOAT GL_TRUE 0
                // 就是让OpenGL去显存VBO里面从每个顶点的偏移0开始读连续3个float传给shader的location=0
                m_vertexBufferIndex++;
                break;
            }
            case ShaderDataType::kInt:
            case ShaderDataType::kInt2:
            case ShaderDataType::kInt3:
            case ShaderDataType::kInt4:
            case ShaderDataType::kBool: {
                glEnableVertexAttribArray(m_vertexBufferIndex);
                glVertexAttribIPointer(m_vertexBufferIndex, element.GetComponentCount(),
                                       ShaderDataTypeToOpenGLBaseType(element.type), layout.GetStride(),
                                       reinterpret_cast<const void*>(element.offset));
                m_vertexBufferIndex++;
                break;
            }
            case ShaderDataType::kMat3:
            case ShaderDataType::kMat4: {
                uint8_t count = element.GetComponentCount();
                for (uint8_t i = 0; i < count; i++) {
                    // OpenGL默认是关闭了顶点属性的 所以要告诉OpenGL启用attribute输入
                    // 这样shader程序就可以通过location=x取到显存里面的顶点数据
                    glEnableVertexAttribArray(m_vertexBufferIndex);
                    glVertexAttribPointer(m_vertexBufferIndex, count, ShaderDataTypeToOpenGLBaseType(element.type),
                                          element.normalized ? GL_TRUE : GL_FALSE, layout.GetStride(),
                                          reinterpret_cast<const void*>(element.offset + sizeof(float) * count * i));
                    glVertexAttribDivisor(m_vertexBufferIndex, 1);
                    m_vertexBufferIndex++;
                }
                break;
            }
            default:
                X_CORE_ASSERT(false, "Unknown ShaderDataType!");
        }
    }
    m_vertexBuffers.push_back(vertexBuffer);
}
```
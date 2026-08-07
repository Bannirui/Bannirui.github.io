---
title: OpenGL-0x04-Shader的封装
category_bar: true
categories: OpenGL
date: 2026-06-01 14:18:41
---

shader是最终跑在GPU上的代码，执行真正的渲染逻辑，与Shader息息相关的概念有

- glsl代码的编译/链接
- 向glsl传attribute变量
- 向glsl传uniform变量

glsl也是一门语言，每个版本之间会有语法特性，因为mac和linux用的OpenGL版本不一样，所以glsl的版本特性也不一样，所以shader的设计要支持运行时动态兼容

## 1 运行时OpenGL版本

### 1.1 要把采集到的版本信息保存起来

```cpp
    // 记录OpenGL的版本信息 运行时从机器上读 控制对GLAD的API调用和GLSL的语法版本选择
    struct GLRendererInfo {
        // 默认3.3
        int MajorVersion = 3;
        int MinorVersion = 3;
        // GLAD支持对spirv的支持 要借助shaderc把glsl编译成spirv字节码提交给GPU
        bool ARB_gl_spirv = false;

        bool IsAtLeast(int major, int minor) const {
            return MajorVersion > major || (MajorVersion == major && MinorVersion >= minor);
        }

        // 给GLSL的版本声明用 比如#version 330 core
        std::string GetGLSLVersionString() const {
            return "#version " + std::to_string(MajorVersion) + std::to_string(MinorVersion) + "0 core";
        }

        static GLRendererInfo& Get();
    };
```

### 1.2 OpenGLContext中拿到版本信息

GLFW负责初始化窗体，也会创建好OpenGL的Context，从里面可以拿到OpenGL的运行时版本

```cpp
    int versionMajor;
    int versionMinor;
    glGetIntegerv(GL_MAJOR_VERSION, &versionMajor);
    glGetIntegerv(GL_MINOR_VERSION, &versionMinor);

    X_CORE_ASSERT(versionMajor > 3 || (versionMajor == 3 && versionMinor >= 3),
                  "Requires at least OpenGL version 3.3, not support {}.{}", versionMajor, versionMinor);

    // 拿到运行时的OpenGL版本缓存起来
    auto& info = X::GLRendererInfo::Get();
    info.MajorVersion = versionMajor;
    info.MinorVersion = versionMinor;
```

## 2 shader类型区分

```cpp
    /**
     * 在glsl源码里面会首先声明类型 在#version之前先声明类型
     * @param type shader类型是vertex还是fragment
     */
    static GLenum shaderTypeFromString(const std::string& type) {
        if (type == "vertex") {
            return GL_VERTEX_SHADER;
        }
        if (type == "fragment" || type == "pixel") {
            return GL_FRAGMENT_SHADER;
        }
        X_CORE_ASSERT(false, "Unknown shader type");
        return 0;
    }
```

## 3 spriv字节码

跟教程里面不一样的是，当然首先是兼容了教程里面的方式。在高版本的OpenGL支持Spriv扩展支持，所以我增加了用Spriv链接的方式

```cpp
        // 支持spriv 用字节码创建shader程序
        for (auto&& [stage, spirv] : m_spirvBinaries) {
            // 创建OpenGL的shader object OpenGL会分配唯一id引用它
            GLuint shaderID = shaderIDs.emplace_back(glCreateShader(stage));
            glShaderBinary(1, &shaderID, GL_SHADER_BINARY_FORMAT_SPIR_V_ARB, spirv.data(),
                           spirv.size() * sizeof(uint32_t));
            glSpecializeShaderARB(shaderID, "main", 0, nullptr, nullptr);
            glAttachShader(program, shaderID);
        }
```

## 4 attribute变量怎么传

这个要结合VBO+VAO一起

- {% post_link OpenGL/OpenGL-0x03-VBO的封装 %}
- {% post_link OpenGL/OpenGL-0x05-VAO %}里面有详细的代码实现

## 5 uniform变量怎么传

用的核心API是`glUniformxx`

```cpp
void OpenGLShader::uploadUniformInt(const std::string& name, int value) const {
    // 先拿到shader程序里面uniform变量对应的location
    GLint location = glGetUniformLocation(m_rendererId, name.c_str());
    // 通过location给uniform变量传值 uniform变量的命名空间是每个shader的也就是说明这个变量只能当前shader用
    // UBO是OpenGL在显存开辟的常量内存可以给所有的shader共享
    glUniform1i(location, value);
}
```

## 6 UBO

这个生命周期虽然不是直接由shader，但是UBO本质就是服务shader的，上面的uniform是给每个shader单独用的，这样的局限可能造成大量的显存浪费。
因此UBO就是显存上的公共空间，让所有shader都可以共享。

{% post_link OpenGL/OpenGL-0x06-UBO %}
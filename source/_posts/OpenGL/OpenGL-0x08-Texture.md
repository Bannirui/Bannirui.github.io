---
title: OpenGL-0x08-Texture
category_bar: true
categories: OpenGL
date: 2026-06-02 23:14:13
---

为什么要有Texture，试想一下，现在要给一个物体在渲染的时候上色，当然可以一个一个像素进行颜色设置，这样的话工作量会暴增。
所以有没有一种可能，用1张2D的图片，把这个图片蒙在物体上，这就是Texture纹理对象。

## 1 Texture基类定义

```cpp
/**
 * 相比较于给很多顶点设置颜色以达到给物体生成纹理 用一个2D图片作为物体纹理 这样的方式代价很低
 * Texture的作用就是封装2D图片给物体设置纹理
 * 当然 理论上也存在1D和3D的纹理对象
 * 纹理坐标uv坐标左下角是(0,0)它的范围是[0...1] 用uv坐标在纹理对象上找贴图颜色的过程叫采样sample
 */
class Texture
{
public:
    virtual ~Texture() = default;

    virtual uint32_t           GetWidth() const      = 0;
    virtual uint32_t           GetHeight() const     = 0;
    virtual uint32_t           GetRendererID() const = 0;
    virtual const std::string& GetPath() const       = 0;
    /**
     * @param data pointer of data
     * @param size how many bytes of data
     */
    virtual void SetData(void* data, uint32_t size) = 0;

    // texture uint
    virtual void Bind(uint32_t slot = 0) const = 0;
    virtual bool IsLoaded()                    = 0;

    virtual bool operator==(const Texture& other) const = 0;

protected:
    Texture() = default;
};
```

## 2 2D纹理对象

```cpp
class Texture2D : public Texture
{
public:
    static X::Ref<Texture2D> Create(const std::string& path);
    static X::Ref<Texture2D> Create(uint32_t width, uint32_t height);
};
```

## 3 创建纹理对象的过程

```cpp
/**
 * 创建纹理对象
 * @param path 图片路径
 */
OpenGLTexture2D::OpenGLTexture2D(const std::string& path) : m_path(path) {
    X_PROFILE_FUNCTION();
    int width, height, channels;
    // OpenGL的y坐标和stb的y坐标定义方向不一样 OpenGL的0在底部 图片的0在顶部 所以要让stb翻转一下 让OpenGL拿到正确方向
    stbi_set_flip_vertically_on_load(true);
    stbi_uc* data{nullptr};
    {
        X_PROFILE_SCOPE("stbi_load - OpenGLTexture2D::OpenGLTexture2D(const std::string&)");
        data = stbi_load(path.c_str(), &width, &height, &channels, 0);
    }
    X_CORE_ASSERT(data, "Failed to load image");
    m_isLoaded = true;
    m_width = width;
    m_height = height;

    GLenum internalFormat = 0, dataFormat = 0;
    if (channels == 4) {
        internalFormat = GL_RGBA8;
        dataFormat = GL_RGBA;
    } else if (channels == 3) {
        internalFormat = GL_RGB8;
        dataFormat = GL_RGB;
    }
    // 生成纹理对象
    glGenTextures(1, &m_rendererId);
    // 激活纹理对象 也可以不用显式激活纹理单元 因为下面的BindTexture这个API会默认自动激活纹理单元0号
    glActiveTexture(GL_TEXTURE0);
    // 绑定纹理对象 类型是2d
    glBindTexture(GL_TEXTURE_2D, m_rendererId);

    // 分配cpu内存
    m_internalFormat = internalFormat;
    m_dataFormat = dataFormat;
    X_CORE_ASSERT(internalFormat & dataFormat, "Format not supported!");
    // 用图片生成一个纹理对象贴图 mipmap level设置0代表的是没有给纹理对象设置mipmap 可以在生成纹理对象后再给它设置mipmap
    glTexImage2D(GL_TEXTURE_2D,   // 纹理对象在上面已经绑定了OpenGL的2d插槽 现在要配置2d插槽就是在配置纹理对象
                 0,               // mipmap的level 不用mipmap就设置0
                 internalFormat,  // 告诉OpenGL图片的格式
                 m_width,         // 图片宽度
                 m_height,        // 图片高度
                 0,               // 为了兼容早期设计导致的 直接设置成0就行
                 dataFormat,      // 图片数据格式
                 GL_UNSIGNED_BYTE,
                 data  // 实际的图片
    );
    // 最佳的工程实践 在创建好了纹理对象也设置好了mipmap后就把图片的空间释放掉
    stbi_image_free(data);

    // 设置纹理对象参数
    /**
     * 电脑屏幕的像素和纹理像素的映射问题 它们几乎不会严格完整映射
     *   - 图片放大时 一个texel要覆盖很多pixel GPU面临的问题是中间色怎么办
     *     如果不用filtering GPU会直接复制最近的texel会导致马赛克
     *   - 图片缩小时 一个pixel对应成千上万个texel 这个时候GPU面临的问题更大 选哪个texel显示
     *     如果随便取就近的一个texel 会导致严重的走样
     *       - 闪烁
     *       - 摩尔纹
     *       - 抖动
     *       - 远处噪声
     */
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    /**
     * 纹理的坐标是0到1 起点是左下方的xy坐标系
     * 指定的贴图坐标是(0,0)到(1,1) 要是超出了这个约定范围怎么办
     *   - S对应U x横向
     *   - T对应V y纵向
     * 默认的策略是repeat
     * OpenGL的策略
     *   - repeat 循环
     *   - mirror repeat 镜像循环
     *   - clamp to edge 超出后用边缘的像素
     *     - <0 用最左边的像素
     *     - >1 用最右边的像素
     *   - clamp to border 越界后不采样纹理 直接用borderColor 就是要先给shader设置一个borderColor一旦越界就用它
     */
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

    // 让OpenGL状态机上的2D纹理插槽撤掉当前纹理对象 防止后面误操作当前的纹理对象
    glBindTexture(GL_TEXTURE_2D, 0);
}
```

## 4 引擎把采样器传给fragment

```cpp
    {
        // 用uniform变量形式告诉shader采样器和纹理单元号的映射关系
        // 因为vertex attribute只会告诉shader纹理单元编号 纹理单元跟采样器一一映射 shader就知道用哪个贴图采样器了
        int samplers[Renderer2DData::MaxTextureSlots];
        for (int i = 0; i < Renderer2DData::MaxTextureSlots; i++) {
            samplers[i] = i;
        }
        s_data.QuadShader->SetIntArray("u_Textures", samplers, Renderer2DData::MaxTextureSlots);
    }
```

## 5 fragment用采样器

```glsl
// 用glUniform1iv把sampler数据传了进来
// 简单情况下在渲染之前调用一次shader的bind OpenGL就会自动地把2D插槽上的texture发送给frag着色器 所以只要uniform sampler2D xxx就拿到了
// 默认情况是纹理单元0号的那个纹理对象
// 现在引擎内部的做法是在初始化texture的时候定义了一个16个大小的texutre缓冲区 在渲染前会变量都bind到插槽上
// 然后手动传uniform数组到shader方式把纹理对象和纹理单元的映射关系传过来 相当于segment会收到16个采样器
// 因此vertex attribute会传进来texture index说明用哪个采样器 两个组合起来 segment就知道用哪个采样器了
uniform sampler2D u_Textures[16];

void main()
{
    // glsl不支持在sampler数组用变量作为下标 texture(u_Textures[int(v_TexIndex)] 用宏展开switch...case
    // tilingFactor贴图因子 uv坐标值区间[0...1] 假设因子是n 那么现在uv区间就是[0...n] 当uv超出1后触发OpenGL策略 现在设置的是repeat
#define TEXTURE_CASE(n) case n: texColor *= texture(u_Textures[n], Input.TexCoord * Input.TilingFactor); break;

    vec4 texColor = Input.Color;
    switch (Input.TexIndex) {
        TEXTURE_CASE(0)  TEXTURE_CASE(1)  TEXTURE_CASE(2)  TEXTURE_CASE(3)
        TEXTURE_CASE(4)  TEXTURE_CASE(5)  TEXTURE_CASE(6)  TEXTURE_CASE(7)
        TEXTURE_CASE(8)  TEXTURE_CASE(9)  TEXTURE_CASE(10) TEXTURE_CASE(11)
        TEXTURE_CASE(12) TEXTURE_CASE(13) TEXTURE_CASE(14) TEXTURE_CASE(15)
    }

#undef TEXTURE_CASE
    if(texColor.a == 0.0) {
        discard;
    }
    o_Color = texColor;
    o_EntityID = Input.EntityID;
}
```
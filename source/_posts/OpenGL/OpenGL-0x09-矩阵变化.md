---
title: OpenGL-0x09-矩阵变化
category_bar: true
categories: OpenGL
date: 2026-06-03 16:04:21
---

这个就纯属线性代数了

- 矩阵跟矩阵的乘法规则
- 单位矩阵

矩阵的变化就是对缩放、旋转、平移的组合，顺序是缩放->旋转->平移

在{% post_link OpenGL/OpenGL-0x01-CMake编译OpenGL项目 %}提到过GLM，进行矩阵运算的时候就借助这个库

```cpp
    // 变换矩阵 仅仅绕着z轴旋转角度
    glm::mat4 transform = glm::translate(glm::mat4(1.0f), position) * /*最后移动*/
                          glm::rotate(glm::mat4(1.0f), glm::radians(rotation), {0.0f, 0.0f, 1.0f}) * /*再旋转 绕着z轴旋转rotation角度*/
                          glm::scale(glm::mat4(1.0f), {size.x, size.y, 1.0f}); /*先缩放 对xy缩放*/
```

## 1 它有什么用处

```glsl
    gl_Position = u_ViewProjection * worldPos;
```

在vertex shader中最终都要向GPU输出一个gl_Position，这就是所谓的剪裁空间坐标，决定着最终渲染出来的效果

## 2 矩阵及矩阵运算扮演的角色

当然可以在每一帧都向GPU传输最新的顶点坐标，显然从内存向显存传输是极大的性能消耗，所以通常都是定义一个初始顶点坐标，然后告诉GPU这个顶点坐标需要经过怎么样的计算
才能变成最终的剪裁坐标。

这里面的公式是什么呢，V(clip)=P(投影矩阵)*V(观察矩阵)*M(模型矩阵)*V(local)

- V(local) 物体的本地坐标
- M模型矩阵 把本地坐标转换成世界坐标
- V观察矩阵 把世界坐标转换成观察空间坐标
- P投影矩阵 把观察坐标转换成剪裁空间坐标

所以渲染的过程变成了

- 初始的时候告诉GPU物体的本地坐标是什么
- 每一帧更新的时候告诉GPU
  - M模型矩阵是什么
  - V观察矩阵是什么
  - P投影矩阵是什么

### 2.1 模型矩阵怎么定义

就是上面提到的缩放、旋转、平移的矩阵相乘

### 2.2 观察矩阵怎么定义

这个比较复杂，可以看{%post_link OpenGL/OpenGL-0x0A-摄像机%}

### 2.3 投影矩阵怎么定义

```cpp
void EditorCamera::updateProjection() {
    // 宽高比
    m_aspectRatio = m_viewportWidth / m_viewportHeight;
    // 投影矩阵的公式
    m_projection = glm::perspective(glm::radians(m_fov), /* 角度->弧度 */
                                    m_aspectRatio, /* 宽高比 */
                                    m_nearClip, /* 近距离 */
                                    m_farClip /* 远距离 */
    );
}
```
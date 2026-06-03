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
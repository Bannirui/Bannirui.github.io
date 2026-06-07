---
title: OpenGL-0x0A-摄像机
category_bar: true
categories: OpenGL
date: 2026-06-07 12:31:04
---

书接上回{%post_link OpenGL/OpenGL-0x09-矩阵变化%}，相机的本质是要提供从相机视角的观察矩阵。但是从投影矩阵的公式可以看到几个变量

- 视野角度
- 宽高比=视口宽度/视口高度
- 近距离
- 远距离

在每一帧中，可能会进行缩放视口，所以投影矩阵也会在每一帧进行变换。那么如果让相机持有投影矩阵P，然后自己又可以提供观察矩阵M，其实客户端就可以得到P*M。

## 1 相机对客户端的交付

```cpp
    /**
     * MVP变换
     * 剪裁空间坐标
     * gl_Position = 投影矩阵*观察矩阵*模型矩阵*本地坐标
     * @return 投影矩阵*观察矩阵
     */
    glm::mat4 GetViewProjection() const {
        return m_projection * m_viewMatrix;
    }
```

## 2 投影矩阵的更新计算

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

## 3 相机的观察矩阵

```cpp
void EditorCamera::updateView() {
    // 相机位置
    m_position = calculatePosition();
    // 相机的四元数
    glm::quat orientation = GetOrientation();
    // 先把四元数转换成旋转矩阵 再构造出camera transform
    m_viewMatrix = glm::translate(glm::mat4(1.0f), m_position) * glm::toMat4(orientation);
    // 为什么要求逆 ViewMatrix的本质是把世界变换到相机空间 不是相机如何移动 而是世界如何反向移动
    m_viewMatrix = glm::inverse(m_viewMatrix);
}
```

关于相机的运动，分为自由移动和视角移动

- 自由移动改变的是相机的位置
- 视角移动改变的是欧拉角

### 3.1 关于相机位置

```cpp
glm::vec3 EditorCamera::calculatePosition() const {
    // 从焦点出发 沿着相机视线的把方向走distance就到了相机
    return m_focalPoint - GetForwardDirection() * m_distance;
}
```

相机位置是通过焦点位置计算出来的，所以相机的自由移动改变的是

- 相机焦点
- 相机和焦点之间的距离

进而，每次移动完就计算出来最新的相机位置

### 3.2 关于四元数

```cpp
glm::quat EditorCamera::GetOrientation() const {
    // 加负号原因是站在相机视角 物体就是相对反方向
    // 用四元数记录相机欧拉角信息
    return glm::quat(glm::vec3(-m_pitch, /*绕X轴的俯仰角*/
                               -m_yaw, /*绕Y轴的偏航角*/
                               0.0f /*绕Z轴的滚转角*/));
}
```

相机的欧拉角信息用四元数存起来，用的时候直接用四元数计算。
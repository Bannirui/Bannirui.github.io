---
title: OpenGL-0x02-窗体的封装
category_bar: true
categories: OpenGL
date: 2026-06-01 10:40:35
---

我并没有直接调用GLFW的API，为什么？因为公司用的电脑是mac mini，家里的电脑是linux。两台电脑适配的OpenGL版本不一样，导致项目的实现也要考虑跨平台

## 1 接口的抽象

把Window定义成纯接口，把它的构造函数用protect限定起来

```cpp
// 封装的窗体 掩藏glfw的细节
class Window
{
public:
    using EventCallbackFn = std::function<void(Event&)>;

    virtual ~Window() = default;

    virtual void OnUpdate() = 0;

    virtual uint32_t GetWidth() const  = 0;
    virtual uint32_t GetHeight() const = 0;

    virtual void SetEventCallback(const EventCallbackFn& callback) = 0;
    virtual void SetVSync(bool enabled)                            = 0;
    virtual bool IsVSync()                                         = 0;

    // 暴露glfw的窗体
    virtual void* get_nativeWindow() const = 0;

    static X::Scope<Window> Create(const WindowProps& props = WindowProps());

protected:
    Window() = default;
};
```

## 2 平台检测

```cpp
// ================================
// Platform detection
// ================================
#if defined(_WIN32)
#    ifdef _WIN64
#        define X_PLATFORM_WINDOWS
#    else
#        error "x86 Builds are not supported"
#    endif
#elif defined(__APPLE__) || defined(__MACH__)
#    include <TargetConditionals.h>
#    if TARGET_IPHONE_SIMULATOR == 1
#        error "IOS simulator is not supported"
#    elif TARGET_OS_IPHONE == 1
#        define X_PLATFORM_IOS
#        error "IOS is not supported"
#    elif TARGET_OS_MAC == 1
#        define X_PLATFORM_MAC
#    else
#        error "Unkonown Apple platform"
#    endif
#elif defined(__ANDROID__)
#    define X_PLATFORM_ANDROID
#    error "Android is not supported"
#elif defined(__linux__)
#    define X_PLATFORM_LINUX
#else
#    error "Unknown platform!"
#endif
```

## 3 跨平台的控制

用宏控制编译mac的实现还是linux的实现

```cpp
#if defined(X_PLATFORM_MAC)
#include "platform/mac/mac_window.h"
#elif defined(X_PLATFORM_LINUX)
#include "platform/linux/linux_window.h"
#else
#error "Unsupported platform!"
#endif

X::Scope<Window> Window::Create(const WindowProps &props)
{
#if defined(X_PLATFORM_MAC)
    return X::CreateScope<MacWindow>(props);
#elif defined(X_PLATFORM_LINUX)
    return X::CreateScope<LinuxWindow>(props);
#else
    return nullptr;  // 理论上不会走到这里
#endif
}
```
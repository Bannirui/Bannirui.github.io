---
title: OpenGL-0x01-CMake编译OpenGL项目
category_bar: true
categories: OpenGL
date: 2026-06-01 10:13:28
---

我选择的当然是CMake+Make管理编译项目，显然需要依赖的三方库有

- GLFW
- GLAD
- GLM

## 1 GLFW的整合

```cmake
# 依赖FetchContent管理三方库
include(FetchContent)
if (UNIX)
    set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
    set(GLFW_BUILD_WAYLAND OFF CACHE BOOL "" FORCE)
    set(GLFW_BUILD_X11 ON CACHE BOOL "" FORCE)
endif ()

# glfw
FetchContent_Declare(
        glfw
        GIT_REPOSITORY	https://github.com/glfw/glfw.git
        GIT_TAG 	    3.4
        GIT_PROGRESS TRUE
)
# 下载依赖的源码
FetchContent_MakeAvailable(glfw)
```

## 2 GLAD的整合

```cmake
# glad的代码生成依赖py/pip和glad
# python
find_package(Python3 REQUIRED COMPONENTS Interpreter)
set(MY_VENV "${CMAKE_BINARY_DIR}/.venv")
if (WIN32)
    set(MY_PYTHON "${MY_VENV}/bin/python.exe")
else ()
    set(MY_PYTHON "${MY_VENV}/bin/python3")
endif ()

# py虚拟环境
if (NOT EXISTS "${MY_VENV}")
    message(STATUS "Creating virtualenv at ${MY_VENV}")
    # 创建.venv
    execute_process(
            COMMAND ${Python3_EXECUTABLE} -m venv "${MY_VENV}"
            RESULT_VARIABLE VENV_CREATE_RESULT
    )
    if (NOT VENV_CREATE_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to create virtual environment at ${MY_VENV}")
    endif ()
else ()
    message(STATUS "Found existing virtualenv: ${MY_VENV}")
endif ()

# ensure pip exists inside venv
execute_process(
        COMMAND ${MY_PYTHON} -m ensurepip --upgrade
        RESULT_VARIABLE VENV_PIP_RET
        OUTPUT_QUIET
        ERROR_QUIET
)
if (NOT VENV_PIP_RET EQUAL 0)
    message(FATAL_ERROR "Failed to bootstrap pip inside virtualenv")
endif ()

# 检查glad命令
execute_process(
        COMMAND ${MY_PYTHON} -m glad --help
        RESULT_VARIABLE GLAD_RET
        OUTPUT_QUIET
        ERROR_QUIET
)
if (NOT GLAD_RET EQUAL 0)
    message(STATUS "Installing glad in venv...")
    # 安装glad到虚拟环境中
    execute_process(
            COMMAND ${MY_PYTHON} -m pip install glad
            --no-cache-dir
            --timeout 60
            -i https://pypi.tuna.tsinghua.edu.cn/simple
            RESULT_VARIABLE GLAD_INSTALL_RET
            ERROR_VARIABLE GLAD_INSTALL_ERR
    )
    if (NOT GLAD_INSTALL_RET EQUAL 0)
        message(FATAL_ERROR "Failed to install glad in virtualenv:\n${GLAD_INSTALL_ERR}")
    endif ()
    message(STATUS "Glad installed successfully in ${MY_VENV}")
else ()
    message(STATUS "Glad already exist in ${MY_VENV}")
endif ()

# 依赖FetchContent管理三方库
include(FetchContent)
# glad
FetchContent_Declare(
        glad
        GIT_REPOSITORY https://github.com/Dav1dde/glad.git
        GIT_TAG v2.0.8
        GIT_PROGRESS TRUE
)

# 下载依赖的源码
FetchContent_MakeAvailable(glad)
# glad2没有现成的代码 用py生成glad代码
set(GLAD_GENERATED_DIR "${CMAKE_BINARY_DIR}/generated/glad")
set(GLAD_C_FILE "${GLAD_GENERATED_DIR}/src/glad.c")
set(GLAD_H_FILE "${GLAD_GENERATED_DIR}/include/glad/glad.h")
file(MAKE_DIRECTORY ${GLAD_GENERATED_DIR})

# glad源码文件不存在 再执行生成
if (NOT EXISTS ${GLAD_C_FILE})
    if (APPLE)
        set(GLAD_API_VER "4.1")
        set(GLAD_EXTENSIONS "")
    elseif (LINUX)
        # linux上支持的OpenGL的版本上限
        set(GLAD_API_VER "4.6")
        # 借助shaderc把glsl编译成spriv字节码提交给GPU
        set(GLAD_EXTENSIONS "GL_ARB_gl_spirv")
    else ()
        message(FATAL_ERROR "Unknown platform, cannot specify OpenGL version")
    endif ()
    message(STATUS "Glad output not found, will generate with glad2 for OpenGL${GLAD_API_VER}")

    set(GLAD_ENV)
    if(DEFINED ENV{http_proxy})
        list(APPEND GLAD_ENV http_proxy=$ENV{http_proxy})
    endif()
    if(DEFINED ENV{https_proxy})
        list(APPEND GLAD_ENV https_proxy=$ENV{https_proxy})
    endif()

    add_custom_command(
            OUTPUT ${GLAD_C_FILE} ${GLAD_H_FILE}
            COMMAND ${CMAKE_COMMAND} -E env
                ${GLAD_ENV}
                ${MY_PYTHON} -m glad --generator c --spec gl --api gl=${GLAD_API_VER} --profile core --out-path ${GLAD_GENERATED_DIR} --extensions "${GLAD_EXTENSIONS}"
            DEPENDS ${MY_PYTHON} ${MY_VENV}/bin/glad
            COMMENT "Generating glad loader with glad2"
            VERBATIM
    )
endif ()
# glad通过depend触发python生成glad文件
add_custom_target(glad-gen
        DEPENDS ${GLAD_C_FILE} ${GLAD_H_FILE}
)
add_library(glad STATIC ${GLAD_GENERATED_DIR}/src/glad.c)
target_include_directories(glad PUBLIC ${GLAD_GENERATED_DIR}/include)
add_dependencies(glad glad-gen)
```

## 3 GLM的整合

```cmake
# 依赖FetchContent管理三方库
include(FetchContent)
# glm
FetchContent_Declare(
        glm
        GIT_REPOSITORY	https://github.com/g-truc/glm.git
        GIT_TAG 	    1.0.1
        GIT_PROGRESS TRUE
)
# 下载依赖的源码
FetchContent_MakeAvailable(glm)
# 启用glm中实验性质的模块
target_compile_definitions(glm INTERFACE GLM_ENABLE_EXPERIMENTAL)
```

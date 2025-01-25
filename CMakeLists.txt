cmake_minimum_required(VERSION 3.25)
project(hexo)

# 依赖node
find_program(node node)
if (NOT node)
    message(FATAL_ERROR "Could not find `node` in PATH")
endif ()

# 依赖hexo-cli
find_program(hexo hexo)
if (NOT hexo)
    message(FATAL_ERROR "Could not find `hexo` in PATH")
endif ()

# 系统检测 不同平台的home目录不相同
if (APPLE)
    # mac
    set(home "/Users/dingrui")
elseif (LINUX)
    # arch linux
    set(home "/home/dingrui")
else ()
    # windows wsl
    message(STATUS "注意当前系统平台类型为${CMAKE_SYSTEM_NAME}")
    if("Linux" STREQUAL ${CMAKE_SYSTEM_NAME})
        set(home "/home/dingrui")
    endif()
endif ()

set(hexo_dir "${home}/MyDev/doc/Bannirui.github.io")
# node modules
if (NOT EXISTS "${hexo_dir}/node_modules")
    message(FATAL_ERROR "博客项目根目录下执行`sudo npm install`")
endif ()

# 发布github pages的token
if (NOT DEFINED ENV{GITHUB_TOKEN_FOR_HEXO})
    message("没有在.zshrc中配置环境变量GITHUB_TOKEN_FOR_HEXO")
endif ()

# hexo的配置文件
if (NOT EXISTS "${hexo_dir}/_config.yml")
    execute_process(
            COMMAND ln -s ${home}/MyDev/env/dev-env-setting/hexo/config/_config.yml ${hexo_dir}/_config.yml
    )
else()
    execute_process(
            COMMAND ln -sf ${home}/MyDev/env/dev-env-setting/hexo/config/_config.yml ${hexo_dir}/_config.yml
    )
endif ()

# fluid主题的配置文件挂在根目录下
if (NOT EXISTS "${hexo_dir}/_config.fluid.yml")
    execute_process(
            COMMAND ln -s ${home}/MyDev/env/dev-env-setting/hexo/config/_config.fluid.yml ${hexo_dir}/_config.fluid.yml
    )
else()
    execute_process(
            COMMAND ln -s -f ${home}/MyDev/env/dev-env-setting/hexo/config/_config.fluid.yml ${hexo_dir}/_config.fluid.yml
    )
endif()

# next主题的配置文件 挂在 根目录下
if (NOT EXISTS "${hexo_dir}/_config.next.yml")
    execute_process(
            COMMAND ln -s ${home}/MyDev/env/dev-env-setting/hexo/config/_config.next.yml ${hexo_dir}/_config.next.yml
    )
else()
    execute_process(
            COMMAND ln -s -f ${home}/MyDev/env/dev-env-setting/hexo/config/_config.next.yml ${hexo_dir}/_config.next.yml
    )
endif ()
message(STATUS "hexo配置成功")
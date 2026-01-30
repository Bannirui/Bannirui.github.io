cmake_minimum_required(VERSION 3.21)
project(hexo LANGUAGES NONE)

# 输出详细日志
set(CMAKE_VERBOSE_MAKEFILE ON)

cmake_policy(SET CMP0135 NEW)

# dep
set(LIB_DIRECTORY ${CMAKE_SOURCE_DIR}/lib)
set(SITE_DIR ${CMAKE_SOURCE_DIR})

include(${LIB_DIRECTORY}/node.cmake)
include(${LIB_DIRECTORY}/hexo.cmake)

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

# 发布github pages的token
if (NOT DEFINED ENV{GITHUB_TOKEN_FOR_HEXO})
    message("没有在.zshrc中配置环境变量GITHUB_TOKEN_FOR_HEXO")
endif ()

set(HEXO_SETTING_DIR "/home/dingrui/MyDev/env/dev-env-setting")
# hexo的配置文件
if (NOT EXISTS "${SITE_DIR}/_config.yml")
    execute_process(
            COMMAND ln -s ${HEXO_SETTING_DIR}/hexo/config/_config.yml ${SITE_DIR}/_config.yml
    )
else()
    execute_process(
            COMMAND ln -sf ${HEXO_SETTING_DIR}/hexo/config/_config.yml ${SITE_DIR}/_config.yml
    )
endif ()

# fluid主题的配置文件挂在根目录下
if (NOT EXISTS "${SITE_DIR}/_config.fluid.yml")
    execute_process(
            COMMAND ln -s ${HEXO_SETTING_DIR}/hexo/config/_config.fluid.yml ${SITE_DIR}/_config.fluid.yml
    )
else()
    execute_process(
            COMMAND ln -s -f ${HEXO_SETTING_DIR}/hexo/config/_config.fluid.yml ${SITE_DIR}/_config.fluid.yml
    )
endif()

# next主题的配置文件 挂在 根目录下
if (NOT EXISTS "${SITE_DIR}/_config.next.yml")
    execute_process(
            COMMAND ln -s ${HEXO_SETTING_DIR}/hexo/config/_config.next.yml ${SITE_DIR}/_config.next.yml
    )
else()
    execute_process(
            COMMAND ln -s -f ${HEXO_SETTING_DIR}/hexo/config/_config.next.yml ${SITE_DIR}/_config.next.yml
    )
endif ()

message(STATUS "hexo配置成功")

set(PROXY_ENV
        HTTP_PROXY=http://127.0.0.1:7890
        HTTPS_PROXY=http://127.0.0.1:7890
        http_proxy=http://127.0.0.1:7890
        https_proxy=http://127.0.0.1:7890
        NO_PROXY=localhost,127.0.0.1
)

set(NODE_ENV
        ${CMAKE_COMMAND} -E env
        PATH=${NODE_DIR}/bin:$ENV{PATH}
        ${PROXY_ENV}
)

add_custom_target(npm_install
        COMMAND ${NODE_ENV} ${NPM_BIN} install
        WORKING_DIRECTORY ${SITE_DIR}
        COMMENT "Installing npm dependencies (isolated)"
        USES_TERMINAL
)

# hexo new post
add_custom_target(hexo_new
        COMMAND ${NODE_ENV} ${NPX_BIN} hexo new post test -p /RocksDB/test.md
        WORKING_DIRECTORY ${SITE_DIR}
        DEPENDS npm_install
        USES_TERMINAL
)

# hexo s
add_custom_target(hexo_server
        COMMAND ${NODE_ENV} ${NPX_BIN} hexo s
        WORKING_DIRECTORY ${SITE_DIR}
        DEPENDS npm_install
        USES_TERMINAL
)

# hexo g -d
add_custom_target(hexo_deploy
        COMMAND ${NODE_ENV} ${NPX_BIN} hexo g -d
        WORKING_DIRECTORY ${SITE_DIR}
        DEPENDS npm_install
        USES_TERMINAL
)
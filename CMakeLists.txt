cmake_minimum_required(VERSION 3.21)
project(hexo-blog LANGUAGES NONE)

# 输出详细日志
set(CMAKE_VERBOSE_MAKEFILE ON)

cmake_policy(SET CMP0135 NEW)

# dep
set(LIB_DIRECTORY ${CMAKE_SOURCE_DIR}/lib)
set(SITE_DIR ${CMAKE_SOURCE_DIR})

include(${LIB_DIRECTORY}/node.cmake)

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

# 创建符号链接的函数
function(create_symlink target_path source_path)
    if (NOT EXISTS ${target_path})
        execute_process(COMMAND ln -s ${source_path} ${target_path})
    else()
        execute_process(COMMAND ln -sf ${source_path} ${target_path})
    endif()
endfunction()

# 发布github pages的token
if (NOT DEFINED GITHUB_TOKEN_FOR_HEXO AND NOT DEFINED ENV{GITHUB_TOKEN_FOR_HEXO})
    message(FATAL_ERROR "没有在.zshrc中配置环境变量GITHUB_TOKEN_FOR_HEXO")
endif ()

set(HEXO_SETTING_DIR "${home}/MyEnv/dev-env-setting")
# hexo的配置文件
create_symlink("${SITE_DIR}/_config.yml" "${HEXO_SETTING_DIR}/hexo/config/_config.yml")
# fluid主题的配置文件挂在根目录下
create_symlink("${SITE_DIR}/_config.fluid.yml" "${HEXO_SETTING_DIR}/hexo/config/_config.fluid.yml")
# next主题的配置文件 挂在 根目录下
create_symlink("${SITE_DIR}/_config.next.yml" "${HEXO_SETTING_DIR}/hexo/config/_config.next.yml")

message(STATUS "hexo配置成功")

# 如果在本机上可以用127地址
# 如果在windows的wsl里面就要指定宿主机windows的地址
set(PROXY_ENV
        HTTP_PROXY=http://192.168.31.168:7890
        HTTPS_PROXY=http://192.168.31.168:7890
        http_proxy=http://192.168.31.168:7890
        https_proxy=http://192.168.31.168:7890
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

# 博客目录
set(POST_DIR "RocksDB")
# 博客文章名
set(POST_NAME "RocksDB源码-0x16-WriteThread串行执行器")
# hexo new post
add_custom_target(hexo_new
        COMMAND ${NODE_ENV} ${NPX_BIN} hexo new post ${POST_NAME} -p /${POST_DIR}/${POST_NAME}.md
        WORKING_DIRECTORY ${SITE_DIR}
        DEPENDS npm_install
        USES_TERMINAL
)

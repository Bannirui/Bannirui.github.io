# Ensure Node exists
if (NOT EXISTS ${NPM_BIN})
    message(FATAL_ERROR "npm not found, Node.js must be installed first")
endif ()

# Hexo project directory
set(HEXO_SITE_DIR ${SITE_DIR})
set(HEXO_NODE_MODULES ${HEXO_SITE_DIR}/node_modules)

# Install hexo-cli locally (idempotent)
add_custom_command(
        OUTPUT ${HEXO_NODE_MODULES}/hexo-cli
        COMMAND ${CMAKE_COMMAND} -E env
            PATH=${NODE_DIR}/bin:$ENV{PATH}
            ${NPM_BIN} install hexo-cli --save-dev
        WORKING_DIRECTORY ${HEXO_SITE_DIR}
        COMMENT "Installing hexo-cli locally"
)

add_custom_target(hexo_cli
        DEPENDS ${HEXO_NODE_MODULES}/hexo-cli
)

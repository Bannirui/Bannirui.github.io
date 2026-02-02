include(FetchContent)

set(NODE_VERSION v20.11.1)

if (APPLE)
        set(NODE_PLATFORM darwin-x64)
elseif (UNIX)
        set(NODE_PLATFORM linux-x64)
endif ()

FetchContent_Declare(
        nodejs
        URL https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${NODE_PLATFORM}.tar.xz
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)

FetchContent_MakeAvailable(nodejs)

# export
set(NODE_DIR ${nodejs_SOURCE_DIR})
set(NODE_BIN ${NODE_DIR}/bin/node)
set(NPM_BIN ${NODE_DIR}/bin/npm)
set(NPX_BIN ${NODE_DIR}/bin/npx)

message(STATUS "Using Node.js: ${NODE_BIN}")
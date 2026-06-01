#!/bin/bash -e
cmake -S ${SRC_DIR} -B build \
    -DCMAKE_INSTALL_PREFIX=${PREFIX}
cmake --build build --target install

# Patch config so find_package(cetmodules) includes modules loaded via FetchContent
cat >> "${PREFIX}/lib/cetmodules/cmake/cetmodulesConfig.cmake" <<'EOF'
include(CetProvideDependency)
include(CetCMakeEnv)
include(CetCMakeUtils)
include(CetCMakeConfig)
include(CetMake)
EOF

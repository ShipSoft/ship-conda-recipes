#!/bin/bash -e
cmake -S ${SRC_DIR} -B build \
    -DCMAKE_INSTALL_PREFIX=${PREFIX}
cmake --build build --target install

# Patch config so find_package(cetmodules) auto-loads modules consumers need at
# the top level (see FNALssi/cetmodules#38). CetCMakeUtils is intentionally not
# listed: CetCMakeConfig and CetMake already include() it under include_guard().
cat >> "${PREFIX}/share/cetmodules/cmake/cetmodulesConfig.cmake" <<'EOF'
include(CetProvideDependency)
include(CetCMakeEnv)
include(CetCMakeConfig)
include(CetMake)
EOF

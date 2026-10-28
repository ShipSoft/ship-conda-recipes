#!/bin/bash
set -euxo pipefail
mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build . -j${CPU_COUNT}
cmake --install .

# Compatibility symlink expected by downstream packages
ln -s "libpythia6${SHLIB_EXT}" "${PREFIX}/lib/libPythia6${SHLIB_EXT}"

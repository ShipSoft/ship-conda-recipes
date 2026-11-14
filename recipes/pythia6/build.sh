#!/bin/bash
set -euxo pipefail
mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build . -j${CPU_COUNT}
cmake --install .

# Compatibility symlink expected by downstream packages. macOS file systems
# are case-insensitive by default, so there libPythia6 already resolves to
# libpythia6 and a second entry would clash.
# shellcheck disable=SC2154  # target_platform is injected by the build environment
if [[ "${target_platform}" == linux-* ]]; then
    ln -s libpythia6.so "${PREFIX}/lib/libPythia6.so"
fi

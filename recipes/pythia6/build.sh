#!/bin/bash -e
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build . -j${CPU_COUNT}
cmake --install .

# Compatibility symlink expected by downstream packages
cp "${PREFIX}/lib/libpythia6.so" "${PREFIX}/lib/libPythia6.so"

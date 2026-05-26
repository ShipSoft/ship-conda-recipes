#!/bin/bash -e
mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DWITH_EXAMPLES=OFF \
    -DWITH_TEST=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POLICY_DEFAULT_CMP0074=NEW
cmake --build . -j${CPU_COUNT}
cmake --install .

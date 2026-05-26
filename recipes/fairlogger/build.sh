#!/bin/bash -e
mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=20 \
    -DDISABLE_COLOR=ON \
    -DUSE_EXTERNAL_FMT=ON \
    -DCMAKE_INSTALL_LIBDIR=lib
cmake --build . -j${CPU_COUNT}
cmake --install .

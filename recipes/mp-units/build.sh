#!/bin/bash -e
cmake ${CMAKE_ARGS} -S ${SRC_DIR}/src -B build \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DMP_UNITS_BUILD_CXX_MODULES=OFF
cmake --build build --parallel ${CPU_COUNT}
cmake --install build

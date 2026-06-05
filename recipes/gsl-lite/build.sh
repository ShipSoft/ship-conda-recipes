#!/bin/bash -e
cmake ${CMAKE_ARGS} -S ${SRC_DIR} -B build \
    -DCMAKE_INSTALL_LIBDIR=lib
cmake --build build --parallel ${CPU_COUNT}
cmake --install build

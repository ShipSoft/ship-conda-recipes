#!/bin/bash
set -euxo pipefail
cmake ${CMAKE_ARGS} -S ${SRC_DIR} -B build \
    -DCMAKE_CXX_STANDARD=23 \
    -DCMAKE_INSTALL_LIBDIR=lib
cmake --build build --parallel ${CPU_COUNT}
cmake --install build

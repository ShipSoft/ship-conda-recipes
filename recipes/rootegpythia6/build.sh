#!/bin/bash
set -euxo pipefail
mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DROOTEGPythia6_Pythia6_BUILTIN=OFF \
    -DPYTHIA6_LIB_DIR=${PREFIX}/lib \
    -DCMAKE_INSTALL_LIBDIR=lib
cmake --build . -j${CPU_COUNT}
cmake --install .

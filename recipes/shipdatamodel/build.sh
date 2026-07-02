#!/bin/bash
set -euxo pipefail
# shellcheck disable=SC2154  # root_cxx_standard is injected by the build environment
cmake ${CMAKE_ARGS} -S ${SRC_DIR} -B build \
    -DCMAKE_CXX_STANDARD=${root_cxx_standard} \
    -DCMAKE_INSTALL_LIBDIR=lib
cmake --build build --parallel ${CPU_COUNT}
cmake --install build

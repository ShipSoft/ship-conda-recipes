#!/bin/bash
set -euxo pipefail
mkdir -p build && cd build
# shellcheck disable=SC2154  # root_cxx_standard is injected by the build environment
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=${root_cxx_standard} \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_POLICY_DEFAULT_CMP0074=NEW \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_TESTING=OFF
cmake --build . -j${CPU_COUNT}
cmake --install .

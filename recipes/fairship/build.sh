#!/bin/bash
set -euxo pipefail
unset SIMPATH
export FAIRROOTPATH="${PREFIX}"
export ROOT_INCLUDE_PATH="${PREFIX}/include:${PREFIX}/include/geant4vmc:${PREFIX}/include/Geant4:${PREFIX}/include/vmc"

mkdir -p build && cd build
# shellcheck disable=SC2154  # root_cxx_standard is injected by the build environment
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=${root_cxx_standard} \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    "-DCMAKE_CXX_FLAGS=-isystem ${PREFIX}/include/geant4vmc -isystem ${PREFIX}/include/Geant4"
cmake --build . -j${CPU_COUNT}
cmake --install .

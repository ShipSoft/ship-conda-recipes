#!/bin/bash -e
unset SIMPATH
export FAIRROOTPATH="${PREFIX}"
export ROOT_INCLUDE_PATH="${PREFIX}/include:${PREFIX}/include/geant4vmc:${PREFIX}/include/Geant4:${PREFIX}/include/vmc"

mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DGeant4VMC_DIR="${PREFIX}/lib/Geant4VMC-6.7.1" \
    "-DCMAKE_CXX_FLAGS=-isystem ${PREFIX}/include/geant4vmc -isystem ${PREFIX}/include/Geant4"
cmake --build . -j${CPU_COUNT}
cmake --install .

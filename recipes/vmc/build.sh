#!/bin/bash -e
mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_POLICY_DEFAULT_CMP0074=NEW \
    -DCMAKE_CXX_STANDARD=20
cmake --build . -j${CPU_COUNT}
cmake --install .

# Backward compatibility symlink
cd "${PREFIX}/lib"
ln -sf libVMCLibrary.so libVMC.so

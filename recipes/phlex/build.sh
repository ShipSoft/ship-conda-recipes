#!/bin/bash -e
cmake ${CMAKE_ARGS} -S ${SRC_DIR} -B build \
    -DCMAKE_CXX_STANDARD=23 \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=CetProvideDependency \
    -DPHLEX_USE_FORM=ON \
    -DBUILD_TESTING=OFF \
    -DENABLE_CLANG_TIDY=OFF
cmake --build build --parallel ${CPU_COUNT}
cmake --install build

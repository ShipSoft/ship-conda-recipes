#!/bin/bash -e
cmake ${CMAKE_ARGS} -S ${SRC_DIR} -B build \
    -DCMAKE_BUILD_TYPE=Release
cmake --build build --target install

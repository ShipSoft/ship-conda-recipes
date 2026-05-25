#!/bin/bash -e

# Patch CMakeLists.txt to pass bare header names to ROOT_GENERATE_DICTIONARY
# instead of absolute paths, avoiding runtime errors when the source dir is gone.
sed -i 's|${CMAKE_CURRENT_SOURCE_DIR}/[^/]*/include/||g' "${SRC_DIR}/CMakeLists.txt"

cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_POLICY_DEFAULT_CMP0074=NEW \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_TESTING=OFF
cmake --build . -j${CPU_COUNT}
cmake --install .

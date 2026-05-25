#!/bin/bash -e

# Patch CMakeLists.txt to pass bare header names to ROOT_GENERATE_DICTIONARY
# instead of absolute paths, avoiding runtime errors when the source dir is gone.
sed -i \
  -e 's|${CMAKE_CURRENT_LIST_DIR}/inc/\(.*\.h\)|\1|g' \
  -e '/^ROOT_GENERATE_DICTIONARY/i include_directories(${CMAKE_CURRENT_LIST_DIR}/inc)' \
  "${SRC_DIR}/CMakeLists.txt"

cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DROOTEGPythia6_Pythia6_BUILTIN=ON \
    -DCMAKE_INSTALL_LIBDIR=lib
cmake --build . -j${CPU_COUNT}
cmake --install .

#!/bin/bash -e
unset SIMPATH

mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_CXX_FLAGS="-fPIC -O2" \
    -DCMAKE_CATCH_DISCOVER_TESTS_DISCOVERY_MODE=PRE_TEST \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DBUILD_BASEMQ=OFF \
    -DBUILD_EXAMPLES=ON \
    -DPythia6_LIBRARY_DIR="${PREFIX}/lib"
cmake --build . -j${CPU_COUNT}
cmake --install .

# Work around hardcoded paths in PCM
for DIR in source sink field event sim steer; do
  ln -nfs ../include "${PREFIX}/include/${DIR}"
done

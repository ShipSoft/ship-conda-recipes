#!/bin/bash
set -euxo pipefail
# Header-only; the compiler only builds and runs the sequence test.
# conda's clang doesn't activate for a noarch build on macOS, so CMAKE_ARGS
# is unset there and CMake uses the system compiler for the test. Fall back
# to the prefix settings CMAKE_ARGS would carry, so CMake finds Random123 and
# installs into $PREFIX.
CMAKE_ARGS="${CMAKE_ARGS:--DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_PREFIX_PATH=${PREFIX}}"
cmake ${CMAKE_ARGS} -S ${SRC_DIR} -B build \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DSHIPRANDOM_BUILD_TESTS=ON
cmake --build build --parallel ${CPU_COUNT}
ctest --test-dir build --output-on-failure
cmake --install build

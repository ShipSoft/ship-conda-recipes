#!/bin/bash
set -euxo pipefail
# Header-only; the compiler only builds and runs the sequence test.
# conda's clang doesn't activate for a noarch build on macOS, so CMAKE_ARGS
# may be unset there; CMake then uses the system compiler for the test.
cmake ${CMAKE_ARGS:-} -S ${SRC_DIR} -B build \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DSHIPRANDOM_BUILD_TESTS=ON
cmake --build build --parallel ${CPU_COUNT}
ctest --test-dir build --output-on-failure
cmake --install build

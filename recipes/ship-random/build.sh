#!/bin/bash
set -euxo pipefail
# Header-only; the compiler only builds and runs the sequence test.
if [[ -n "${CMAKE_ARGS:-}" ]]; then
    build_tests=ON
else
    # conda's clang doesn't activate for a noarch build on macOS, so there
    # is no conda compiler (and no CMAKE_ARGS). The sequence test runs on the
    # Linux builds of this noarch package; here only install the headers.
    CMAKE_ARGS="-DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_PREFIX_PATH=${PREFIX}"
    build_tests=OFF
fi
cmake ${CMAKE_ARGS} -S ${SRC_DIR} -B build \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DSHIPRANDOM_BUILD_TESTS=${build_tests}
cmake --build build --parallel ${CPU_COUNT}
if [[ "${build_tests}" == ON ]]; then
    ctest --test-dir build --output-on-failure
fi
cmake --install build

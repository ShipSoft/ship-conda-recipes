#!/bin/bash
set -euxo pipefail

# Permit the legacy Fortran sources (non-conforming argument types and BOZ
# constants) under modern gfortran.
FFLAGS="-fallow-argument-mismatch -fallow-invalid-boz -fno-tree-loop-distribute-patterns"

mkdir -p build && cd build
# shellcheck disable=SC2154  # root_cxx_standard is injected by the build environment
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=${root_cxx_standard} \
    -DCMAKE_SKIP_RPATH=TRUE \
    -DCMAKE_POLICY_DEFAULT_CMP0074=NEW \
    -DCMAKE_C_FLAGS="${CFLAGS} -std=gnu17" \
    ${FFLAGS:+-DCMAKE_Fortran_FLAGS="${FFLAGS}"}
cmake --build . -j${CPU_COUNT}
cmake --install .

# Ensure both lib and lib64 work
if [ ! -d "${PREFIX}/lib64" ]; then
    ln -sf lib "${PREFIX}/lib64"
fi

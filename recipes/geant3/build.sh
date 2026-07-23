#!/bin/bash
set -euxo pipefail

# gfortran >= 10 rejects the legacy Fortran sources (non-conforming
# argument types and BOZ constants) by default.
FVERSION=$(gfortran --version | grep -i fortran | sed -e 's/.* //' | cut -d. -f1)
FFLAGS=""
if [ "${FVERSION}" -ge 10 ]; then
    FFLAGS="-fallow-argument-mismatch -fallow-invalid-boz -fno-tree-loop-distribute-patterns"
fi

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

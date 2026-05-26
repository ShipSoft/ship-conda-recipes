#!/bin/bash -e

# Detect gfortran version for compatibility flags
FVERSION=$(gfortran --version | grep -i fortran | sed -e 's/.* //' | cut -d. -f1)
FFLAGS=""
if [ "${FVERSION}" -ge 10 ]; then
    FFLAGS="-fallow-argument-mismatch -fallow-invalid-boz -fno-tree-loop-distribute-patterns"
fi

mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=20 \
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

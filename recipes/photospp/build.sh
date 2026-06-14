#!/bin/bash
set -euxo pipefail
mkdir -p build && cd build
cp -a "${SRC_DIR}/." .

# Permit the legacy Fortran sources (non-conforming argument types and
# BOZ constants) under modern gfortran.
export FFLAGS="${FFLAGS} -fallow-argument-mismatch -fallow-invalid-boz"

autoreconf -ifv
./configure \
    --prefix=${PREFIX} \
    --with-hepmc3=${PREFIX} \
    --without-hepmc \
    --with-pythia8=${PREFIX} \
    --with-tauola=${PREFIX}

# Make symlink creation idempotent across re-runs, and propagate the
# Fortran flags into the bundled tauola-fortran sub-build.
find . \( -name makefile -o -name Makefile \) -exec sed -i 's/@ln -s /@ln -sf /g' {} + 2>/dev/null || true
if [ -f tauola-fortran/make.inc ]; then
    sed -i "s/^F77FLAGS.*/F77FLAGS = -fPIC -fno-automatic -fno-backslash -ffixed-line-length-132 -fallow-argument-mismatch -fallow-invalid-boz/" tauola-fortran/make.inc
fi
mkdir -p lib

make -j${CPU_COUNT}
make install

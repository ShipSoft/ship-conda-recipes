#!/bin/bash
set -euxo pipefail

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
find . \( -name makefile -o -name Makefile \) -exec sed -i 's/@ln -s /@ln -sf /g' {} +
if [ -f tauola-fortran/make.inc ]; then
    sed -i "s|^F77FLAGS.*|F77FLAGS = ${FFLAGS} -fPIC -fno-automatic -fno-backslash -ffixed-line-length-132|" tauola-fortran/make.inc
fi
mkdir -p lib

# The top-level Makefile archives with a bare `ar`, which only works where the
# host happens to have binutils; use the conda toolchain's instead.
sed -i 's/^\tar cr /\t$(AR) cr /' Makefile
make -j${CPU_COUNT} AR="${AR}"
make install

#!/bin/bash -e
mkdir -p build && cd build
rsync -a ${SRC_DIR}/ .

export FFLAGS="${FFLAGS} -fallow-argument-mismatch -fallow-invalid-boz"

autoreconf -ifv
./configure \
    --prefix=${PREFIX} \
    --with-hepmc3=${PREFIX} \
    --without-hepmc \
    --with-pythia8=${PREFIX} \
    --with-tauola=${PREFIX}

# Fix ln -s calls and inject Fortran flags (same issues as tauolapp)
find . \( -name makefile -o -name Makefile \) -exec sed -i 's/@ln -s /@ln -sf /g' {} + 2>/dev/null || true
if [ -f tauola-fortran/make.inc ]; then
    sed -i "s/^F77FLAGS.*/F77FLAGS = -fPIC -fno-automatic -fno-backslash -ffixed-line-length-132 -fallow-argument-mismatch -fallow-invalid-boz/" tauola-fortran/make.inc
fi
mkdir -p lib

make -j1
make install

#!/bin/bash -e
mkdir -p build && cd build
rsync -a ${SRC_DIR}/ .

export FFLAGS="${FFLAGS} -fallow-argument-mismatch -fallow-invalid-boz"

./configure \
    --prefix=${PREFIX} \
    --with-hepmc3=${PREFIX} \
    --without-hepmc \
    --with-pythia8=${PREFIX}

# Fix ln -s calls that fail if file already exists
find . -name makefile -exec sed -i 's/@ln -s /@ln -sf /g' {} +
# Inject Fortran compatibility flags
sed -i "s/^F77FLAGS.*/F77FLAGS = -fPIC -fno-automatic -fno-backslash -ffixed-line-length-132 -fallow-argument-mismatch -fallow-invalid-boz/" tauola-fortran/make.inc

# Ensure lib dir exists (Makefile assumes it)
mkdir -p lib
# Build without parallel make — tauola-fortran has race conditions in its makefile
make -j1
make install DESTDIR= PREFIX=${PREFIX} LIBDIR=${PREFIX}/lib

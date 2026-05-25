#!/bin/bash -e
cd ${SRC_DIR}

autoreconf -ifv
F77=gfortran ./configure \
    --prefix=${PREFIX} \
    --with-hepmc3=${PREFIX} \
    --without-hepmc \
    --with-pythia8=${PREFIX} \
    --with-tauola=${PREFIX}
make -j${CPU_COUNT}
make install

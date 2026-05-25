#!/bin/bash -e
cd ${SRC_DIR}

F77=gfortran ./configure \
    --prefix=${PREFIX} \
    --with-hepmc3=${PREFIX} \
    --without-hepmc \
    --with-pythia8=${PREFIX}
make -j${CPU_COUNT}
make install DESTDIR= PREFIX=${PREFIX} LIBDIR=${PREFIX}/lib

#!/bin/bash -e
# Restore dummy PDFLIB subroutines (renamed to *X in this fork).
# The real ones come from PDFLIB which we don't use; without the dummies,
# the symbols are undefined and dlopen fails (conda-forge uses BIND_NOW).
sed -i -e 's/SUBROUTINE PDFSETX/SUBROUTINE PDFSET/' \
       -e 's/SUBROUTINE STRUCTPX/SUBROUTINE STRUCTP/' \
       -e 's/SUBROUTINE STRUCTMX/SUBROUTINE STRUCTM/' "${SRC_DIR}/pythia-6.4.28.f"

mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build . -j${CPU_COUNT}
cmake --install .

# Compatibility symlink expected by downstream packages
cp "${PREFIX}/lib/libpythia6.so" "${PREFIX}/lib/libPythia6.so"

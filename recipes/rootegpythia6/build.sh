#!/bin/bash
set -euxo pipefail
mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DROOTEGPythia6_Pythia6_BUILTIN=OFF \
    -DPYTHIA6_LIB_DIR=${PREFIX}/lib \
    -DCMAKE_INSTALL_LIBDIR=lib
cmake --build . -j${CPU_COUNT}
cmake --install .

# Fix rootmap content: upstream's ROOT_GENERATE_DICTIONARY(TPythia6 ...)
# emits libTPythia6.so as the library tag, but the library is libEGPythia6.so.
# Patch the tag and rename the rootmap file for clarity (ROOT scans *.rootmap
# by content, so the filename is cosmetic).
sed -i 's/libTPythia6\.so/libEGPythia6.so/' "${PREFIX}/lib/libTPythia6.rootmap"
mv "${PREFIX}/lib/libTPythia6.rootmap" "${PREFIX}/lib/libEGPythia6.rootmap"

# Do NOT rename libTPythia6_rdict.pcm: ROOT_GENERATE_DICTIONARY(TPythia6 ...)
# bakes the literal filename libTPythia6_rdict.pcm into libEGPythia6.so's
# dictionary registration. TCling::LoadPCM looks it up by the dictionary
# name (TPythia6), not the library name (EGPythia6).

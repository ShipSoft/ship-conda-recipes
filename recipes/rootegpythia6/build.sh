#!/bin/bash -e
mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DROOTEGPythia6_Pythia6_BUILTIN=OFF \
    -DPYTHIA6_LIB_DIR=${PREFIX}/lib \
    -DCMAKE_INSTALL_LIBDIR=lib
cmake --build . -j${CPU_COUNT}
cmake --install .

# Fix rootmap: dictionary is named TPythia6 but library is EGPythia6
# (upstream bug — contribute fix, keep this patch until merged)
sed -i 's/libTPythia6\.so/libEGPythia6.so/' "${PREFIX}/lib/libTPythia6.rootmap"
mv "${PREFIX}/lib/libTPythia6.rootmap" "${PREFIX}/lib/libEGPythia6.rootmap"
mv "${PREFIX}/lib/libTPythia6_rdict.pcm" "${PREFIX}/lib/libEGPythia6_rdict.pcm"

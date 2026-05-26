#!/bin/bash -e
mkdir -p build && cd build
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=20 \
    -DGeant4VMC_USE_VGM=ON \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_POLICY_DEFAULT_CMP0074=NEW
cmake --build . -j${CPU_COUNT}
cmake --install .

# Create convenience symlink for examples
G4VMC_SHARE=$(cd "${PREFIX}/share" && echo Geant4VMC-* | cut -d' ' -f1)
ln -nfs "${G4VMC_SHARE}/examples" "${PREFIX}/share/examples"

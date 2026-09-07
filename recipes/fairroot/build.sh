#!/bin/bash
set -euxo pipefail
unset SIMPATH

mkdir -p build && cd build
# CMAKE_REQUIRE_FIND_PACKAGE_Geant4: geant4 is a deliberate host dep, but
# FairRoot only warns when it is missing and silently drops simulation
# support, so a Geant4Config that fails to load (e.g. an unsatisfiable
# find_dependency) would otherwise ship a degraded package. Make it fatal.
# shellcheck disable=SC2154  # root_cxx_standard is injected by the build environment
cmake ${CMAKE_ARGS} ${SRC_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=${root_cxx_standard} \
    -DCMAKE_CXX_FLAGS="-fPIC -O2" \
    -DCMAKE_CATCH_DISCOVER_TESTS_DISCOVERY_MODE=PRE_TEST \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_REQUIRE_FIND_PACKAGE_Geant4=ON \
    -DBUILD_BASEMQ=OFF \
    -DBUILD_EXAMPLES=ON \
    -DPythia6_LIBRARY_DIR="${PREFIX}/lib"
cmake --build . -j${CPU_COUNT}
cmake --install .

# The dictionary PCMs record headers under their source-module directories
# (e.g. field/FairField.h) while the headers install flat into include/;
# symlink the module names back onto include/ so cling resolves them.
for DIR in source sink field event sim steer; do
  ln -nfs ../include "${PREFIX}/include/${DIR}"
done

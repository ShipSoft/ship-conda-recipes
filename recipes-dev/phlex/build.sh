#!/bin/bash -e
# Kept identical to the conda-forge phlex-feedstock build.sh, except that the
# feedstock also installs conda activation scripts setting PHLEX_PLUGIN_PATH;
# the SHiP repos set that in their own activate.sh.
# shellcheck disable=SC2154  # root_cxx_standard is injected by the build environment
cmake ${CMAKE_ARGS} -S ${SRC_DIR} -B build --preset default \
    -DCMAKE_CXX_STANDARD=${root_cxx_standard} \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DBUILD_TESTING=OFF \
    -DENABLE_CLANG_TIDY=OFF \
    -DFORM_USE_RNTUPLE_STORAGE=ON
cmake --build build --parallel ${CPU_COUNT}
cmake --install build

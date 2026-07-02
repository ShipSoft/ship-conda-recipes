#!/bin/bash
set -euxo pipefail

# shellcheck disable=SC2154  # root_cxx_standard is injected by the build environment
cmake ${CMAKE_ARGS} -S "${SRC_DIR}" -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_CXX_STANDARD=${root_cxx_standard} \
    -DACTS_USE_SYSTEM_LIBS=ON \
    -DACTS_BUILD_EXAMPLES=ON \
    -DACTS_BUILD_EXAMPLES_PYTHON_BINDINGS=ON \
    -DACTS_BUILD_EXAMPLES_ROOT=ON

cmake --build build --parallel ${CPU_COUNT}
cmake --install build

# Upstream hardcodes the Python install dir to ${PREFIX}/python/acts.
# Drop a .pth in site-packages so `import acts` works without setting
# PYTHONPATH; the .so's embedded $ORIGIN/../../lib rpath still resolves
# correctly because we leave the install layout in place.
PY_SITE="${SP_DIR}"
mkdir -p "${PY_SITE}"
echo '../../../python' > "${PY_SITE}/acts.pth"

#!/bin/bash
set -euxo pipefail

# shellcheck disable=SC2154  # root_cxx_standard is injected by the build environment
cmake ${CMAKE_ARGS} -S "${SRC_DIR}" -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_CXX_STANDARD=${root_cxx_standard} \
    -DPython_EXECUTABLE="${PYTHON}" \
    -DACTS_USE_SYSTEM_LIBS=ON \
    -DACTS_BUILD_EXAMPLES=ON \
    -DACTS_BUILD_EXAMPLES_ROOT=OFF \
    -DACTS_BUILD_PLUGIN_ROOT=ON \
    -DACTS_BUILD_PYTHON_BINDINGS=ON

cmake --build build --parallel ${CPU_COUNT}
cmake --install build

PY_SITE="${SP_DIR}"

if [ -d "${PREFIX}/python/acts" ]; then
    mkdir -p "${PY_SITE}/acts"
    cp -r "${PREFIX}/python/acts/"* "${PY_SITE}/acts/"
    rm -rf "${PREFIX}/python"
fi

# Add the Python extension modules that the install step did not place
# itself. Only *.cpython-*.so: the libActs*.so shared libraries are already
# installed into lib/ and must not be duplicated into site-packages.
find build/ -type f -name "*.cpython-*.so" -print0 | while IFS= read -r -d '' so; do
    if [ -z "$(find "${PY_SITE}/acts" -name "$(basename "${so}")" -print -quit)" ]; then
        cp "${so}" "${PY_SITE}/acts/"
    fi
done

if [ ! -d "${PY_SITE}/acts" ] || [ -z "$(ls -A "${PY_SITE}/acts")" ]; then
    echo "ERROR: 'acts' package directory is empty or missing in site-packages!" >&2
    exit 1
fi

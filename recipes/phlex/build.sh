#!/bin/bash -e
# shellcheck disable=SC2154  # root_cxx_standard and build_platform are injected by the build environment
if [[ "${build_platform}" != "${target_platform}" ]]; then
    # Under CMP0190 (set NEW by cetmodules' cmake_minimum_required),
    # FindPython runs the target interpreter through the cross-compiling
    # emulator. cross-python has already replaced $PREFIX/bin/python with a
    # build-machine shim, so a pass-through emulator is enough. The shim
    # reports the build env's numpy headers, which CMAKE_FIND_ROOT_PATH
    # rejects, so point FindPython at the host numpy directly.
    CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_CROSSCOMPILING_EMULATOR=env -DPython_EXECUTABLE=${PREFIX}/bin/python"
    CMAKE_ARGS="${CMAKE_ARGS} -DPython_NumPy_INCLUDE_DIR=${SP_DIR}/numpy/_core/include"
fi
cmake ${CMAKE_ARGS} -S ${SRC_DIR} -B build --preset default \
    -DCMAKE_CXX_STANDARD=${root_cxx_standard} \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DBUILD_TESTING=OFF \
    -DENABLE_CLANG_TIDY=OFF \
    -DFORM_USE_RNTUPLE_STORAGE=ON
cmake --build build --parallel ${CPU_COUNT}
cmake --install build

# Install conda activation scripts so PHLEX_PLUGIN_PATH points at the plugin libdir.
for CHANGE in activate deactivate; do
    mkdir -p "${PREFIX}/etc/conda/${CHANGE}.d"
    for EXT in sh csh fish; do
        cp "${RECIPE_DIR}/${CHANGE}.${EXT}" \
           "${PREFIX}/etc/conda/${CHANGE}.d/${PKG_NAME}_${CHANGE}.${EXT}"
    done
done

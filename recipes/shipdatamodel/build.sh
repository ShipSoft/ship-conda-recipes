#!/bin/bash
set -euxo pipefail
# shellcheck disable=SC2154  # root_cxx_standard is injected by the build environment
cmake ${CMAKE_ARGS} -S ${SRC_DIR} -B build \
    -DCMAKE_CXX_STANDARD=${root_cxx_standard} \
    -DCMAKE_INSTALL_LIBDIR=lib
cmake --build build --parallel ${CPU_COUNT}
ctest_args=()
# shellcheck disable=SC2154  # target_platform is injected by the build environment
if [[ "${target_platform}" == osx-* ]]; then
    # The committed schema snapshot spells std::int64_t as long (Linux); macOS
    # has long long, so EventHeader's checksum differs. ShipSoft/data-model#63.
    ctest_args+=(--exclude-regex '^schema_snapshot$')
fi
ctest --test-dir build --output-on-failure --parallel ${CPU_COUNT} "${ctest_args[@]}"
cmake --install build

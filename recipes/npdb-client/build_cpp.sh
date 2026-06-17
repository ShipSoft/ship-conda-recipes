#!/usr/bin/env bash
set -euxo pipefail

export CARGO_NET_RETRY=10
export CARGO_HTTP_TIMEOUT=120

cd "${SRC_DIR}/npdb-client"

cmake ${CMAKE_ARGS} -S . -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_INSTALL_LIBDIR=lib
cmake --build build --parallel "${CPU_COUNT}"
cmake --install build

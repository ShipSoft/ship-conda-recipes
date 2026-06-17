#!/usr/bin/env bash
set -euxo pipefail

export CARGO_NET_RETRY=10
export CARGO_HTTP_TIMEOUT=120

cd "${SRC_DIR}/npdb-client"

cmake ${CMAKE_ARGS} -S . -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_INSTALL_LIBDIR=lib
# Build only the library target. Upstream's CMakeLists.txt also defines
# an `example_client` executable whose C++ link embeds the Rust static
# lib but doesn't wire in -lpthread, so it fails with undefined
# references to pthread_*. We're packaging the library, not the
# example, and there is no install(TARGETS example_client ...) rule.
cmake --build build --target npdb_client_bridge --parallel "${CPU_COUNT}"
cmake --install build

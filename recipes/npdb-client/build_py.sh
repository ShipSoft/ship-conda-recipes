#!/usr/bin/env bash
set -euxo pipefail

export CARGO_NET_RETRY=10
export CARGO_HTTP_TIMEOUT=120

cd "${SRC_DIR}/npdb-client"

"${PYTHON}" -m pip install . \
    --no-deps \
    --no-build-isolation \
    -vv

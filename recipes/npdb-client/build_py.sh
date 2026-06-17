#!/usr/bin/env bash
set -euxo pipefail

cd "${SRC_DIR}/npdb-client"

"${PYTHON}" -m pip install . \
    --no-deps \
    --no-build-isolation \
    -vv

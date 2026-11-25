#!/bin/bash
# Build recipes-manual/root, one rattler-build run per variant file.
#
# ROOT is too big for the GitHub runners, so this runs on a large build
# machine: `pixi run build-root [variant files...]`. Without arguments it
# builds every linux-64 variant. Packages land in output/ (or $OUTPUT_DIR);
# upload the root_base and root packages to prefix.dev/ship-experiment/stable
# afterwards (not the noarch root_cxx_standard, see the README).
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
recipe="$repo/recipes-manual/root"
output="${OUTPUT_DIR:-$repo/output}"

if [ "$#" -eq 0 ]; then
    set -- "$recipe"/variants/linux-64_*.yaml
fi

for variant in "$@"; do
    echo "=== building $(basename "$variant")"
    # The ship channel comes first so the host env takes our pythia8.
    rattler-build build \
        --recipe "$recipe" \
        --variant-config "$variant" \
        --output-dir "$output" \
        --skip-existing=all \
        --channel https://prefix.dev/ship-experiment/stable \
        --channel conda-forge
done

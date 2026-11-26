#!/bin/bash
# Build recipes-manual/root, one rattler-build run per variant file.
#
# ROOT is too big for the GitHub runners, so this runs on a large linux-64
# build machine: `pixi run build-root [variant files...]`. Without arguments it
# builds every variant under variants/. linux-aarch64 variants are
# cross-compiled; their tests need qemu-user registered with binfmt_misc and
# QEMU_LD_PREFIX pointing at an aarch64 glibc sysroot, e.g. the
# aarch64-conda-linux-gnu/sysroot directory of an extracted
# sysroot_linux-aarch64 package. Packages land in output/
# (or $OUTPUT_DIR); upload the root_base and root packages to
# prefix.dev/ship-experiment/stable afterwards (not the noarch
# root_cxx_standard, see the README).
#
# EXTRA_CHANNEL: a channel searched before the ship channel, e.g. a local
#   file:// channel with a clangdev build that conda-forge doesn't have yet.
# NO_TEST=1: skip the tests (e.g. cross builds without qemu).
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
recipe="$repo/recipes-manual/root"
output="${OUTPUT_DIR:-$repo/output}"

if [ "$#" -eq 0 ]; then
    set -- "$recipe"/variants/*.yaml
fi

extra_args=()
if [ -n "${EXTRA_CHANNEL:-}" ]; then
    extra_args+=(--channel "$EXTRA_CHANNEL")
fi
if [ "${NO_TEST:-0}" = 1 ]; then
    extra_args+=(--test skip)
fi

for variant in "$@"; do
    name=$(basename "$variant" .yaml)
    # Variant files are named <target platform>_py<x.y>_cxx<std>.yaml.
    target=${name%%_*}
    platform_args=()
    if [ "$target" != linux-64 ]; then
        platform_args=(--target-platform "$target" --build-platform linux-64)
        # qemu-user looks for the target's dynamic loader under
        # QEMU_LD_PREFIX, so the tests need a target glibc sysroot there.
        if [ "${NO_TEST:-0}" != 1 ] && [ -z "${QEMU_LD_PREFIX:-}" ]; then
            echo "error: $name: set QEMU_LD_PREFIX to a $target sysroot (or NO_TEST=1)" >&2
            exit 1
        fi
    fi
    echo "=== building $name"
    # The ship channel comes first so the host env takes our pythia8.
    rattler-build build \
        --recipe "$recipe" \
        --variant-config "$variant" \
        --output-dir "$output" \
        --skip-existing=all \
        "${platform_args[@]}" \
        "${extra_args[@]}" \
        --channel https://prefix.dev/ship-experiment/stable \
        --channel conda-forge
done

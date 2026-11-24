#!/usr/bin/env bash
set -euo pipefail

# Patch an upstream (conda-forge) package in place inside a consumer's pixi
# environment: build a source checkout of it incrementally with the
# environment's own compilers and dependencies, install it over the released
# package, and put the released package back afterwards. See the Developer
# Guide (SHiP Documentation site), "Patching an upstream package".
#
# conda-forge links with DT_RPATH, which the dynamic loader searches before
# LD_LIBRARY_PATH, so a build in a separate prefix is not picked up by
# binaries from the environment. Installing into the prefix is what works.
#
# The source must be at the same version as the installed package (plus your
# patch): the other packages in the environment were built against its
# released ABI.
#
# Usage:
#   overlay.sh configure <consumer> <src> [-e ENV] [-t "TOOL ..."] [-- CMAKE_ARGS...]
#   overlay.sh build     <consumer> <src> [-e ENV]
#   overlay.sh install   <consumer> <src> <package> [-e ENV]
#   overlay.sh restore   <consumer> <package> [-e ENV]
#   overlay.sh status    <consumer> [-e ENV]
#
# <consumer> is the checkout whose pixi environment is patched (e.g. ../aegir),
# <src> the upstream source checkout. The build directory is <src>-overlay-build.
# -t names build-only tools the consumer environment lacks (e.g. "cetmodules
# pkg-config"); they come from a cached `pixi exec` environment and are added
# to PATH and CMAKE_PREFIX_PATH. CMAKE_ARGS should mirror the feedstock's
# build script.

die() {
    echo "error: $*" >&2
    exit 1
}
usage() {
    sed -n '/^# Usage:/,/^# build script\./p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
}

[[ $# -ge 2 ]] || usage
cmd=$1
consumer=$(realpath "$2")
shift 2
[[ -f "$consumer/pixi.toml" ]] || die "$consumer has no pixi.toml"

src=
pkg=
case $cmd in
configure | build)
    [[ $# -ge 1 ]] || usage
    src=$(realpath "$1")
    shift
    ;;
install)
    [[ $# -ge 2 ]] || usage
    src=$(realpath "$1")
    pkg=$2
    shift 2
    ;;
restore)
    [[ $# -ge 1 ]] || usage
    pkg=$1
    shift
    ;;
status) ;;
*) usage ;;
esac

env=default
tools=
cmake_args=()
while [[ $# -gt 0 ]]; do
    case $1 in
    -e)
        env=$2
        shift 2
        ;;
    -t)
        tools=$2
        shift 2
        ;;
    --)
        shift
        cmake_args=("$@")
        break
        ;;
    *) usage ;;
    esac
done

# Run a command inside the consumer environment.
in_env() {
    pixi run -q --manifest-path "$consumer/pixi.toml" -e "$env" "$@"
}
prefix=$(in_env bash -c 'echo "$CONDA_PREFIX"')
[[ -d "$prefix/conda-meta" ]] || die "could not locate the '$env' environment of $consumer"
# Outside conda-meta/: rattler reads every *.json file there as a package record.
marker_dir="$prefix/.ship-overlay"
build_dir="${src:+$src-overlay-build}"

# Check that the build directory is configured for this environment, so that
# a build configured for one consumer is never installed (and recorded) as
# an overlay of another.
check_configured() {
    [[ -f "$build_dir/CMakeCache.txt" ]] || die "$build_dir is not configured; run 'configure' first"
    local configured
    configured=$(sed -n 's/^CMAKE_INSTALL_PREFIX:[A-Z]*=//p' "$build_dir/CMakeCache.txt")
    [[ "$configured" == "$prefix" ]] ||
        die "$build_dir is configured for $configured, not $prefix; run 'configure' again for this environment"
}

# Run a command in the consumer environment with the -t tools of the
# configure step on PATH, so that build and install find them too.
in_build_env() {
    local aux=
    [[ -f "$build_dir/.overlay-aux" ]] && aux=$(<"$build_dir/.overlay-aux")
    # shellcheck disable=SC2016  # expanded inside the environment
    in_env bash -c '[[ -n "$1" ]] && export PATH="$PATH:$1/bin"; shift; "$@"' overlay "$aux" "$@"
}

case $cmd in
configure)
    aux=
    if [[ -n "$tools" ]]; then
        specs=()
        for t in $tools; do specs+=(-s "$t"); done
        aux=$(pixi exec "${specs[@]}" -- bash -c 'echo "$CONDA_PREFIX"')
    fi
    # $CMAKE_ARGS is set by the conda compiler activation (toolchain, sysroot,
    # install prefix); the feedstock build scripts start from it as well.
    # shellcheck disable=SC2016  # expanded inside the environment
    in_env bash -c '
        aux=$1 src=$2 build=$3
        shift 3
        if [[ -n "$aux" ]]; then
            export PATH="$PATH:$aux/bin"
            prefix_path="$CONDA_PREFIX;$aux"
        else
            prefix_path="$CONDA_PREFIX"
        fi
        # shellcheck disable=SC2086  # CMAKE_ARGS is a word list
        cmake -S "$src" -B "$build" -G Ninja $CMAKE_ARGS \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" \
            -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_PREFIX_PATH="$prefix_path" \
            "$@"
    ' overlay "$aux" "$src" "$build_dir" "${cmake_args[@]}"
    printf '%s' "$aux" >"$build_dir/.overlay-aux"
    ;;
build)
    check_configured
    in_build_env cmake --build "$build_dir"
    ;;
install)
    check_configured
    installed=$(pixi list --manifest-path "$consumer/pixi.toml" -e "$env" "$pkg" 2>/dev/null |
        awk -v p="$pkg" '$1 == p {print $2; exit}')
    [[ -n "$installed" ]] || die "$pkg is not installed in the '$env' environment of $consumer"
    described=$(git -C "$src" describe --tags --always --dirty 2>/dev/null || echo unknown)
    if [[ "$described" != *"$installed"* ]]; then
        echo "warning: $src is at '$described' but the environment has $pkg $installed;" >&2
        echo "         check out the matching tag, or ABI mismatches may crash at run time" >&2
    fi
    # Record the overlay before touching the prefix: cmake --install doesn't
    # roll back, so a failed install still leaves something to restore.
    mkdir -p "$marker_dir/$pkg"
    write_info() {
        printf 'source=%s\nrevision=%s\nreleased=%s\ndate=%s\nstate=%s\n' \
            "$src" "$described" "$installed" "$(date -Iseconds)" "$1" >"$marker_dir/$pkg/info"
    }
    write_info installing
    # cmake --install replaces files rather than writing into them, so files
    # hardlinked from the shared package cache stay intact. Don't use cp here.
    if ! in_build_env cmake --install "$build_dir"; then
        echo "error: install failed; $prefix may hold a mix of released and overlay files." >&2
        echo "       Put the released package back with: overlay.sh restore $consumer $pkg -e $env" >&2
        exit 1
    fi
    # Keep the union over repeated installs, so that restore also removes
    # files that only an earlier build installed.
    manifest="$marker_dir/$pkg/install_manifest.txt"
    { [[ -f "$manifest" ]] && cat "$manifest"; cat "$build_dir/install_manifest.txt"; echo; } |
        sed '/^$/d' | sort -u >"$manifest.new"
    mv "$manifest.new" "$manifest"
    write_info installed
    echo "$pkg overlaid on $prefix ($described over $installed)."
    echo "pixi list still shows the released build. Undo with: overlay.sh restore $consumer $pkg -e $env"
    ;;
restore)
    [[ -f "$marker_dir/$pkg/info" ]] || die "no overlay of $pkg recorded in $prefix"
    # Remove everything the source build installed (it may have added files
    # the package doesn't ship), then let pixi re-link the released package.
    if [[ -f "$marker_dir/$pkg/install_manifest.txt" ]]; then
        # CMake doesn't end the manifest with a newline; read the last line too.
        while IFS= read -r f || [[ -n "$f" ]]; do
            case $f in
            "$prefix"/*) rm -f -- "$f" ;;
            *) echo "warning: skipping $f (outside $prefix)" >&2 ;;
            esac
        done <"$marker_dir/$pkg/install_manifest.txt"
    else
        echo "warning: the first install of $pkg failed, so there is no list of the files it added;" >&2
        echo "         files the released package doesn't ship may remain in $prefix" >&2
    fi
    pixi reinstall --manifest-path "$consumer/pixi.toml" -e "$env" "$pkg"
    rm -rf "${marker_dir:?}/$pkg"
    rmdir "$marker_dir" 2>/dev/null || true
    echo "$pkg restored to the released build in $prefix."
    ;;
status)
    if [[ ! -d "$marker_dir" ]] || [[ -z "$(ls -A "$marker_dir")" ]]; then
        echo "No overlays in $prefix."
        exit 0
    fi
    for d in "$marker_dir"/*/; do
        echo "$(basename "$d"):"
        sed 's/^/  /' "$d/info"
    done
    ;;
esac

#!/bin/bash
set -euo pipefail

# Build the phlex conda package from an upstream PR (or any git ref) into the
# local dev channel ../ship-local-channel, where downstream dev environments
# (e.g. aegir's dev environment) resolve it ahead of conda-forge. See the
# Developer Guide (SHiP Documentation site), "Testing dependency PRs".
#
# Usage:
#   pixi run build-phlex-pr <pr-number|branch|tag|sha>

REPO=Framework-R-D/phlex
CHANNEL_DIR=../ship-local-channel

if [[ $# -ne 1 ]]; then
    echo "usage: build-phlex-pr <pr-number|branch|tag|sha>" >&2
    exit 2
fi
ref=$1

if [[ "$ref" =~ ^[0-9]+$ ]]; then
    # PR number: resolve to the PR head commit.
    sha=$(gh api "repos/$REPO/pulls/$ref" --jq .head.sha 2>/dev/null) ||
        sha=$(git ls-remote "https://github.com/$REPO.git" "refs/pull/$ref/head" | cut -f1)
else
    # Branch or tag; fall back to treating the argument as a commit SHA.
    sha=$(git ls-remote "https://github.com/$REPO.git" "$ref" | head -n1 | cut -f1)
    [[ -n "$sha" ]] || sha=$ref
fi
if [[ -z "$sha" ]]; then
    echo "error: could not resolve '$ref' in $REPO" >&2
    exit 1
fi
echo "Building phlex at $sha (from '$ref')"

# Render the dev recipe with the resolved revision; the recipe itself stays
# a diffable twin of the conda-forge feedstock recipe.
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cp recipes-dev/phlex/* "$tmpdir/"
sed -i "s|^  git_rev: .*|  git_rev: $sha|" "$tmpdir/recipe.yaml"

rattler-build build \
    --recipe "$tmpdir/recipe.yaml" \
    --output-dir "$CHANNEL_DIR" \
    --channel conda-forge

cat <<EOF

phlex $sha built into $CHANNEL_DIR.
To consume it in a downstream checkout (e.g. aegir), enable the dev
environment (see the commented block in its pixi.toml), which resolves
$CHANNEL_DIR ahead of the remote channels, then:

    pixi update phlex   # or: pixi lock
    pixi run -e dev build

Discard the resulting pixi.toml/pixi.lock changes when done.
EOF

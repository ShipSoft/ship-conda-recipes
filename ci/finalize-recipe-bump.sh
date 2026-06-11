#!/usr/bin/env bash
# Refresh sha256 in a rattler-build recipe after Renovate bumps
# context.version. The recipes use a single context.version field that holds
# the upstream tag form (e.g. "2-2", "6-8") and a source URL templated as
# .../v${{ version }}.tar.gz; the dotted package.version is derived via Jinja
# in the recipe itself, so this script does not touch the version line.
#
# Usage: ci/finalize-recipe-bump.sh path/to/recipe.yaml [more.yaml ...]
#
# Idempotent: re-running on an already-correct file is a no-op.
set -euo pipefail

for recipe in "$@"; do
  if [ ! -f "$recipe" ]; then
    echo "skip: $recipe (not a file)" >&2
    continue
  fi

  version=$(grep -E '^[[:space:]]+version:[[:space:]]*"' "$recipe" \
            | head -1 \
            | sed -E 's/^[[:space:]]+version:[[:space:]]*"([^"]+)".*/\1/')
  if [ -z "$version" ]; then
    echo "skip: $recipe (no context.version field)" >&2
    continue
  fi

  url_template=$(grep -E '^[[:space:]]+url:[[:space:]]*http' "$recipe" \
                 | head -1 \
                 | sed -E 's/^[[:space:]]+url:[[:space:]]*//')
  url=$(echo "$url_template" \
        | sed -E "s|\\\$\\{\\{[[:space:]]*version[[:space:]]*\\}\\}|$version|g")

  echo "[$recipe] version=$version" >&2
  echo "[$recipe] url=$url" >&2

  new_sha=$(curl -fsSL "$url" | sha256sum | cut -d' ' -f1)

  sed -i -E "s|^([[:space:]]+sha256:[[:space:]]*)[a-f0-9]+|\\1$new_sha|" "$recipe"

  echo "[$recipe] sha256=$new_sha" >&2
done

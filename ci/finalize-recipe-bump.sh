#!/usr/bin/env bash
# Refresh sha256 and derive context.version after a tag bump in a rattler-build
# recipe that uses the context.{version, tag} pattern (HEP-style upstream tags
# like v6-8, v6-7-p1).
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

  tag=$(grep -E '^[[:space:]]+tag:[[:space:]]*"' "$recipe" \
        | head -1 \
        | sed -E 's/^[[:space:]]+tag:[[:space:]]*"([^"]+)".*/\1/')
  if [ -z "$tag" ]; then
    echo "skip: $recipe (no context.tag field — not a HEP-tag recipe)" >&2
    continue
  fi

  url_template=$(grep -E '^[[:space:]]+url:[[:space:]]*http' "$recipe" \
                 | head -1 \
                 | sed -E 's/^[[:space:]]+url:[[:space:]]*//')
  url=$(echo "$url_template" \
        | sed -E "s|\\\$\\{\\{[[:space:]]*tag[[:space:]]*\\}\\}|$tag|g")

  echo "[$recipe] tag=$tag" >&2
  echo "[$recipe] url=$url" >&2

  new_sha=$(curl -fsSL "$url" | sha256sum | cut -d' ' -f1)
  new_version=$(echo "$tag" | sed -E 's/^v//; s/-p([0-9]+)/.\1/g; s/-/./g')

  sed -i -E "s|^([[:space:]]+sha256:[[:space:]]*)[a-f0-9]+|\\1$new_sha|" "$recipe"
  sed -i -E "/^[[:space:]]+version:[[:space:]]/s|\"[^\"]+\"|\"$new_version\"|" "$recipe"

  echo "[$recipe] sha256=$new_sha version=$new_version" >&2
done

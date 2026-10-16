#!/usr/bin/env bash
# Refresh the sha256 values in a rattler-build recipe after Renovate bumps
# context.version. The source URLs are taken from `rattler-build --render-only`
# rather than by substituting the version textually, so templated tag forms
# (`v${{ version | replace(".", "-") }}`, `${{ tag }}`, ...) resolve exactly as
# they do in a real build. Multi-source recipes are handled as long as every
# url source carries a sha256: the n-th `sha256:` line in the file is matched
# to the n-th rendered url source.
#
# Needs rattler-build and jq on PATH.
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
  dir=$(dirname "$recipe")

  variant_args=()
  if [ -f "$dir/variants.yaml" ]; then
    variant_args=(-m "$dir/variants.yaml")
  fi

  # Rendered url sources in recipe order, deduplicated across variants and
  # outputs (staging caches repeat the top-level sources).
  rendered=$(rattler-build build --render-only --recipe "$dir" "${variant_args[@]}")
  mapfile -t urls < <(
    jq -r '[.[] | .recipe | (.staging_caches[]?.source[]?, .source[]?)
                | select(type == "object" and has("url") and has("sha256")) | .url]
               | reduce .[] as $u ([]; if any(.[]; . == $u) then . else . + [$u] end)
               | .[]' <<< "$rendered"
  )
  if [ ${#urls[@]} -eq 0 ]; then
    echo "skip: $recipe (no url source with sha256)" >&2
    continue
  fi

  sha_count=$(grep -cE '^[[:space:]]+(- )?sha256:[[:space:]]*[a-f0-9]{64}' "$recipe" || true)
  if [ "$sha_count" -ne ${#urls[@]} ]; then
    echo "error: $recipe has $sha_count sha256 lines but ${#urls[@]} url sources;" \
         "refresh it manually" >&2
    exit 1
  fi

  for i in "${!urls[@]}"; do
    url=${urls[$i]}
    new_sha=$(curl -fsSL --retry 3 "$url" | sha256sum | cut -d' ' -f1)
    # Replace the (i+1)-th sha256 value in the file.
    awk -v n=$((i + 1)) -v sha="$new_sha" '
      /^[[:space:]]+(- )?sha256:[[:space:]]*[a-f0-9]{64}/ && ++seen == n {
        sub(/[a-f0-9]{64}/, sha)
      }
      { print }
    ' "$recipe" > "$recipe.tmp"
    mv "$recipe.tmp" "$recipe"
    echo "[$recipe] $url sha256=$new_sha" >&2
  done
done

#!/bin/bash
# Output all packages from deps.json in topological (build) order.
#
# Usage: ci/build-order.sh
# Output: one package name per line, in build order
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEPS_FILE="${SCRIPT_DIR}/deps.json"

# Parse deps.json with only shell + grep (no python/jq required)
declare -A DEPS
declare -A RDEPS
ALL_PKGS=()

while IFS= read -r line; do
  pkg=$(echo "$line" | grep -oP '^\s*"\K[^"]+')
  [ -z "$pkg" ] && continue
  ALL_PKGS+=("$pkg")
  dep_list=$(echo "$line" | grep -oP '\[.*\]' | tr -d '[]" ' )
  DEPS[$pkg]="$dep_list"
  IFS=',' read -ra dep_arr <<< "$dep_list"
  for dep in "${dep_arr[@]}"; do
    [ -z "$dep" ] && continue
    RDEPS[$dep]="${RDEPS[$dep]:-}${RDEPS[$dep]:+,}$pkg"
  done
done < <(grep '".*":' "$DEPS_FILE")

# Topological sort (Kahn's algorithm) over all packages
declare -A IN_DEGREE
for pkg in "${ALL_PKGS[@]}"; do
  IN_DEGREE[$pkg]=0
done
for pkg in "${ALL_PKGS[@]}"; do
  IFS=',' read -ra deps <<< "${DEPS[$pkg]:-}"
  for dep in "${deps[@]}"; do
    [ -z "$dep" ] && continue
    IN_DEGREE[$pkg]=$(( ${IN_DEGREE[$pkg]} + 1 ))
  done
done

sorted=()
while [ ${#sorted[@]} -lt ${#ALL_PKGS[@]} ]; do
  found=0
  for pkg in "${ALL_PKGS[@]}"; do
    # Skip already sorted
    for s in "${sorted[@]+"${sorted[@]}"}"; do
      [ "$s" = "$pkg" ] && continue 2
    done
    if [ "${IN_DEGREE[$pkg]}" -eq 0 ]; then
      sorted+=("$pkg")
      IFS=',' read -ra dependents <<< "${RDEPS[$pkg]:-}"
      for dep in "${dependents[@]}"; do
        [ -z "$dep" ] && continue
        IN_DEGREE[$dep]=$(( ${IN_DEGREE[$dep]} - 1 ))
      done
      found=1
    fi
  done
  if [ "$found" -eq 0 ]; then
    echo "ERROR: circular dependency detected" >&2
    exit 1
  fi
done

for pkg in "${sorted[@]}"; do
  echo "$pkg"
done

#!/bin/bash
# Given a list of changed recipe dirs, compute the full set of packages to
# rebuild (changed + downstream dependents) in topological order.
#
# Usage: ci/build-order.sh <changed_recipe> [<changed_recipe> ...]
# Example: ci/build-order.sh vmc fairlogger
# Output: one package name per line, in build order
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEPS_FILE="${SCRIPT_DIR}/deps.json"

if [ $# -eq 0 ]; then
  echo "Usage: $0 <changed_recipe> [...]" >&2
  exit 1
fi

# Parse deps.json with only shell + grep (no python/jq guaranteed)
# Build adjacency list: for each package, find what depends on it (reverse deps)
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

# BFS from changed packages through reverse deps to find all affected
declare -A TO_BUILD
queue=("$@")
while [ ${#queue[@]} -gt 0 ]; do
  current="${queue[0]}"
  queue=("${queue[@]:1}")
  [ -n "${TO_BUILD[$current]:-}" ] && continue
  TO_BUILD[$current]=1
  IFS=',' read -ra dependents <<< "${RDEPS[$current]:-}"
  for dep in "${dependents[@]}"; do
    [ -z "$dep" ] && continue
    [ -z "${TO_BUILD[$dep]:-}" ] && queue+=("$dep")
  done
done

# Topological sort (Kahn's algorithm) over the affected set
declare -A IN_DEGREE
for pkg in "${!TO_BUILD[@]}"; do
  IN_DEGREE[$pkg]=0
done
for pkg in "${!TO_BUILD[@]}"; do
  IFS=',' read -ra deps <<< "${DEPS[$pkg]:-}"
  for dep in "${deps[@]}"; do
    [ -z "$dep" ] && continue
    [ -n "${TO_BUILD[$dep]:-}" ] && IN_DEGREE[$pkg]=$(( ${IN_DEGREE[$pkg]} + 1 ))
  done
done

sorted=()
while [ ${#sorted[@]} -lt ${#TO_BUILD[@]} ]; do
  found=0
  for pkg in "${!TO_BUILD[@]}"; do
    # Skip already sorted
    for s in "${sorted[@]+"${sorted[@]}"}"; do
      [ "$s" = "$pkg" ] && continue 2
    done
    if [ "${IN_DEGREE[$pkg]}" -eq 0 ]; then
      sorted+=("$pkg")
      # Decrease in-degree of dependents
      IFS=',' read -ra dependents <<< "${RDEPS[$pkg]:-}"
      for dep in "${dependents[@]}"; do
        [ -z "$dep" ] && continue
        [ -n "${TO_BUILD[$dep]:-}" ] && IN_DEGREE[$dep]=$(( ${IN_DEGREE[$dep]} - 1 ))
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

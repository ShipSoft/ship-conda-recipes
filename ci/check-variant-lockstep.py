#!/usr/bin/env python3
"""Check that ROOT-linking recipes agree on the ``root_base`` variant pin.

Most recipes here hold ``root_base`` at a value this repo chooses, declared in
their ``variants.yaml`` and advanced in lockstep (see "ROOT C++ standard
variants" in the README). A recipe that another pinning recipe links against,
but which leaves ``root_base`` to float, breaks the lockstep as soon as
conda-forge moves ROOT, and the two halves of the break land in different
drift PRs:

* rebuilt on its own, it pins conda-forge's current ROOT and the host env of
  every pinning consumer stops solving. Strict channel priority makes that
  fatal: once the local output channel holds the package, the compatible
  builds on the ship channel are excluded.
* left unrebuilt while the lockstep advances, it keeps the old pin and the
  solver reaches past it to whatever ancient build in the channel carries a
  loose enough ROOT dependency, typically one whose ``run_exports`` predate
  the current recipe. The consumer then builds green and ships without the
  library at runtime.

rootegpythia6 hit both halves at once (PRs #169 and #170). This check is what
catches that at review time, offline and without touching the channel.

The recipe/variants parsing is deliberately regex-based and stdlib-only so the
hook runs in the lint environment; ci/check-channel-drift.py parses the same
files the same way but needs py-rattler, so the two cannot share a module.

Usage: python ci/check-variant-lockstep.py [recipes-dir]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Variant keys held in lockstep across recipes. A key listed here must be
# pinned by every recipe that (a) is linked by a pinning recipe and (b) names
# the key's package in its own host: block.
LOCKSTEP_KEYS = ("root_base",)


def read_variants(path: Path) -> dict[str, list[str]]:
    """Parse a variants.yaml into ``key -> [value, ...]``."""
    out: dict[str, list[str]] = {}
    key = None
    for line in path.read_text().splitlines():
        m = re.match(r"^([A-Za-z0-9._-]+):\s*$", line)
        if m:
            key = m.group(1)
            out.setdefault(key, [])
            continue
        m = re.match(r"^\s+-\s*(.+?)\s*$", line)
        if m and key:
            out[key].append(m.group(1).strip("\"'"))
    return out


def pinned(recipe: Path, key: str) -> str | None:
    """The single value ``recipe`` holds ``key`` at, or None if it is free.

    A key carrying several values is a build matrix (root_cxx_standard), not a
    pin, so it does not participate in the lockstep.
    """
    variants = recipe.parent / "variants.yaml"
    if not variants.is_file():
        return None
    values = read_variants(variants).get(key, [])
    return values[0] if len(values) == 1 else None


def output_names(recipe: Path) -> set[str]:
    """Every package name a recipe publishes."""
    return {
        m.group(1)
        for m in (
            re.match(r"^\s*name:\s*([A-Za-z0-9._-]+)\s*$", line)
            for line in recipe.read_text().splitlines()
        )
        if m
    }


def host_deps(recipe: Path) -> set[str]:
    """Dependency names appearing in any ``host:`` block of a recipe.

    Multi-output recipes have one block per output; they are pooled, since the
    lockstep applies to the recipe as a whole (one variants.yaml covers all
    outputs). ``if:``/``then:`` branches are included: a conditional host dep
    constrains the variant matrix just as an unconditional one does.
    """
    deps: set[str] = set()
    indent = None
    for line in recipe.read_text().splitlines():
        if indent is None:
            m = re.match(r"^(\s*)host:\s*$", line)
            if m:
                indent = len(m.group(1))
            continue
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if len(line) - len(line.lstrip()) <= indent:
            indent = None
            m = re.match(r"^(\s*)host:\s*$", line)
            if m:
                indent = len(m.group(1))
            continue
        m = re.match(r"^\s*-\s*(?:if:.*|then:.*)?$", line)
        if m:
            continue
        m = re.match(r"^\s*-\s*([A-Za-z0-9._-]+)", line)
        if m:
            deps.add(m.group(1))
    return deps


def check(recipes_dir: Path) -> list[str]:
    recipes = sorted(recipes_dir.glob("*/recipe.yaml"))
    provider = {name: r for r in recipes for name in output_names(r)}
    hosts = {r: host_deps(r) for r in recipes}

    problems: list[str] = []
    for key in LOCKSTEP_KEYS:
        for recipe in recipes:
            value = pinned(recipe, key)
            if value is None:
                continue
            for dep in sorted(hosts[recipe]):
                target = provider.get(dep)
                if target is None or target == recipe:
                    continue
                if key not in hosts[target]:
                    continue
                dep_value = pinned(target, key)
                if dep_value is None:
                    problems.append(
                        f"{target.parent.name}: links {key} and is a host dependency of "
                        f"{recipe.parent.name} (which pins {key} {value}), so it must pin "
                        f"{key} in its own variants.yaml"
                    )
                elif dep_value != value:
                    problems.append(
                        f"{target.parent.name}: pins {key} {dep_value} but its consumer "
                        f"{recipe.parent.name} pins {key} {value}; bump them in lockstep"
                    )
    return sorted(set(problems))


def main(argv: list[str]) -> int:
    recipes_dir = Path(argv[1]) if len(argv) > 1 else Path("recipes")
    problems = check(recipes_dir)
    for problem in problems:
        print(f"error: {problem}", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

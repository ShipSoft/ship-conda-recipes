#!/usr/bin/env python3
"""Detect ship-channel packages whose conda-forge pins have gone stale.

For every package published to the prefix.dev/ship channel we look at the
build the solver would actually pick (highest version, then highest build
number) and inspect its ``depends`` entries. When a dependency carries an
upper version bound (a ``<`` / ``<=`` from an upstream ``run_exports`` pin)
and the *current* conda-forge release of that dependency has moved past the
bound, the ship build is stale: a fresh rebuild would pin a newer range, so
the package needs rebuilding to stay co-installable with freshly built
siblings (e.g. in the dev-source workflows).

This catches drift that the binary dev-build signal misses: a free ``*``
solve simply co-selects the older, mutually-compatible builds and stays
green, hiding the fact that the channel has fallen behind conda-forge.

Modes:
  (default)         print a report; exit 1 if any drift is found.
  --bump-recipes    additionally bump ``build.number`` for every affected
                    single-output recipe so a rebuild PR can be opened;
                    multi-output recipes are listed for manual handling.
                    Exits 0 so the caller can open the PR.
  --pr-body PATH    write the markdown report (used as the PR body) to PATH.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

from rattler import Version

SHIP_REPODATA = "https://prefix.dev/ship/{subdir}/repodata.json"
CONDA_FORGE_CHANNELDATA = "https://conda.anaconda.org/conda-forge/channeldata.json"
SUBDIRS = ("linux-64", "noarch")
RECIPES_DIR = Path("recipes")

# (package, dependency) pairs to ignore, for deliberate pins that lag
# conda-forge on purpose. Keep this small and documented.
IGNORE: set[tuple[str, str]] = set()

# Dependency names to skip for ALL packages: ABI-marker packages that are
# exact-pinned transitively (not "kept current"), so conda-forge publishing a
# newer marker does NOT mean a rebuild helps. eigen-abi is pinned by
# geomodel-core's baked eigen run_export (conda-forge geomodel-core is still on
# eigen-abi 5.0.1.80 while conda-forge ships 5.0.1.100); it only advances when
# conda-forge rebuilds geomodel-core against the newer eigen-abi — never on a
# SHiP rebuild — so flagging it here is pure noise.
IGNORE_DEPS: set[str] = {"eigen-abi"}


# --- conda version ordering (delegated to rattler) --------------------------

def vcmp(a: str, b: str) -> int:
    """Compare two conda version strings, returning -1/0/1.

    Delegates to ``rattler.Version`` — the same conda ``VersionOrder``
    implementation pixi and rattler-build use — so epoch/local/dev/post
    ordering matches the solver exactly (a dev release sorts below its final
    release, a post release above it), including odd repodata versions like
    ``0.0.0.dev20260729+c457825``.
    """
    va, vb = Version(a), Version(b)
    return (va > vb) - (va < vb)


# --- matchspec upper bound --------------------------------------------------

def upper_bound(constraint: str):
    """Return (op, version) for the '<'/'<=' bound in a constraint, or None."""
    for part in constraint.split(","):
        part = part.strip()
        if part.startswith("<="):
            return "<=", part[2:].strip()
        if part.startswith("<"):
            return "<", part[1:].strip()
    return None


def exceeds(latest: str, op: str, bound: str) -> bool:
    c = vcmp(latest, bound)
    return c >= 0 if op == "<" else c > 0


# --- data fetching ----------------------------------------------------------

def fetch_json(url: str):
    # prefix.dev rejects the default urllib User-Agent with 403.
    req = urllib.request.Request(url, headers={"User-Agent": "ship-channel-drift/1"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.load(resp)


def _rank_cmp(a: dict, b: dict) -> int:
    """Order two records by version, then build_number (solver preference)."""
    order = vcmp(a["version"], b["version"])
    if order:
        return order
    an, bn = a.get("build_number", 0), b.get("build_number", 0)
    return (an > bn) - (an < bn)


def latest_builds() -> tuple[dict[str, list[dict]], list[str]]:
    """name -> the records the solver could pick (all tied at max version/build).

    Returns ``(picked, failed)`` where ``failed`` lists any subdir whose
    repodata could not be fetched; callers must not report a clean no-drift
    result while sources are missing.
    """
    picked: dict[str, list[dict]] = {}
    failed: list[str] = []
    for subdir in SUBDIRS:
        try:
            repodata = fetch_json(SHIP_REPODATA.format(subdir=subdir))
        except Exception as exc:  # noqa: BLE001 - transient / network / 403
            print(f"error: could not fetch {subdir} repodata: {exc}", file=sys.stderr)
            failed.append(subdir)
            continue
        records = {**repodata.get("packages", {}), **repodata.get("packages.conda", {})}
        for rec in records.values():
            name = rec["name"]
            variants = picked.setdefault(name, [])
            if not variants:
                variants.append(rec)
                continue
            order = _rank_cmp(rec, variants[0])
            if order > 0:  # strictly higher — supersede all retained ties
                variants[:] = [rec]
            elif order == 0 and all(
                v.get("build") != rec.get("build") for v in variants
            ):  # tie on version+build_number — retain distinct build strings
                variants.append(rec)
    return picked, failed


def conda_forge_versions() -> dict[str, str]:
    data = fetch_json(CONDA_FORGE_CHANNELDATA)
    return {name: meta.get("version") for name, meta in data.get("packages", {}).items()}


# --- recipe mapping / build-number bump -------------------------------------

def recipe_name_map() -> dict[str, Path]:
    """package/output name -> recipe.yaml path (for rebuild bumps)."""
    mapping: dict[str, Path] = {}
    for recipe in sorted(RECIPES_DIR.glob("*/recipe.yaml")):
        for line in recipe.read_text().splitlines():
            m = re.match(r"^\s*name:\s*([A-Za-z0-9._-]+)\s*$", line)
            if m:
                mapping.setdefault(m.group(1), recipe)
    return mapping


def is_multi_output(recipe: Path) -> bool:
    return any(re.match(r"^outputs:", ln) for ln in recipe.read_text().splitlines())


def bump_build_number(recipe: Path) -> int | None:
    """Increment the single top-level build.number; return the new value."""
    lines = recipe.read_text().splitlines(keepends=True)
    in_build = False
    for i, line in enumerate(lines):
        body = line.rstrip("\n")
        if re.match(r"^build:\s*$", body):
            in_build = True
            continue
        if in_build:
            if body and not body.startswith((" ", "\t")):
                in_build = False  # left the build block
                continue
            m = re.match(r"^(\s*)number:\s*(\d+)\s*$", body)
            if m:
                new = int(m.group(2)) + 1
                lines[i] = f"{m.group(1)}number: {new}\n"
                recipe.write_text("".join(lines))
                return new
    return None


# --- main -------------------------------------------------------------------

def detect(ship: dict[str, list[dict]], cf: dict[str, str]) -> list[tuple]:
    rows = []
    for name, variants in sorted(ship.items()):
        for rec in variants:
            for dep in rec.get("depends", []):
                tokens = dep.split()
                dep_name = tokens[0]
                if dep_name in IGNORE_DEPS or (name, dep_name) in IGNORE:
                    continue
                constraint = tokens[1] if len(tokens) > 1 else ""
                ub = upper_bound(constraint)
                if not ub:
                    continue
                latest = cf.get(dep_name)
                if not latest:  # not a conda-forge package (e.g. another ship pkg)
                    continue
                op, bound = ub
                if exceeds(latest, op, bound):
                    rows.append((name, rec, dep_name, constraint, latest))
    return rows


def render(rows: list[tuple]) -> str:
    lines = ["# Channel drift check", ""]
    if not rows:
        lines.append("No stale conda-forge pins found in the ship channel. ✅")
        return "\n".join(lines) + "\n"
    pkgs = sorted({name for name, *_ in rows})
    lines += [
        f"Found **{len(rows)}** stale pin(s) across **{len(pkgs)}** ship package(s). "
        "conda-forge has moved past these ranges; rebuild (bump `build.number`) to "
        "refresh the pins and keep the packages co-installable with fresh source builds.",
        "",
        "| Ship build | Dependency | Pinned range | conda-forge latest |",
        "|------------|------------|--------------|--------------------|",
    ]
    for name, rec, dep, constraint, latest in rows:
        build = f"{name} {rec['version']} `{rec.get('build', rec.get('build_number', 0))}`"
        lines.append(f"| {build} | {dep} | `{constraint}` | {latest} |")
    return "\n".join(lines) + "\n"


def bump_affected(rows: list[tuple]) -> str:
    """Bump build numbers for affected single-output recipes; return a summary."""
    names = sorted({name for name, *_ in rows})
    mapping = recipe_name_map()
    bumped, manual, unknown = [], [], []
    for name in names:
        recipe = mapping.get(name)
        if recipe is None:
            unknown.append(name)
        elif is_multi_output(recipe):
            manual.append((name, recipe.parent.name))
        else:
            new = bump_build_number(recipe)
            if new is None:
                manual.append((name, recipe.parent.name))
            else:
                bumped.append((name, recipe.parent.name, new))

    out = ["", "## Rebuild actions", ""]
    if bumped:
        out.append("Bumped `build.number` (rebuilds on merge):")
        out += [f"- `{r}` → build {n} ({p})" for p, r, n in bumped]
        out.append("")
    if manual:
        out.append("Needs manual rebuild (multi-output recipe):")
        out += [f"- `{p}` (recipe `{r}`)" for p, r in manual]
        out.append("")
    if unknown:
        out.append("No recipe in this repo (rebuilt elsewhere / transitive):")
        out += [f"- `{p}`" for p in unknown]
        out.append("")
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bump-recipes", action="store_true",
                    help="bump build.number for affected single-output recipes")
    ap.add_argument("--pr-body", type=Path, help="write the markdown report to this path")
    args = ap.parse_args()

    ship, failed = latest_builds()
    if failed:
        print(
            f"error: could not fetch ship repodata for: {', '.join(failed)}; "
            "refusing to certify no-drift on partial data",
            file=sys.stderr,
        )
        return 2

    cf = conda_forge_versions()
    rows = detect(ship, cf)

    report = render(rows)
    if rows and args.bump_recipes:
        report += bump_affected(rows)

    print(report)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        Path(summary).write_text(report, encoding="utf-8")
    if args.pr_body:
        args.pr_body.write_text(report, encoding="utf-8")

    if args.bump_recipes:
        return 0
    return 1 if rows else 0


if __name__ == "__main__":
    raise SystemExit(main())

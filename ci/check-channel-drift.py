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

Some pins are ours, not conda-forge's: a dependency named by a recipe's
``variants.yaml`` is held at a value we choose, so a rebuild reproduces the
same pin and only a lockstep bump of every ``variants.yaml`` advances it.
Those are reported separately and never trigger a ``build.number`` bump.

Modes:
  (default)         print a report; exit 1 if any drift is found.
  --bump-recipes    additionally bump ``build.number`` once per affected
                    recipe so a rebuild PR can be opened. Recipes flagged only
                    for variant-pinned deps are skipped; a recipe whose
                    top-level ``build.number`` cannot be incremented in place
                    (e.g. it is templated) is listed for manual handling.
                    Exits 0 so the caller can open the PR.
  --bump-variants   rewrite variant pins that conda-forge has moved past, in
                    every recipe declaring them, so a lockstep-bump PR can be
                    opened. All-or-nothing per pin. Exits 0.
  --pr-body PATH    write the markdown report (used as the PR body) to PATH.
"""

from __future__ import annotations

import argparse
import functools
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


def _read_variants(path: Path) -> dict[str, list[str]]:
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


@functools.lru_cache(maxsize=None)
def variant_pinned_deps(recipe: Path) -> frozenset[str]:
    """Dependency names this recipe pins in its own variants.yaml.

    conda-forge moving past such a pin does not make the published build
    stale in a way a rebuild fixes: the rebuild reproduces the same pin.
    """
    variants = recipe.parent / "variants.yaml"
    if not variants.is_file():
        return frozenset()
    return frozenset(_read_variants(variants))


def variant_pins() -> tuple[dict[str, tuple[str, list[Path]]], dict[str, dict[str, list[Path]]]]:
    """Return ``(pins, inconsistent)`` across every recipe's variants.yaml.

    ``pins`` maps a variant key that carries exactly one value in every recipe
    declaring it to ``(value, recipes)`` — a deliberate pin we can advance.
    A key with more than one value anywhere is a build matrix (root_cxx_standard,
    genie_hadronization), not a pin, and is excluded everywhere.

    ``inconsistent`` maps a single-valued key whose recipes disagree on the
    value to ``{value: recipes}``. That is a half-finished lockstep bump, not
    something to bump again, so it is reported rather than acted on.
    """
    values: dict[str, dict[str, list[Path]]] = {}
    matrix: set[str] = set()
    for recipe in sorted(RECIPES_DIR.glob("*/recipe.yaml")):
        variants = recipe.parent / "variants.yaml"
        if not variants.is_file():
            continue
        for key, vals in _read_variants(variants).items():
            if len(vals) != 1:
                matrix.add(key)
                continue
            values.setdefault(key, {}).setdefault(vals[0], []).append(recipe)

    pins: dict[str, tuple[str, list[Path]]] = {}
    inconsistent: dict[str, dict[str, list[Path]]] = {}
    for key, by_value in values.items():
        if key in matrix:
            continue
        if len(by_value) == 1:
            value, recipes = next(iter(by_value.items()))
            pins[key] = (value, recipes)
        else:
            inconsistent[key] = by_value
    return pins, inconsistent


def rewrite_variant_pin(path: Path, key: str, old: str, new: str) -> str | None:
    """Return variants.yaml text with ``key``'s value ``old`` -> ``new``.

    Returns None when the pin is not present as expected, so callers can treat
    a lockstep rewrite as all-or-nothing.
    """
    lines = path.read_text().splitlines(keepends=True)
    in_key = False
    for i, line in enumerate(lines):
        body = line.rstrip("\n")
        if re.match(rf"^{re.escape(key)}:\s*$", body):
            in_key = True
            continue
        if not in_key:
            continue
        m = re.match(r"^(\s+-\s*)([\"']?)(.+?)([\"']?)\s*$", body)
        if m:
            if m.group(3) != old:
                return None
            lines[i] = f"{m.group(1)}{m.group(2)}{new}{m.group(4)}\n"
            return "".join(lines)
        if body and not body.startswith((" ", "\t")):
            in_key = False
    return None


def bump_build_number(recipe: Path) -> int | None:
    """Increment the single top-level build.number; return the new value.

    ``^build:`` is anchored at column 0, so the nested (indented) ``build:``
    blocks of a multi-output recipe are never matched and the one top-level
    number — which governs every output — is the one bumped. Returns None when
    there is nothing to increment in place (e.g. a templated
    ``number: ${{ build_number }}``), leaving that recipe for manual handling.
    """
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


def detect_variant_drift(
    pins: dict[str, tuple[str, list[Path]]], cf: dict[str, str]
) -> list[tuple]:
    """Variant pins conda-forge has moved past; these need a lockstep bump."""
    rows = []
    for key, (value, recipes) in sorted(pins.items()):
        latest = cf.get(key)
        if not latest:  # not a conda-forge package (e.g. genie_hadronization)
            continue
        if vcmp(latest, value) > 0:
            rows.append((key, value, latest, recipes))
    return rows


def split_rows(rows: list[tuple]) -> tuple[list[tuple], list[tuple]]:
    """Partition rows into (rebuild refreshes these, held by our variants.yaml)."""
    mapping = recipe_name_map()
    stale, pinned = [], []
    for row in rows:
        name, _rec, dep_name = row[0], row[1], row[2]
        recipe = mapping.get(name)
        target = (
            pinned
            if recipe is not None and dep_name in variant_pinned_deps(recipe)
            else stale
        )
        target.append(row)
    return stale, pinned


def _dep_table(rows: list[tuple]) -> list[str]:
    lines = [
        "| Ship build | Dependency | Pinned range | conda-forge latest |",
        "|------------|------------|--------------|--------------------|",
    ]
    for name, rec, dep, constraint, latest in rows:
        build = f"{name} {rec['version']} `{rec.get('build', rec.get('build_number', 0))}`"
        lines.append(f"| {build} | {dep} | `{constraint}` | {latest} |")
    return lines


def render(
    rows: list[tuple],
    variant_rows: list[tuple],
    inconsistent: dict[str, dict[str, list[Path]]],
) -> str:
    lines = ["# Channel drift check", ""]
    if not rows and not variant_rows and not inconsistent:
        lines.append("No stale conda-forge pins found in the ship channel. ✅")
        return "\n".join(lines) + "\n"

    stale, pinned = split_rows(rows)

    if stale:
        pkgs = sorted({name for name, *_ in stale})
        lines += [
            f"Found **{len(stale)}** stale pin(s) across **{len(pkgs)}** ship "
            "package(s). conda-forge has moved past these ranges; rebuild (bump "
            "`build.number`) to refresh the pins and keep the packages "
            "co-installable with fresh source builds.",
            "",
            *_dep_table(stale),
            "",
        ]

    if pinned:
        pkgs = sorted({name for name, *_ in pinned})
        lines += [
            "## Pins held by our own `variants.yaml`",
            "",
            f"**{len(pinned)}** pin(s) across **{len(pkgs)}** package(s) are held "
            "at a value this repo chooses, not tracked to conda-forge. A rebuild "
            "reproduces them unchanged, so these do **not** justify a "
            "`build.number` bump — advance them by bumping the pin in lockstep.",
            "",
            *_dep_table(pinned),
            "",
        ]

    if variant_rows:
        lines += [
            "## Variant pins behind conda-forge",
            "",
            "Bump these in lockstep across every `variants.yaml` that declares "
            "them. No `build.number` bump is needed: the variant hash changes "
            "the build string, so the rebuild is not skipped.",
            "",
            "| Variant | Pinned | conda-forge latest | Recipes |",
            "|---------|--------|--------------------|---------|",
        ]
        for key, value, latest, recipes in variant_rows:
            names = ", ".join(sorted(r.parent.name for r in recipes))
            lines.append(f"| `{key}` | {value} | {latest} | {names} ({len(recipes)}) |")
        lines.append("")

    if inconsistent:
        lines += [
            "## Inconsistent variant pins",
            "",
            "These keys are pinned to different values in different recipes — "
            "usually a lockstep bump that stopped half-way. Reconcile them by "
            "hand; they are not bumped automatically.",
            "",
        ]
        for key, by_value in sorted(inconsistent.items()):
            for value, recipes in sorted(by_value.items()):
                names = ", ".join(sorted(r.parent.name for r in recipes))
                lines.append(f"- `{key}` = {value}: {names}")
        lines.append("")

    return "\n".join(lines) + "\n"


def group_by_recipe(rows: list[tuple]) -> tuple[dict[Path, dict[str, set[str]]], list[str]]:
    """Collapse rows onto their owning recipe; return ``(grouped, unknown)``.

    Several outputs of one recipe (field-service-core, field-service-tools, …)
    map to the same recipe.yaml. Grouping on the recipe rather than the package
    name is what keeps a bump at +1 instead of +1 per flagged output.
    """
    mapping = recipe_name_map()
    grouped: dict[Path, dict[str, set[str]]] = {}
    unknown: set[str] = set()
    for name, _rec, dep_name, *_ in rows:
        recipe = mapping.get(name)
        if recipe is None:
            unknown.add(name)
            continue
        entry = grouped.setdefault(recipe, {"pkgs": set(), "deps": set()})
        entry["pkgs"].add(name)
        entry["deps"].add(dep_name)
    return grouped, sorted(unknown)


def bump_affected(rows: list[tuple]) -> str:
    """Bump build.number once per affected recipe; return a summary."""
    grouped, unknown = group_by_recipe(rows)
    bumped, manual, pinned = [], [], []
    for recipe, entry in sorted(grouped.items()):
        pkgs = ", ".join(sorted(entry["pkgs"]))
        deps = entry["deps"]
        if not deps - variant_pinned_deps(recipe):
            pinned.append((pkgs, recipe.parent.name, sorted(deps)))
            continue
        new = bump_build_number(recipe)
        if new is None:
            manual.append((pkgs, recipe.parent.name))
        else:
            bumped.append((pkgs, recipe.parent.name, new))

    out = ["", "## Rebuild actions", ""]
    if bumped:
        out.append("Bumped `build.number` (rebuilds on merge):")
        out += [f"- `{r}` → build {n} ({p})" for p, r, n in bumped]
        out.append("")
    if manual:
        out.append("Needs manual rebuild (no bumpable top-level `build.number`):")
        out += [f"- `{p}` (recipe `{r}`)" for p, r in manual]
        out.append("")
    if pinned:
        out.append(
            "Not bumped — flagged only for pins held by the recipe's own "
            "`variants.yaml`, which a rebuild reproduces unchanged. Advance "
            "these by bumping the pin in lockstep instead:"
        )
        out += [
            f"- `{r}` ({', '.join(d)}) — {p}" for p, r, d in pinned
        ]
        out.append("")
    if unknown:
        out.append("No recipe in this repo (rebuilt elsewhere / transitive):")
        out += [f"- `{p}`" for p in unknown]
        out.append("")
    return "\n".join(out)


def bump_affected_variants(variant_rows: list[tuple]) -> str:
    """Rewrite each behind variant pin in every recipe declaring it."""
    out = ["", "## Variant actions", ""]
    if not variant_rows:
        out.append("No variant pins behind conda-forge.")
        return "\n".join(out) + "\n"
    for key, value, latest, recipes in variant_rows:
        # Stage every rewrite before touching disk: a pin advanced in some
        # recipes but not others is worse than one left alone.
        staged = {}
        for recipe in recipes:
            variants = recipe.parent / "variants.yaml"
            text = rewrite_variant_pin(variants, key, value, latest)
            if text is None:
                break
            staged[variants] = text
        if len(staged) != len(recipes):
            out.append(
                f"- `{key}`: **not rewritten** — could only update "
                f"{len(staged)}/{len(recipes)} recipes, and a partial lockstep "
                "bump would split the stack. Needs a look by hand."
            )
            continue
        for path, text in staged.items():
            path.write_text(text)
        names = ", ".join(sorted(r.parent.name for r in recipes))
        out.append(f"- `{key}` {value} → {latest} in {len(recipes)} recipe(s): {names}")
    out += [
        "",
        "No `build.number` bump accompanies these: changing a variant changes "
        "the build hash, so the build string is new and `--skip-existing` will "
        "not skip the rebuild.",
        "",
    ]
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bump-recipes", action="store_true",
                    help="bump build.number once per affected recipe")
    ap.add_argument("--bump-variants", action="store_true",
                    help="rewrite variant pins conda-forge has moved past, in lockstep")
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
    pins, inconsistent = variant_pins()
    variant_rows = detect_variant_drift(pins, cf)

    report = render(rows, variant_rows, inconsistent)
    if rows and args.bump_recipes:
        report += bump_affected(rows)
    if args.bump_variants:
        report += bump_affected_variants(variant_rows)

    print(report)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        Path(summary).write_text(report, encoding="utf-8")
    if args.pr_body:
        args.pr_body.write_text(report, encoding="utf-8")

    if args.bump_recipes or args.bump_variants:
        return 0
    return 1 if (rows or variant_rows or inconsistent) else 0


if __name__ == "__main__":
    raise SystemExit(main())

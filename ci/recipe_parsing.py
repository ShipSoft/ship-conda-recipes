"""Minimal recipe.yaml / variants.yaml parsing shared by the ci/ checks.

Regex-based and stdlib-only, so check-variant-lockstep.py can run as a prek
hook in the lint environment; check-channel-drift.py imports it alongside
py-rattler. Both scripts are run as ``python ci/<script>.py``, which puts this
directory on ``sys.path``.
"""

from __future__ import annotations

import re
from pathlib import Path

# YAML only starts a comment at a `#` preceded by whitespace.
_KEY = re.compile(r"^([A-Za-z0-9._-]+):(?:\s+#.*)?\s*$")
_ITEM = re.compile(r"^\s+-\s*(.+?)(?:\s+#.*)?\s*$")
_NAME = re.compile(r"^\s*name:\s*([A-Za-z0-9._-]+)\s*$")


def read_variants(path: Path) -> dict[str, list[str]]:
    """Parse a variants.yaml into ``key -> [value, ...]``.

    Only the block-sequence form used in this repo is understood
    (``key:`` followed by ``- value`` lines); quotes around values are dropped.
    """
    out: dict[str, list[str]] = {}
    key = None
    for line in path.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = _KEY.match(line)
        if m:
            key = m.group(1)
            out.setdefault(key, [])
            continue
        m = _ITEM.match(line)
        if m and key:
            out[key].append(m.group(1).strip("\"'"))
    return out


def recipe_names(recipe: Path) -> list[str]:
    """Every package name a recipe publishes, in file order."""
    return [
        m.group(1)
        for m in (_NAME.match(line) for line in recipe.read_text().splitlines())
        if m
    ]

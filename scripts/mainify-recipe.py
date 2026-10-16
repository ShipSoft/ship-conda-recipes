#!/usr/bin/env python3
"""Turn a release recipe into a build of the upstream main branch.

Copies recipes/<name>/ to an output directory and rewrites the copy so that
rattler-build builds a given commit of the ShipSoft repository instead of the
release tarball:

* the source entry pointing at github.com/ShipSoft/<repo> becomes a git
  source at that commit; other sources (e.g. vendored tarballs) are kept;
* build.number becomes the commit count on main, so newer commits always
  sort higher;
* build.string becomes main_<sha7>_<hash>, so the commit is visible in
  `pixi list` and builds of different commits never share a filename.

The version stays at the last release. Consumers select these builds by
channel (prefix.dev/ship-experiment/nightly), not by version.

Used by .github/workflows/nightly-main.yml.

Usage:
    mainify-recipe.py <recipe-dir> <repo> <sha> <commit-count> <out-dir>
"""

import re
import shutil
import sys
from pathlib import Path

from ruamel.yaml import YAML


def rewrite_sources(recipe, repo, sha):
    sources = recipe.get("source")
    if sources is None:
        raise SystemExit("recipe has no source")
    entries = sources if isinstance(sources, list) else [sources]
    pattern = re.compile(rf"github\.com/ShipSoft/{re.escape(repo)}/", re.IGNORECASE)
    hits = [e for e in entries if pattern.search(str(e.get("url", "")))]
    if len(hits) != 1:
        raise SystemExit(
            f"expected exactly one source from ShipSoft/{repo}, found {len(hits)}"
        )
    entry = hits[0]
    keep = {k: v for k, v in entry.items() if k not in ("url", "sha256", "md5")}
    entry.clear()
    entry["git"] = f"https://github.com/ShipSoft/{repo}.git"
    entry["rev"] = sha
    entry.update(keep)


def main():
    if len(sys.argv) != 6:
        print(__doc__.split("Usage:")[1], file=sys.stderr)
        return 2
    recipe_dir, repo, sha, count, out_dir = sys.argv[1:]
    recipe_dir, out_dir = Path(recipe_dir), Path(out_dir)
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise SystemExit(f"not a full commit SHA: {sha}")

    shutil.copytree(recipe_dir, out_dir, dirs_exist_ok=True)
    path = out_dir / "recipe.yaml"

    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.width = 4096
    yaml.indent(mapping=2, sequence=4, offset=2)
    recipe = yaml.load(path)

    rewrite_sources(recipe, repo, sha)

    # Top-level build: is inherited by every output of a multi-output recipe.
    build = recipe.setdefault("build", {})
    build["number"] = int(count)
    build["string"] = f"main_{sha[:7]}_${{{{ hash }}}}"

    yaml.dump(recipe, path)
    return 0


if __name__ == "__main__":
    sys.exit(main())

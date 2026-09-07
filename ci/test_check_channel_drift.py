#!/usr/bin/env python3
"""Regression tests for ci/check-channel-drift.py.

No pytest; run in the drift pixi env (the module imports ``rattler``):

    pixi run -e drift python ci/test_check_channel_drift.py
"""

import importlib.util
import tempfile
import textwrap
import unittest
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "check_channel_drift", Path(__file__).with_name("check-channel-drift.py")
)
drift = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(drift)


class VersionOrderTest(unittest.TestCase):
    def assert_lt(self, a, b):
        self.assertEqual(drift.vcmp(a, b), -1, f"expected {a} < {b}")
        self.assertEqual(drift.vcmp(b, a), 1, f"expected {b} > {a}")

    def assert_eq(self, a, b):
        self.assertEqual(drift.vcmp(a, b), 0, f"expected {a} == {b}")

    def test_dev_sorts_below_release(self):
        # dev-releases precede the corresponding final release
        self.assert_lt("1.0.dev1", "1.0")
        self.assert_lt("1.0dev1", "1.0")
        self.assert_lt("2.3.4.dev0", "2.3.4")

    def test_dev_sorts_below_other_prereleases(self):
        # conda upper-cases "dev" so it sorts below alpha/beta/rc markers
        self.assert_lt("1.0dev1", "1.0a1")
        self.assert_lt("1.0.dev1", "1.0.rc1")

    def test_post_sorts_above_release(self):
        # post-releases follow the corresponding final release ...
        self.assert_lt("1.0", "1.0.post1")
        self.assert_lt("1.0", "1.0post1")
        # ... but still precede the next micro release. (A hand-rolled
        # "post == infinity" comparator got this wrong; rattler is authoritative.)
        self.assert_lt("1.0.post1", "1.0.1")

    def test_ordering_chain(self):
        for a, b in zip(
            ["1.0dev1", "1.0a1", "1.0rc1", "1.0", "1.0.post1"],
            ["1.0a1", "1.0rc1", "1.0", "1.0.post1", "1.1"],
        ):
            self.assert_lt(a, b)

    def test_basic_and_equivalence(self):
        self.assert_eq("1.0", "1.0.0")
        self.assert_lt("1.9", "1.10")
        self.assert_lt("1.0", "2.0")

    def test_exceeds_uses_conda_semantics(self):
        # a conda-forge post-release must trip a "< final" upper bound
        self.assertTrue(drift.exceeds("1.0.post1", "<", "1.0"))
        # a dev-release must NOT trip it
        self.assertFalse(drift.exceeds("1.0.dev1", "<", "1.0"))


class SelectionTest(unittest.TestCase):
    def _fake_repodata(self, monkey, per_subdir):
        def fake_fetch(url):
            for subdir, payload in per_subdir.items():
                if subdir in url:
                    if isinstance(payload, Exception):
                        raise payload
                    return payload
            raise AssertionError(f"unexpected url {url}")

        monkey(drift, "fetch_json", fake_fetch)

    def setUp(self):
        self._orig = drift.fetch_json
        self.addCleanup(lambda: setattr(drift, "fetch_json", self._orig))

    def _set_fetch(self, mod, name, fn):
        setattr(mod, name, fn)

    def test_retains_tied_build_variants(self):
        # two builds tied on version + build_number but with distinct build
        # strings must both be retained for inspection
        pkg = lambda build, deps: {  # noqa: E731
            "name": "foo", "version": "1.0", "build_number": 0,
            "build": build, "depends": deps,
        }
        self._fake_repodata(self._set_fetch, {
            "linux-64": {"packages": {
                "foo-a.tar.bz2": pkg("cxx20_h0_0", ["bar <2"]),
                "foo-b.tar.bz2": pkg("cxx23_h1_0", ["bar <3"]),
            }},
            "noarch": {"packages": {}},
        })
        picked, failed = drift.latest_builds()
        self.assertEqual(failed, [])
        self.assertEqual(len(picked["foo"]), 2)
        rows = drift.detect(picked, {"bar": "2.5"})
        # the <2 variant drifts against bar 2.5; the <3 one does not
        drifted = {(r[0], r[3]) for r in rows}
        self.assertIn(("foo", "<2"), drifted)
        self.assertNotIn(("foo", "<3"), drifted)

    def test_higher_supersedes_ties(self):
        pkg = lambda ver, bn, build: {  # noqa: E731
            "name": "foo", "version": ver, "build_number": bn,
            "build": build, "depends": [],
        }
        self._fake_repodata(self._set_fetch, {
            "linux-64": {"packages": {
                "a": pkg("1.0", 0, "h0_0"),
                "b": pkg("1.0", 0, "h1_0"),
                "c": pkg("1.1", 0, "h0_0"),  # strictly higher wipes the ties
            }},
            "noarch": {"packages": {}},
        })
        picked, _ = drift.latest_builds()
        self.assertEqual([r["version"] for r in picked["foo"]], ["1.1"])

    def test_fetch_failure_is_reported(self):
        self._fake_repodata(self._set_fetch, {
            "linux-64": RuntimeError("boom"),
            "noarch": {"packages": {}},
        })
        _picked, failed = drift.latest_builds()
        self.assertEqual(failed, ["linux-64"])

    def test_ignored_dep_names_are_skipped(self):
        # eigen-abi is an ABI marker pinned transitively (IGNORE_DEPS): a newer
        # conda-forge marker must not be flagged, but genuine drift still is.
        rec = {
            "name": "shipgeometry", "version": "0.2.1", "build_number": 3,
            "build": "hb0f4dca_3",
            "depends": ["eigen-abi >=5.0.1.80,<5.0.1.81.0a0",
                        "libboost >=1.90.0,<1.91.0a0"],
        }
        rows = drift.detect(
            {"shipgeometry": [rec]},
            {"eigen-abi": "5.0.1.100", "libboost": "1.91.0"},
        )
        flagged = {r[2] for r in rows}
        self.assertNotIn("eigen-abi", flagged)
        self.assertIn("libboost", flagged)


class _TempRecipes(unittest.TestCase):
    """Base: point RECIPES_DIR at a throwaway tree of recipes."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.recipes = Path(self._tmp.name)
        self._orig_dir = drift.RECIPES_DIR
        drift.RECIPES_DIR = self.recipes
        drift.variant_pinned_deps.cache_clear()
        self.addCleanup(self._restore)

    def _restore(self):
        drift.RECIPES_DIR = self._orig_dir
        drift.variant_pinned_deps.cache_clear()
        self._tmp.cleanup()

    def write(self, dirname, recipe: str, variants: str | None = None) -> Path:
        d = self.recipes / dirname
        d.mkdir()
        (d / "recipe.yaml").write_text(textwrap.dedent(recipe).lstrip())
        if variants is not None:
            (d / "variants.yaml").write_text(textwrap.dedent(variants).lstrip())
        return d / "recipe.yaml"

    @staticmethod
    def row(pkg, dep):
        rec = {"name": pkg, "version": "0.1.0", "build_number": 2, "build": "h0_2"}
        return (pkg, rec, dep, ">=1,<2", "3.0")


MULTI_OUTPUT = """
    build:
      number: 2

    outputs:
      - package:
          name: thing-core
        build:
          files:
            - lib/libthing.so
      - package:
          name: thing-tools
        build:
          files:
            - bin/thing
"""

ROOT_PIN = """
    root_cxx_standard:
      - "20"
      - "23"
    root_base:
      - "6.40.2"
"""


class RecipeBumpTest(_TempRecipes):
    """build.number bumping, incl. multi-output and repeated-output recipes."""

    def test_multi_output_top_level_number_is_bumped(self):
        # Nested output build: blocks are indented, so only the column-0 one —
        # which governs every output — is touched.
        recipe = self.write("thing", MULTI_OUTPUT)
        self.assertEqual(drift.bump_build_number(recipe), 3)
        text = recipe.read_text()
        self.assertIn("build:\n  number: 3\n", text)
        self.assertEqual(text.count("number:"), 1)

    def test_templated_number_is_left_for_manual_handling(self):
        self.write("tmpl", """
            context:
              build_number: 0

            build:
              number: ${{ build_number }}

            outputs:
              - package:
                  name: tmpl-core
        """)
        self.assertIsNone(drift.bump_build_number(self.recipes / "tmpl" / "recipe.yaml"))
        report = drift.bump_affected([self.row("tmpl-core", "libboost")])
        self.assertIn("no bumpable top-level", report)
        self.assertIn("`tmpl`", report)

    def test_recipe_bumped_once_when_several_outputs_flagged(self):
        # Regression: both outputs map to one recipe.yaml, so iterating package
        # names rather than recipes bumped it twice.
        recipe = self.write("thing", MULTI_OUTPUT)
        drift.bump_affected([
            self.row("thing-core", "libboost"),
            self.row("thing-tools", "gsl"),
        ])
        self.assertIn("build:\n  number: 3\n", recipe.read_text())

    def test_unknown_package_is_listed_not_bumped(self):
        report = drift.bump_affected([self.row("built-elsewhere", "libboost")])
        self.assertIn("No recipe in this repo", report)


class VariantPinTest(_TempRecipes):
    """Deps pinned by our own variants.yaml, and pins that fall behind."""

    def simple(self, dirname, variants=None, number=2):
        return self.write(
            dirname,
            f"package:\n  name: {dirname}\n\nbuild:\n  number: {number}\n",
            variants,
        )

    def test_matrix_keys_are_not_pins(self):
        self.simple("alpha", ROOT_PIN)
        pins, inconsistent = drift.variant_pins()
        # root_cxx_standard carries two values: a build matrix, not a pin.
        self.assertEqual(sorted(pins), ["root_base"])
        self.assertEqual(pins["root_base"][0], "6.40.2")
        self.assertEqual(inconsistent, {})

    def test_divergent_values_reported_as_inconsistent(self):
        self.simple("alpha", ROOT_PIN)
        self.simple("beta", 'root_base:\n  - "6.40.04"\n')
        pins, inconsistent = drift.variant_pins()
        self.assertNotIn("root_base", pins)
        self.assertEqual(sorted(inconsistent["root_base"]), ["6.40.04", "6.40.2"])

    def test_variant_pinned_dep_does_not_trigger_a_bump(self):
        recipe = self.simple("alpha", ROOT_PIN)
        report = drift.bump_affected([self.row("alpha", "root_base")])
        self.assertIn("  number: 2\n", recipe.read_text())
        self.assertIn("variants.yaml", report)
        self.assertIn("root_base", report)

    def test_unpinned_dep_still_triggers_a_bump(self):
        # Same recipe, also flagged for something its variants.yaml does not pin.
        recipe = self.simple("alpha", ROOT_PIN)
        drift.bump_affected([
            self.row("alpha", "root_base"),
            self.row("alpha", "gsl"),
        ])
        self.assertIn("  number: 3\n", recipe.read_text())

    def test_recipe_pinning_only_a_matrix_key_is_bumpable(self):
        # rootegpythia6 pins only root_cxx_standard, so its root_base pin does
        # refresh on a rebuild and the bump is worth making.
        recipe = self.simple("gamma", 'root_cxx_standard:\n  - "20"\n  - "23"\n')
        drift.bump_affected([self.row("gamma", "root_base")])
        self.assertIn("  number: 3\n", recipe.read_text())

    def test_split_rows_partitions_on_the_owning_recipe(self):
        self.simple("alpha", ROOT_PIN)
        stale, pinned = drift.split_rows([
            self.row("alpha", "root_base"),
            self.row("alpha", "gsl"),
        ])
        self.assertEqual([r[2] for r in stale], ["gsl"])
        self.assertEqual([r[2] for r in pinned], ["root_base"])

    def test_detect_variant_drift(self):
        self.simple("alpha", ROOT_PIN)
        pins, _ = drift.variant_pins()
        rows = drift.detect_variant_drift(pins, {"root_base": "6.40.04"})
        self.assertEqual([(r[0], r[1], r[2]) for r in rows],
                         [("root_base", "6.40.2", "6.40.04")])
        # Level pegging, and keys conda-forge does not know, yield nothing.
        self.assertEqual(drift.detect_variant_drift(pins, {"root_base": "6.40.2"}), [])
        self.assertEqual(drift.detect_variant_drift(pins, {}), [])

    def test_bump_variants_rewrites_every_recipe_and_keeps_quoting(self):
        a = self.simple("alpha", ROOT_PIN)
        b = self.simple("beta", ROOT_PIN)
        pins, _ = drift.variant_pins()
        rows = drift.detect_variant_drift(pins, {"root_base": "6.40.04"})
        drift.bump_affected_variants(rows)
        for recipe in (a, b):
            text = (recipe.parent / "variants.yaml").read_text()
            self.assertIn('root_base:\n  - "6.40.04"\n', text)
            self.assertIn('  - "20"\n  - "23"\n', text)  # matrix untouched

    def test_partial_lockstep_is_refused(self):
        self.simple("alpha", ROOT_PIN)
        stray = self.simple("beta", ROOT_PIN)
        pins, _ = drift.variant_pins()
        rows = drift.detect_variant_drift(pins, {"root_base": "6.40.04"})
        # Someone moved one recipe out from under us between detect and bump.
        (stray.parent / "variants.yaml").write_text('root_base:\n  - "7.0.0"\n')
        report = drift.bump_affected_variants(rows)
        self.assertIn("not rewritten", report)
        alpha = (self.recipes / "alpha" / "variants.yaml").read_text()
        self.assertIn('  - "6.40.2"\n', alpha)


if __name__ == "__main__":
    unittest.main()

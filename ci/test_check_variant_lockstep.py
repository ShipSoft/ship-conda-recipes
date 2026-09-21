#!/usr/bin/env python3
"""Regression tests for ci/check-variant-lockstep.py.

No pytest; stdlib only, so it runs in the lint env:

    pixi run test-lockstep
"""

import importlib.util
import tempfile
import textwrap
import unittest
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "check_variant_lockstep", Path(__file__).with_name("check-variant-lockstep.py")
)
lockstep = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(lockstep)


def write_recipe(root: Path, name: str, *, recipe: str, variants: str | None = None) -> None:
    d = root / name
    d.mkdir(parents=True)
    (d / "recipe.yaml").write_text(textwrap.dedent(recipe).lstrip())
    if variants is not None:
        (d / "variants.yaml").write_text(textwrap.dedent(variants).lstrip())


PRODUCER = """
    package:
      name: rootegpythia6
      version: "0.1"
    requirements:
      host:
        - root_base
        - root_cxx_standard
        - pythia6
"""

CONSUMER = """
    package:
      name: fairship
      version: "26.09"
    requirements:
      host:
        - root_base
        - root_cxx_standard
        - rootegpythia6
"""

PIN_6402 = """
    root_cxx_standard:
      - "20"
      - "23"
    root_base:
      - "6.40.2"
"""

MATRIX_ONLY = """
    root_cxx_standard:
      - "20"
      - "23"
"""


class LockstepTest(unittest.TestCase):
    def check(self, recipes: dict[str, tuple[str, str | None]]) -> list[str]:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "recipes"
            root.mkdir()
            for name, (recipe, variants) in recipes.items():
                write_recipe(root, name, recipe=recipe, variants=variants)
            return lockstep.check(root)

    def test_matching_pins_pass(self):
        self.assertEqual(
            self.check(
                {
                    "rootegpythia6": (PRODUCER, PIN_6402),
                    "fairship": (CONSUMER, PIN_6402),
                }
            ),
            [],
        )

    def test_unpinned_producer_is_reported(self):
        # The state that broke PRs #169 and #170.
        problems = self.check(
            {
                "rootegpythia6": (PRODUCER, MATRIX_ONLY),
                "fairship": (CONSUMER, PIN_6402),
            }
        )
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("must pin root_base in its own variants.yaml", problems[0])
        self.assertIn("rootegpythia6", problems[0])

    def test_half_finished_lockstep_bump_is_reported(self):
        bumped = PIN_6402.replace("6.40.2", "6.40.04")
        problems = self.check(
            {
                "rootegpythia6": (PRODUCER, PIN_6402),
                "fairship": (CONSUMER, bumped),
            }
        )
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("bump them in lockstep", problems[0])

    def test_producer_that_does_not_link_root_is_ignored(self):
        pythia6 = """
            package:
              name: pythia6
              version: "6.4.28"
            requirements:
              host:
                - libgfortran
        """
        consumer = """
            package:
              name: fairship
              version: "26.09"
            requirements:
              host:
                - root_base
                - pythia6
        """
        self.assertEqual(
            self.check({"pythia6": (pythia6, None), "fairship": (consumer, PIN_6402)}), []
        )

    def test_unpinned_consumer_does_not_constrain_its_deps(self):
        # aegir-genie constrains ROOT in host: instead of pinning a variant, so
        # it follows whatever its dependencies bring and cannot desync.
        unpinned_consumer = CONSUMER.replace("fairship", "aegir-genie")
        self.assertEqual(
            self.check(
                {
                    "rootegpythia6": (PRODUCER, MATRIX_ONLY),
                    "aegir-genie": (unpinned_consumer, MATRIX_ONLY),
                }
            ),
            [],
        )

    def test_conditional_host_dep_counts(self):
        # genie lists rootegpythia6 only under the pythia6 variant.
        genie = """
            package:
              name: genie
              version: "3.06.02"
            requirements:
              host:
                - root_base
                - if: genie_hadronization == "pythia6"
                  then:
                    - rootegpythia6
                    - pythia6
                  else:
                    - pythia8
        """
        problems = self.check(
            {"rootegpythia6": (PRODUCER, MATRIX_ONLY), "genie": (genie, PIN_6402)}
        )
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("rootegpythia6", problems[0])

    def test_multi_output_host_blocks_are_pooled(self):
        multi = """
            recipe:
              name: field-service
              version: "0.1.0"
            outputs:
              - package:
                  name: field-service-core
                requirements:
                  host:
                    - eigen
              - package:
                  name: field-service-tools
                requirements:
                  host:
                    - root_base
                    - rootegpythia6
        """
        problems = self.check(
            {"rootegpythia6": (PRODUCER, MATRIX_ONLY), "field-service": (multi, PIN_6402)}
        )
        self.assertEqual(len(problems), 1, problems)


if __name__ == "__main__":
    unittest.main()

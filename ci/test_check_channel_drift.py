#!/usr/bin/env python3
"""Regression tests for ci/check-channel-drift.py.

No pytest; run in the drift pixi env (the module imports ``rattler``):

    pixi run -e drift python ci/test_check_channel_drift.py
"""

import importlib.util
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


if __name__ == "__main__":
    unittest.main()

# ship-conda-recipes

Conda recipes for SHiP experiment packages not available on conda-forge.

Built with [rattler-build](https://prefix-dev.github.io/rattler-build/) and hosted
on [prefix.dev/ship-experiment/stable](https://prefix.dev/channels/@ship-experiment/stable).
The old `prefix.dev/ship` channel no longer receives uploads.

## Packages

| Package | Upstream candidate? |
|---------|---------------------|
| aegir | No (SHiP-specific) |
| aegir-genie | No (SHiP-specific, links GPL GENIE) |
| evtgen | Temporary (conda-forge's links pythia8 8.312, see below) |
| fairroot | No (carries patch) |
| fairship | No (SHiP-specific) |
| field-service | No (SHiP-specific) |
| ganga | No (HEP-specific, not in conda-forge today) |
| geant3 | Yes |
| genfit | Yes |
| genie | No (GPL, links SHiP-specific drivers) |
| genie-data | No (ships with `genie`) |
| genie-splines-ship | No (SHiP-specific splines) |
| mp-units | Yes (conda-forge feedstock) |
| npdb-client | No (SHiP-specific, split recipe with `python-npdb-client`) |
| photospp | Yes |
| pythia6 | No (ShipSoft fork) |
| pythia8 | Temporary (conda-forge is behind, see below) |
| random123 | Yes (conda-forge feedstock) |
| rootegpythia6 | No (niche) |
| shannon | No (SHiP-specific) |
| ship-ci-metrics | No (SHiP-specific) |
| ship-field-maps | No (SHiP-specific data) |
| ship-random | No (SHiP-specific) |
| shipdatamodel | No (SHiP-specific) |
| shipgeometry | No (SHiP-specific) |
| shipgeometryservice | No (SHiP-specific) |
| trout | No (SHiP-specific) |

### Upstreamed to conda-forge

Previously packaged here, now consumed directly from conda-forge:

- [FairLogger](https://github.com/conda-forge/fairlogger-feedstock)
- [FairCMakeModules](https://github.com/conda-forge/faircmakemodules-feedstock)
- [cetmodules](https://github.com/conda-forge/cetmodules-feedstock)
- [libjsonnet](https://github.com/conda-forge/libjsonnet-feedstock)
- [vmc](https://github.com/conda-forge/vmc-feedstock)
- [vgm](https://github.com/conda-forge/vgm-feedstock)
- [phlex](https://github.com/conda-forge/phlex-feedstock)
- [GeoModel](https://github.com/conda-forge/geomodel-feedstock)
- [geant4-vmc](https://github.com/conda-forge/geant4-vmc-feedstock)

### Temporary overrides of conda-forge

conda-forge ships these, but too old for SHiP. The recipes are copies of the
conda-forge feedstocks with as few changes as possible, and they go away once
conda-forge catches up.

- **pythia8 8.318**: conda-forge has 8.312, and SHiP productions see physics
  differences from 8.316 onward. The 8.316 bump is
  [pythia8-feedstock#74](https://github.com/conda-forge/pythia8-feedstock/pull/74).
  Changes from the feedstock: hepmc3 capped below 3.3.1 so it can share an
  environment with conda-forge `photos`/`evtgen`, plus the `fastjet-cxx-devel`
  dependency from #74. `run_exports` is the feedstock's
  (`>=8.318,<8.400.0a0`).
- **evtgen 2.2.3**: the same version as conda-forge, rebuilt against our
  pythia8. conda-forge's build links 8.312 and accepts any 8.3 release at
  runtime, but Pythia doesn't keep ABI between releases. linux-64 only, like
  the rest of the FairShip stack.

The ship channel comes first and solves use strict channel priority, so while
our pythia8 is on the channel, no solve sees conda-forge's. Once conda-forge
ships pythia8 ≥ 8.318 (and an evtgen built against it):

1. Delete `recipes/pythia8` and `recipes/evtgen` and their table rows.
2. Refresh the downstream lockfiles (FairShip, aegir) so they no longer point
   at the ship-channel builds.
3. Delete the ship-channel pythia8 and evtgen builds with the prefix.dev
   delete API. A UI yank isn't enough: the builds stay in the repodata and keep
   shadowing conda-forge.

Consumers need no rebuild: their `pythia8 >=8.318,<8.400.0a0` pin accepts
conda-forge's build.

## Recipe conventions

### Compiler versions (`global-variants.yaml`)

Every build passes `global-variants.yaml` with `--variant-config`: `build.yml`,
`nightly-main.yml` and the pixi build tasks. It pins `c_compiler_version` and
`cxx_compiler_version` to the versions in conda-forge's global pinning. Without
it rattler-build uses the newest compiler on conda-forge, and a package built
with a newer GCC than its consumers can fail to link in their environments
(seen with `std::format` code built by GCC 16 and linked by GCC 15). Move the
pin when conda-forge does, and bump `build.number` in every recipe whose build
string changes, so the rebuilds supersede the old builds.

### Platforms

Everything is built for linux-64. The Amaru stack is also built for
linux-aarch64 and osx-arm64: aegir, aegir-genie, shannon, trout,
shipdatamodel, shipgeometry, shipgeometryservice, field-service, mp-units,
and the GENIE chain (genie, pythia6, pythia8, rootegpythia6). `build.yml`
runs one native job per platform (`platforms` in the shared rattler-build
workflow), `nightly-main.yml` does the same for each library, and the aegir
dev builds run on the Linux runners.

The FairShip stack (fairship, fairroot, evtgen, geant3, genfit, photospp)
and npdb-client stay linux-64 only. Their recipes skip every other platform
with `target_platform != "linux-64"`, so a `--recipe-dir` build on an arm64
runner leaves them out. noarch recipes need no skip. Each CI job builds the
noarch packages it needs, and only the linux-64 job uploads them.

Recipes request the sysroot as `if: linux` / `then: sysroot_${{ target_platform
}} 2.17.*` instead of `${{ stdlib('c') }}`. `stdlib('c')` would add
`c_stdlib` and `c_stdlib_version` to the hash of every compiled package and
force a rebuild of the whole channel on linux-64. On macOS the same entry
falls through to `else: ${{ stdlib('c') }}`, which only renders there.

macOS needs two settings, both in `global-variants.yaml` behind `if: osx`:

- clang 20 instead of conda-forge's default 21. conda-forge's `root_base` on
  macOS requires `libcxx-devel 20.*`, the headers of the clang cling was built
  with, so any environment that has ROOT and a compiler gets clang 20.
  root-feedstock and phlex-feedstock build with it for the same reason.
- deployment target 13.3 (`c_stdlib_version`). `std::format` of floating-point
  values needs `std::to_chars`, which libc++ only provides from macOS 13.3.

The ROOT recipes skip their cxx20 variant on macOS: it only serves the
linux-64 FairShip stack, and everything on macOS that links ROOT is cxx23.
conda-forge's libc++ 20 headers also misspell the LLVM 20 availability
attribute (fixed upstream in libcxx-feedstock#265, not on its 20.x branch),
which breaks C++20 code that pulls in `<charconv>`, e.g. through `<chrono>`.
Where C++20 is unavoidable (GENIE's build, the mp-units consumer test),
`-D_LIBCPP_DISABLE_AVAILABILITY` works around it; conda's libcxx is the
runtime, so the markup isn't needed.

Library tests use a `shlib_ext` context variable (`dylib` on macOS, `so`
elsewhere) for ordinary shared libraries. The phlex plugins are CMake `MODULE`
libraries, which keep the `.so` suffix on macOS, so their tests don't change.

### ROOT C++ standard variants (`root_cxx_standard` / `root_base`)

conda-forge splits ROOT builds by C++ standard: consumers put `root_base` and
the `root_cxx_standard` marker in `host:` and rely on `root_base`'s
`run_exports`. Most ROOT-linking recipes here build two variants, driven by
two keys in their `variants.yaml`:

- `root_cxx_standard` (`"20"` / `"23"`) is a variant key: it is folded into
  the package hash, constrains the `root_base` build selected in `host:`, and
  — where the package compiles with an explicit standard — is read by
  `build.sh` as `$root_cxx_standard`. cxx20 serves consumers of the default
  ROOT builds (e.g. FairShip); cxx23 serves the phlex/aegir stack (phlex pins
  `root_cxx_standard ==23`).
- `root_base` must be pinned explicitly as well (currently `6.40.04` in the
  published recipes under `recipes/`). A bare
  `root_base` host spec resolves, under `root_cxx_standard` 23, to the legacy
  pre-cxx-split `root_base` 6.36.06 — that build declares no
  `root_cxx_standard` dependency, so it spuriously satisfies the C++23 marker
  and the solver prefers it. Pinning keeps every recipe on the same ROOT
  series, as conda-forge's global `root_base` pin does. Bump every
  `variants.yaml` under `recipes/` in lockstep when conda-forge moves ROOT
  past 6.40.04. `recipes-dev/phlex` is not part of the lockstep: it keeps its
  own series pin (`6.40`), matched to the SHiP stack's lock file.

Because `root_base` is pinned by us rather than tracked to conda-forge, a
rebuild reproduces the same pin — so the channel-drift check reports it apart
from genuine stale pins and never bumps `build.number` for it. When conda-forge
moves past the pin, the check opens a separate `variant-drift` PR advancing it
across every `variants.yaml` under `recipes/` at once. That PR is a real ROOT upgrade rather than
a routine refresh, so review it on its own merits. No `build.number` bump
accompanies it: changing a variant changes the build hash, so the build string
is new and `--skip-existing` will not skip the rebuild. Every published
ROOT-linking recipe carries the pin, rootegpythia6 included: fairship and genie list
rootegpythia6 in `host:` and pin `root_base` themselves, so a rootegpythia6
left to float to conda-forge's current ROOT either makes their host env
unsolvable or sends the solver back to a pre-`root_base` build from the
channel. `ci/check-variant-lockstep.py` enforces that at review time; it runs
as a prek hook and needs no network access.

For packages whose upstream build system sets no explicit C++ standard
(photospp's autotools, GENIE's perl configure — both inherit ROOT's standard
via `root-config`), there is no compile flag to drive; the variant only makes
the ROOT build they link against deterministic.

The C++23-only aegir stack (aegir, aegir-genie, shannon, trout) builds a
single variant and constrains ROOT in `host:` instead — `root_base >=6.40`
plus `root_cxx_standard ==23` — which equally excludes the legacy 6.36.06
build.
rootegpythia6 builds both variants and pins `root_base` in `variants.yaml`, in
lockstep with fairship and genie, which link against it.

### Known upstream workarounds

Workarounds carried by several recipes at once are documented here; the
recipes carry a one-line pointer. Single-recipe workarounds keep their full
rationale inline next to the pin. Each entry states the condition under which
it can be dropped.

- **`eigen-abi-devel` in `host:`** (aegir, aegir-genie, shipgeometry,
  shipgeometryservice, trout): `GeoModelCoreConfig.cmake` does
  `find_dependency(Eigen3)`; per the conda-forge eigen-feedstock README
  (case B), consumers of a library that exposes Eigen in public headers must
  list `eigen-abi-devel` in host.
  *Remove when* conda-forge geomodel-feedstock ships `-devel` outputs
  (case C).
- **`eigen-abi` excluded from the channel-drift check**
  (`ci/check-channel-drift.py` `IGNORE_DEPS`): every geomodel-core consumer
  inherits an exact `eigen-abi` pin from geomodel-core's baked `eigen`
  run_export. conda-forge geomodel-core is still on `eigen-abi 5.0.1.80` while
  conda-forge ships `5.0.1.100`, so the marker reads as "behind" — but it's an
  ABI lock a SHiP rebuild can't advance, so the drift check skips it.
  *Remove when* conda-forge geomodel-core is rebuilt against the newer
  eigen-abi.
- **`libboost-devel` pinned in fairroot, outside the variant-drift check**
  (`recipes/fairroot/variants.yaml`, `IGNORE_VARIANT_DRIFT` in
  `ci/check-channel-drift.py`): fairship links both fairroot and acts-core, so
  the two have to use the same libboost. conda-forge acts-core follows
  conda-forge's libboost migration (1.90), but nothing in fairroot's host
  limits Boost, so left free it takes the newest libboost on conda-forge
  instead. The pin follows the migration, so a newer Boost release on
  conda-forge does not count as drift.
  *Remove when* fairroot's host has another dependency that pins libboost.
  Until then, advance the pin when conda-forge's libboost migration moves.
- **`nlohmann_json` in `host:`** (same five recipes):
  `GeoModelToolsConfig.cmake` does `find_dependency(nlohmann_json 3.12.0)`,
  but conda-forge geomodel-tools keeps nlohmann_json in host only (no run, no
  run_exports) and nlohmann_json has no run_exports of its own — so any
  package whose Config triggers `find_dependency(GeoModelTools)` at configure
  time forces consumers to list nlohmann_json in host.
  *Remove when* conda-forge geomodel-feedstock adds nlohmann_json to
  geomodel-tools' `run:`.
- **`libnsl` as an explicit dependency** (genie, aegir-genie): conda-forge
  log4cpp 1.1.4 underdeclares its libnsl runtime dependency
  (`liblog4cpp.so.5` has `DT_NEEDED libnsl.so.3` but the package only depends
  on libgcc/libstdcxx).
  *Remove when* the conda-forge log4cpp feedstock declares it.
- **`expat`, `zlib` and `freetype` in `host:`** (fairship, fairroot, aegir,
  aegir-genie, shipgeometryservice, field-service, trout): conda-forge geant4
  is built with `GEANT4_USE_SYSTEM_EXPAT=ON`, `GEANT4_USE_SYSTEM_ZLIB=ON` and
  `GEANT4_USE_FREETYPE=ON`, so its `Geant4Config.cmake` calls
  `find_dependency()` on EXPAT, ZLIB and Freetype — each of which needs
  headers and a CMake config, not just the shared library. Since the
  v1-recipe modernisation (conda-forge/geant4-feedstock#104) the geant4
  output's `run:` lists only `libexpat` / `libzlib` / `libfreetype`, so
  `find_package(Geant4)` fails in any consumer that does not bring the three
  itself. Consumers that also depend on ROOT get `zlib` and `freetype` via
  its closure and only trip over `expat`; shipgeometryservice, which has no
  ROOT, trips over all three. The feedstock's own CMake test does not catch
  this because its test environment lists all three explicitly.
  The dev-build workflows resolve the upstream pixi manifests instead of these
  recipes, so FairShip's and geometry_service's `pixi.toml` carry the same
  three (and field_service's carries `expat`); drop those alongside the recipe
  entries.
  *Remove when* conda-forge geant4-feedstock puts `expat`, `zlib` and
  `freetype` back in the geant4 output's `run:`.

## Building

```bash
pixi install
pixi run build-all
```

Builds every recipe under `recipes/`. rattler-build resolves the
cross-recipe dependency order from each recipe's `requirements:` block
and skips packages that have already been built.

To build a single recipe:

```bash
pixi run rattler-build build --recipe recipes/<package-name> \
    --variant-config global-variants.yaml \
    --channel https://prefix.dev/ship-experiment/stable --channel conda-forge
```

## Nightly main builds

`.github/workflows/nightly-main.yml` builds the `main` branch of the
ShipSoft libraries used by aegir, Shannon and Trout (ship-random,
shipdatamodel, shipgeometry, shipgeometryservice, field-service) every night
and uploads them to [prefix.dev/ship-experiment/nightly](https://prefix.dev/channels/@ship-experiment/nightly).
Consumer repos run advisory PR jobs against these builds, so a PR can use an
unreleased library change before it is released.

`scripts/mainify-recipe.py` derives each build from the release recipe here:
the source becomes the main commit, the build number is the commit count on
main, and the build string is `main_<sha7>_<hash>`. The version stays at the
last release. Each library builds against released dependencies only, never
against other nightly packages, and the recipe tests are skipped because
they check the release's file list. A commit already on the channel is not
rebuilt; dispatch the workflow with `force` to rebuild it.

To build one library's main locally:

```bash
pixi run -e nightly mainify-recipe \
    recipes/ship-random ship-random <sha> <commit-count> /tmp/ship-random-main
pixi run rattler-build build --recipe /tmp/ship-random-main \
    --variant-config global-variants.yaml \
    --channel https://prefix.dev/ship-experiment/stable --channel conda-forge
```

## Dev builds of upstream PRs

`recipes-dev/` holds recipes that are never published. `build-all` only
builds `recipes/`. `recipes-dev/phlex` mirrors the conda-forge phlex-feedstock
recipe but builds from a git ref. It writes into a local channel at
`../ship-local-channel`, which downstream dev environments resolve ahead of
conda-forge:

```bash
pixi run build-phlex-pr <pr-number|branch|tag|sha>
```

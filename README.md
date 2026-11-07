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
| phlex | Temporary (conda-forge has no ROOT 6.42, see below) |
| pythia6 | No (ShipSoft fork) |
| pythia8 | Temporary (conda-forge is behind, see below) |
| random123 | Yes (conda-forge feedstock) |
| root | Temporary (conda-forge's links pythia8 8.312, see below) |
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

- **phlex 0.4.3** (`recipes/phlex`, linux-64 and linux-aarch64): the
  feedstock's recipe at `b62502c`, with `stdlib('c')` replaced by the sysroot
  convention below and a one-line patch for ROOT 6.42's deprecated
  `RVersion.h` (fatal under phlex's `-Werror`), built against our ROOT 6.42.00 (cxx23, Python 3.14) so
  the Amaru stack can move to 6.42. conda-forge can't build that until it has
  ROOT 6.42. `variants.yaml` pins spdlog, fmt and libboost-devel to the Amaru
  lock files' versions, because the free solve picks incompatible ones without
  conda-forge's global pinning. Only the latest phlex is built: with strict
  channel priority this hides conda-forge's phlex on both platforms, so an
  environment still on ROOT 6.40 can no longer solve a phlex. Drop it once
  conda-forge has phlex built against ROOT 6.42.
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
- **root 6.42.00** (`recipes-manual/root`, linux-64 and linux-aarch64; 6.40.04
  also on the channel): root-feedstock's recipe at `fedfe95`, moved to 6.42.00
  ahead of conda-forge and built against our pythia8. conda-forge's
  `root_base` links 8.312, and its `EGPythia8` C++ module embeds the 8.312
  headers. With our 8.318 in the environment, `libEGPythia8` fails to load
  (missing `Pythia8::HadronLevel::moreDecays`). Worse, cling takes the Pythia8
  declarations from that module, so PyROOT reads Pythia8 members at 8.312
  offsets: `particleData.m0(211)` returns 0.0. `variants/` holds the
  feedstock's `.ci_support` files with `pythia8` changed (and the smithy-only
  `channel_sources`/`channel_targets` dropped, which clash with `--channel`); the recipe
  adds `test_egpythia8.py`, which checks that cling's Pythia8 view matches
  the library. The build is too big for GitHub runners. Run `pixi run
  build-root` on a large linux-64 build machine and upload `output/` by hand.
  linux-aarch64 is cross-compiled there, through the feedstock's own
  cross-compilation path (the one conda-forge uses for ppc64le). Its tests
  need qemu-user registered with binfmt_misc and `QEMU_LD_PREFIX` set to an
  aarch64 glibc sysroot (from `sysroot_linux-aarch64`). Without them, set
  `NO_TEST=1`. The recipe isn't under `recipes/`, so `build-all` and CI skip
  it.

  6.42 moves cling to LLVM 22, and conda-forge has no `clangdev` with ROOT's
  patches for it yet (`root_64200`, in draft
  [clangdev-feedstock#517](https://github.com/conda-forge/clangdev-feedstock/pull/517)).
  Build that PR's `linux_64_variantroot_64200` and, cross-compiled,
  `linux_aarch64_variantroot_64200` into a local channel and pass it as
  `EXTRA_CHANNEL=file://...`. The PR (at `eb62367`) needs one fix first: its
  `build.sh` lost the 20.x branch's `root*`-variant sed that sets
  `LLVM_LINK_LLVM_DYLIB no` in `LLVMConfig.cmake` before clang is configured.
  Without it the static clang targets link the LLVM dylib, so rootcling links
  LLVM twice and aborts with "Option 'W' registered more than once". Only the
  build needs clangdev: `root_base` links clang statically and depends on
  conda-forge's unpatched `libllvm22` at runtime. Don't upload the clangdev
  builds. On the ship channel they would hide every conda-forge clangdev.

  Of the feedstock's patches, 0005, 0006, 0014, 0015 and 0017 are upstream in
  6.42 and have been dropped; 0003, 0004, 0007 and 0011 have been rebased.
  `build_root.sh` gains three 6.42 changes. civetweb, JSROOT and MathJax are
  no longer bundled, so it enables their builtins (civetweb isn't on
  conda-forge, and without JSROOT the web GUI loads it from root.cern at
  runtime). When cross-compiling, it first builds a native `cppinterop-tblgen`
  and passes it as `CPPINTEROP_TABLEGEN_EXE`, because CppInterOp otherwise
  calls the tool by bare name in builds that count as cross-compiling. Both
  versions also set `check_connection=OFF`: the configure-time probe fetches a
  file from root.cern that now answers 403, while the downloads themselves come
  from lcgpackages.

  Strict channel priority hides all of conda-forge's builds of `root_base`
  and `root` on every platform where we upload one, so a missing variant
  makes a solve fail instead of falling back. `variants/` holds only the
  variants SHiP uses: Python 3.13 with both C++ standards (FairShip) and
  Python 3.14 with C++23 (the aegir stack) on linux-64, and Python 3.14 with
  both C++ standards on linux-aarch64 (the aegir stack, plus genie and
  rootegpythia6, which CI builds in both standards). Add a variant file
  before a consumer moves to another Python. The 6.40.04 builds stay on the
  channel for the consumers that still pin it: all eight feedstock variants
  on linux-64, and the two aarch64 ones. Don't upload the noarch
  `root_cxx_standard` marker: it is identical to conda-forge's and would
  shadow it on every platform. That also means a ROOT upgrade
  (`variant-drift` PR) needs this rebuilt at the new version first.
  osx-arm64 still uses conda-forge's ROOT, whose PyROOT Pythia8 view is wrong
  there too.

The ship channel comes first and solves use strict channel priority, so while
our pythia8 is on the channel, no solve sees conda-forge's. Once conda-forge
ships pythia8 8.318 (and evtgen built against it):

1. Delete `recipes/pythia8` and `recipes/evtgen` and their table rows.
2. Delete the ship-channel pythia8 and evtgen builds with the prefix.dev
   delete API. A UI yank isn't enough: the builds stay in the repodata and
   keep shadowing conda-forge.
3. Refresh the downstream lockfiles (FairShip, aegir) straight away. Until
   then they point at the deleted builds and fail to install; refreshing
   before the delete doesn't help, because strict priority still picks the
   ship-channel builds while they exist.

It has to be 8.318 itself. Our ROOT builds stay on the channel (see below)
and link 8.318, and Pythia doesn't keep ABI between releases, yet the
`pythia8 >=8.318,<8.400.0a0` run_export would accept any later 8.3. If
conda-forge has moved past 8.318 by then, rebuild ROOT, and anything else
here that links pythia8, against its version first, and tighten the pin.

ROOT has to wait until conda-forge ships 6.42 as well, with its 6.40.04 and
6.42 builds linking that pythia8. phlex, shipdatamodel, field-service and
shannon need 6.42, which only the ship channel has today, and while any of
our `root_base` builds is on the channel, strict priority hides all of
conda-forge's. So the 6.40.04 and 6.42.00 builds go together: delete
`recipes-manual/root` and its table row, delete the ship-channel root_base
and root builds the same way, then refresh the lockfiles. Consumers need no
rebuild, since their `root_base` pins accept conda-forge's 6.40.04 and
6.42.00.

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

### Geant4 version (`global-variants.yaml`)

`global-variants.yaml` also pins `geant4`, so every recipe that lists `geant4`
in `host:` is built against the same release, and geant4's `run_exports` pin
the packages to it at runtime. Without the pin each recipe takes whatever its
other dependencies allow. That left fairroot and fairship on 11.4.2 (held back
by geant4-vmc) while aegir, trout and shipgeometryservice moved to 11.4.3, and
the two halves could not be installed together. Moving the pin is a physics
change, so do it on purpose: first check that conda-forge has geant4-vmc, vgm
and geomodel builds for the new version, then bump `build.number` in every
recipe that lists `geant4` in `host:`.

The nightly builds don't follow on their own: `nightly-main.yml` skips a
library commit that is already on the nightly channel, and moving the pin
changes no library commit. Once the stable packages are published, run
`nightly-main.yml` by hand with `force` for each nightly library that lists
`geant4` (shipgeometryservice and field-service), and check that the
consumers' main-deps jobs solve with the new builds.

### Platforms

Everything is built for linux-64. The Amaru stack is also built for
linux-aarch64: aegir, aegir-genie, shannon, trout, shipdatamodel,
shipgeometry, shipgeometryservice, field-service, mp-units, and the GENIE
chain (genie, pythia6, pythia8, rootegpythia6). osx-arm64 is planned. `build.yml` runs
one native job per platform (`platforms` in the shared rattler-build
workflow), `nightly-main.yml` does the same for each library, and the aegir
dev builds run on both runners.

The FairShip stack (fairship, fairroot, evtgen, geant3, genfit, photospp)
and npdb-client stay linux-64 only. Their recipes skip every other platform
with `target_platform != "linux-64"`, so a `--recipe-dir` build on an arm64
runner leaves them out. noarch recipes need no skip. Each CI job builds the
noarch packages it needs, and only the linux-64 job uploads them.

Recipes request the sysroot as `if: linux` / `then: sysroot_${{ target_platform
}} 2.17.*` instead of `${{ stdlib('c') }}`. `stdlib('c')` would add
`c_stdlib` and `c_stdlib_version` to the hash of every compiled package and
force a rebuild of the whole channel on linux-64.

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
- `root_base` must be pinned explicitly as well. A bare
  `root_base` host spec resolves, under `root_cxx_standard` 23, to the legacy
  pre-cxx-split `root_base` 6.36.06 — that build declares no
  `root_cxx_standard` dependency, so it spuriously satisfies the C++23 marker
  and the solver prefers it. Pinning keeps every recipe on the same ROOT
  series, as conda-forge's global `root_base` pin does. Two series are
  current. The FairShip stack (fairroot, fairship, geant3, genfit, photospp)
  pins `6.40.04`, because conda-forge's vmc, vgm and geant4-vmc are only built
  against 6.40. The Amaru stack is on our `6.42.00` (shipdatamodel and phlex
  pin it). genie and rootegpythia6 serve both and list both values, so each
  is built against each. `recipes-dev/phlex` is not part of the lockstep: it
  keeps its own series pin (`6.42`), matched to the Amaru stack's lock files.

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
channel. `ci/check-variant-lockstep.py` enforces that at review time: every
`root_base` value a recipe pins must be among the values of each ROOT-linking
recipe in its `host:`. It runs as a prek hook and needs no network access.
While genie and rootegpythia6 list two values, the channel-drift check treats
`root_base` as a build matrix and opens no `variant-drift` PR for it; ROOT
upgrades go through `recipes-manual/root` first anyway.

For packages whose upstream build system sets no explicit C++ standard
(photospp's autotools, GENIE's perl configure — both inherit ROOT's standard
via `root-config`), there is no compile flag to drive; the variant only makes
the ROOT build they link against deterministic.

The C++23-only aegir stack (aegir, aegir-genie, field-service, shannon,
trout) builds a single variant and constrains ROOT in `host:` instead —
`root_base` plus `root_cxx_standard ==23` — which equally excludes the
legacy 6.36.06 build. All of them require `>=6.42`.
rootegpythia6 builds both C++ standards and both ROOT series in
`variants.yaml`, covering fairship (6.40.04) and genie (both), which link
against it.

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
  shipgeometryservice also lists the three in `run:`, because its own CMake
  config finds Geant4: packages and pixi environments that get Geant4 only
  through it would otherwise have to know about the workaround.
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

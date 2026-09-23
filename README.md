# ship-conda-recipes

Conda recipes for SHiP experiment packages not available on conda-forge.

Built with [rattler-build](https://prefix-dev.github.io/rattler-build/) and hosted
on a [prefix.dev](https://prefix.dev) channel.

## Packages

| Package | Upstream candidate? |
|---------|---------------------|
| acts-ship | No (SHiP fork of conda-forge `acts-core`) |
| aegir | No (SHiP-specific) |
| aegir-genie | No (SHiP-specific, links GPL GENIE) |
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
| pythia6 | No (SND-LHC fork) |
| random123 | Yes (conda-forge feedstock) |
| rootegpythia6 | No (niche) |
| shannon | No (SHiP-specific) |
| ship-ci-metrics | No (SHiP-specific) |
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

## Recipe conventions

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
- `root_base` must be pinned explicitly as well (currently `6.40.2`). A bare
  `root_base` host spec resolves, under `root_cxx_standard` 23, to the legacy
  pre-cxx-split `root_base` 6.36.06 — that build declares no
  `root_cxx_standard` dependency, so it spuriously satisfies the C++23 marker
  and the solver prefers it. Pinning keeps every recipe on the same ROOT
  series, as conda-forge's global `root_base` pin does. Bump all
  `variants.yaml` in lockstep when conda-forge moves ROOT past 6.40.2.

Because `root_base` is pinned by us rather than tracked to conda-forge, a
rebuild reproduces the same pin — so the channel-drift check reports it apart
from genuine stale pins and never bumps `build.number` for it. When conda-forge
moves past the pin, the check opens a separate `variant-drift` PR advancing it
across every `variants.yaml` at once. That PR is a real ROOT upgrade rather than
a routine refresh, so review it on its own merits. No `build.number` bump
accompanies it: changing a variant changes the build hash, so the build string
is new and `--skip-existing` will not skip the rebuild. Every ROOT-linking
recipe carries the pin, rootegpythia6 included: fairship and genie list
rootegpythia6 in `host:` and pin `root_base` themselves, so a rootegpythia6
left to float to conda-forge's current ROOT either makes their host env
unsolvable or sends the solver back to a pre-`root_base` build from the
channel. `ci/check-variant-lockstep.py` enforces that at review time; it runs
as a prek hook and needs no network access.

For packages whose upstream build system sets no explicit C++ standard
(photospp's autotools, GENIE's perl configure — both inherit ROOT's standard
via `root-config`), there is no compile flag to drive; the variant only makes
the ROOT build they link against deterministic.

The C++23-only aegir stack (aegir, aegir-genie) builds a single variant and
constrains ROOT in `host:` instead — `root_base >=6.40` plus
`root_cxx_standard ==23` — which equally excludes the legacy 6.36.06 build.
rootegpythia6 builds both variants and pins `root_base` in `variants.yaml`, in
lockstep with fairship and genie, which link against it.

### Known upstream workarounds

Workarounds carried by several recipes at once are documented here; the
recipes carry a one-line pointer. Single-recipe workarounds keep their full
rationale inline next to the pin. Each entry states the condition under which
it can be dropped.

- **`eigen-abi-devel` in `host:`** (aegir, aegir-genie, shipgeometry,
  shipgeometryservice): `GeoModelCoreConfig.cmake` does
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
- **`nlohmann_json` in `host:`** (same four recipes):
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
  aegir-genie, shipgeometryservice, field-service): conda-forge geant4 is
  built with `GEANT4_USE_SYSTEM_EXPAT=ON`, `GEANT4_USE_SYSTEM_ZLIB=ON` and
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
    --channel https://prefix.dev/ship --channel conda-forge
```

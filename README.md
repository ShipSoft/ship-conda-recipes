# ship-conda-recipes

Conda recipes for SHiP experiment packages not available on conda-forge.

Built with [rattler-build](https://prefix-dev.github.io/rattler-build/) and hosted
on a [prefix.dev](https://prefix.dev) channel.

## Packages

| Package | Version | Upstream candidate? |
|---------|---------|---------------------|
| acts-ship | 0.0.0.dev20260608+fcf8bbe | No (SHiP fork of conda-forge `acts-core`) |
| aegir | 0.1.0 | No (SHiP-specific) |
| aegir-genie | 0.1.0 | No (SHiP-specific, links GPL GENIE) |
| fairroot | 19.0.1 | No (carries patch) |
| fairship | 26.06 | No (SHiP-specific) |
| ganga | 8.7.12 | No (HEP-specific, not in conda-forge today) |
| geant3 | 4.5 | Yes |
| genfit | 2.3.0 | Yes |
| mp-units | 2.5.0 | Yes (conda-forge feedstock) |
| npdb-client | 0.3.0 | No (SHiP-specific, split recipe with `python-npdb-client`) |
| photospp | 3.64 | Yes |
| pythia6 | 6.4.28 | No (SND-LHC fork) |
| random123 | 1.14.0 | Yes (conda-forge feedstock) |
| rootegpythia6 | 0.1 | No (niche) |
| shipdatamodel | 0.1.0 | No (SHiP-specific) |
| shipgeometry | 0.2.0 | No (SHiP-specific) |
| shipgeometryservice | 0.1.0 | No (SHiP-specific) |

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

For packages whose upstream build system sets no explicit C++ standard
(photospp's autotools, GENIE's perl configure — both inherit ROOT's standard
via `root-config`), there is no compile flag to drive; the variant only makes
the ROOT build they link against deterministic.

The C++23-only aegir stack (aegir, aegir-genie) builds a single variant and
constrains ROOT in `host:` instead — `root_base >=6.40` plus
`root_cxx_standard ==23` — which equally excludes the legacy 6.36.06 build.
rootegpythia6 builds both variants but likewise uses a `root_base >=6.40`
floor in `host:` rather than a variant pin.

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

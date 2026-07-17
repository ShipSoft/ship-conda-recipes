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

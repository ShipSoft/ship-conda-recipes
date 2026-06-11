# ship-conda-recipes

Conda recipes for SHiP experiment packages not available on conda-forge.

Built with [rattler-build](https://prefix-dev.github.io/rattler-build/) and hosted
on a [prefix.dev](https://prefix.dev) channel.

## Packages

| Package | Version | Upstream candidate? |
|---------|---------|---------------------|
| aegir | 0.1.0 | No (SHiP-specific) |
| fairroot | 19.0.1 | No (carries patch) |
| fairship | 26.05.7 | No (SHiP-specific) |
| ganga | 8.7.12 | No (HEP-specific, not in conda-forge today) |
| geant3 | 4.5 | Yes |
| geant4-vmc | 6.8 | Yes |
| genfit | 2.3.0 | Yes |
| geomodel | 6.27.0 | Yes (ATLAS-maintained, candidate for conda-forge) |
| gsl-lite | 1.1.0 | No (newer than conda-forge) |
| mp-units | 2.5.0 | Yes (conda-forge feedstock) |
| phlex | 0.2.0 | No (Framework-R-D, not yet on conda-forge) |
| photospp | 3.64 | Yes |
| pythia6 | 6.4.28 | No (SND-LHC fork) |
| random123 | 1.14.0 | Yes (conda-forge feedstock) |
| rootegpythia6 | 0.1 | No (niche) |
| shipdatamodel | 26.06.0 | No (SHiP-specific) |
| shipgeometry | 0.1.0 | No (SHiP-specific) |
| shipgeometryservice | 26.06.0 | No (SHiP-specific) |
| vgm | 5.4 | Yes |
| vmc | 2.2 | Yes |

### Upstreamed to conda-forge

Previously packaged here, now consumed directly from conda-forge:

- [FairLogger](https://github.com/conda-forge/fairlogger-feedstock)
- [FairCMakeModules](https://github.com/conda-forge/faircmakemodules-feedstock)
- [cetmodules](https://github.com/conda-forge/cetmodules-feedstock)
- [libjsonnet](https://github.com/conda-forge/libjsonnet-feedstock)

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

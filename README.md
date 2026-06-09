# ship-conda-recipes

Conda recipes for SHiP experiment packages not available on conda-forge.

Built with [rattler-build](https://prefix-dev.github.io/rattler-build/) and hosted
on a [prefix.dev](https://prefix.dev) channel.

## Packages

| Package | Version | Tier | Upstream candidate? |
|---------|---------|------|---------------------|
| pythia6 | 6.4.28 | 0 | No (SND-LHC fork) |
| ganga | 8.7.12 | 0 | No (HEP-specific, not in conda-forge today) |
| gsl-lite | 1.1.0 | 0 | No (newer than conda-forge) |
| mp-units | 2.5.0 | 0 | Yes (conda-forge feedstock) |
| random123 | 1.14.0 | 0 | Yes (conda-forge feedstock) |
| vmc | 2.2 | 1 | Yes |
| vgm | 5.4 | 1 | Yes |
| rootegpythia6 | 0.1 | 1 | No (niche) |
| genfit | 2.3.0 | 1 | Yes |
| photospp | 3.64 | 1 | Yes |
| shipdatamodel | 26.06.0 | 1 | No (SHiP-specific) |
| geant3 | 4.5 | 2 | Yes |
| geant4-vmc | 6.8 | 2 | Yes |
| shipgeometry | 0.1.0 | 2 | No (SHiP-specific) |
| fairroot | 19.0.1 | 3 | No (carries patch) |
| shipgeometryservice | 26.06.0 | 3 | No (SHiP-specific) |
| aegir | 0.1.0 | 4 | No (SHiP-specific) |

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

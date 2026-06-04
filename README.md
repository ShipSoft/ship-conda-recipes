# ship-conda-recipes

Conda recipes for SHiP experiment packages not available on conda-forge.

Built with [rattler-build](https://prefix-dev.github.io/rattler-build/) and hosted
on a [prefix.dev](https://prefix.dev) channel.

## Packages

| Package | Version | Tier | Upstream candidate? |
|---------|---------|------|---------------------|
| faircmakemodules | 1.0.0 | 0 | Yes |
| pythia6 | 6.4.28 | 0 | No (SND-LHC fork) |
| vmc | 2.2 | 1 | Yes |
| vgm | 5.4 | 1 | Yes |
| rootegpythia6 | 0.1 | 1 | No (niche) |
| genfit | 2.3.0 | 1 | Yes |
| photospp | 3.64 | 1 | Yes |
| geant3 | 4.5 | 2 | Yes |
| geant4-vmc | 6.8 | 2 | Yes |
| fairroot | 19.0.1 | 3 | No (carries patch) |
| ganga | 8.7.12 | 0 | No (HEP-specific, not in conda-forge today) |

## Building

```bash
pixi install
pixi run build-<package-name>
```

Packages must be built in tier order (0 → 1 → 2 → 3).

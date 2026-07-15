# Archive brand assets

Archive's launcher identity is a flowing capital A with a two-wave crossbar. The line moves through the app's four metric colors in their established order:

1. Habit pink: `#FFC5D3`
2. Sleep purple: `#C9A0DC`
3. Water blue: `#A2BFFE`
4. Move green: `#E5F9E4`

The final green endpoint represents the latest point in the archive. The charcoal field is `#1D1D1F`.

- `archive-icon.svg` is the full production source.
- `archive-icon-foreground.svg` is the transparent adaptive-icon layer.
- `archive-icon-1024.png` and `archive-icon-foreground-1024.png` are generated master rasters.
- `scripts/generate-launcher-icons.ps1` regenerates Android legacy, round, and adaptive launcher assets at every required density.

Do not edit generated PNGs individually. Change the shared geometry and generator together, then regenerate all densities.

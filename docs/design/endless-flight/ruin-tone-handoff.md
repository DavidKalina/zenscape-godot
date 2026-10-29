# Ruin tone: handoff

The Amberlands' ruins were a warm gold that matched the grass. The user
picked basalt from five tones rendered side by side (amber, basalt, slate,
limestone, sandstone).

## What changed

- **Ruin tones** (`scripts/endless/land_arches.gd` `TONES`, `tone_lift()`):
  each tone is the albedo lift over the kit's dark stone. The world
  profile's `ruin_tone` layer picks one, and `--ruin-tone=NAME` overrides
  it.
  - Set pieces, bridges and land arches take the tone (`land_arches`),
    and so do halls (`land_halls`).
  - Tunnel stone takes it lifted less, by the same share as before
    (`land_tunnels` `_dark_materials`).
  - Under `amber` everything is exactly as before.
- **Moss on tops for every set piece**: the profile's `set_moss` layer
  (`tops`), overridable with `--set-moss=tops|full`. Without this, the
  gothic pieces' full moss covered the stone in grass-coloured olive, and
  no stone tone could show through.
- **The Amberlands** (`scripts/endless/world/amberlands/look.gd`):
  `"ruin_tone":"basalt","set_moss":"tops"`. The other worlds keep amber
  and full moss.

## Checks

- Smoke PASS, 0 errors: default, `--world=amberlands`, `--world=regions`.
- Stills: `scratch/audit/tones_*.png` (the five tones),
  `scratch/audit/basalt_sheet.png` (the defaults, no flags).

## Open

- `--world=regions`: this round didn't check which tone the
  Amberlands-like regions get there (it depends on what the regions'
  current profile answers for `ruin_tone`).
- A far tunnel portal seen from about 1 km still read pale at its front,
  and its carved-rock hood is warm (rock, not ruin stone). Not traced.
- Basalt in shaded arches picks up a little blue from the sky fill.

# Handoff: more wind in the grass by default (polish round, wind lane)

Ask: "Grass looks great, but relatively inert most of the times. More wind by default?"

## What changed

The floor is on the plants only, in how the field's strength maps to what the
plants show. The field (`WindField.wind_at`, `zs_wind_strength`) is unchanged.

- `scripts/endless/wind_field.gd`: new `plant_wind(w) = 0.65 + sqrt(w)`
  (`PLANT_FLOOR`, `PLANT_RISE`). `breeze_of` and `swell_of` now take
  `plant_wind(w)` where they used to take `w`. The floor turns off with
  `--grass-wind=old` and in fixed mode (`--wind=X`, where the plants show X as
  before).
- `shaders/wind_field.gdshaderinc`: `zs_wind_plant` is the same map. It is on
  when `zs_wind_field.w` is 2, which EndlessLook publishes while the floor is on
  (1 = old). The shader's `zs_wind_breeze_of` and `zs_wind_swell_of` use it, and
  so does the new `zs_wind_plant_local_here`.
- `shaders/endless_ground.gdshader`: the ground paint's grass crests (the
  rolling sheen) read the plants' wind instead of the field's strength.
- `scripts/endless/endless_look.gd`: inside the field's land, the air's travel
  for `zs_gust_distance` and `zs_sheen_distance` uses the plants' wind, so the
  meadow waves roll at a pace that matches the lean. `drift` keeps the field's
  own.

### Why the floor goes in this map and not elsewhere

The field's strength is shared. The sea, lake chop, foam, cat's paws, sound,
eddies, flags and spray all read it. Raising DAY, SHELTER or the calm temper
would have made the water and sound windier too, which risks a stormy sea on a
calm morning. A floor plus a square root in the plant map gives every place and
hour visible motion. It also keeps the order: a hollow sways less than a ridge,
dawn less than afternoon, a calm day less than a gusty one. The square root
squeezes the field's 0.01 to 2.5 range into 0.7 to 2.2. Most of the day sits
under 0.3, where the old linear map left the plants still.

## Numbers (seed 1, from scratch/wind/numbers.gd)

For comparison, fixed wind gives these breezes: 0.9 gives 0.69, 1.3 gives 0.97,
2.0 gives 1.46.

Each cell shows `w`, then the breeze before → after. Old swell was 0 in every
row below 0.25. New swell is 0.75 to 1.0.

| temper | hour | sheltered meadow (720,500) | forest hollow (330,-150) |
|---|---|---|---|
| calm | 6 | 0.018: 0.07 → 0.61 | 0.005: 0.06 → 0.57 |
| calm | 14.5 | 0.30: 0.27 → 0.90 | 0.09: 0.12 → 0.72 |
| breezy | 6 | 0.034: 0.08 → 0.64 | 0.010: 0.07 → 0.59 |
| breezy | 8.6 (title) | 0.17: 0.18 → 0.80 | 0.05: 0.10 → 0.67 |
| breezy | 14.5 | 0.57: 0.46 → 1.04 | 0.17: 0.18 → 0.80 |
| breezy | 21 | 0.05: 0.10 → 0.67 | 0.015: 0.07 → 0.60 |
| gusty | 8.6 | 0.25: 0.23 → 0.86 | 0.07: 0.11 → 0.71 |
| gusty | 14.5 | 0.84: 0.65 → 1.16 | 0.25: 0.24 → 0.87 |

At the extremes, a fully exposed ridge inside a patch on a gusty afternoon is
about w 2.5, giving breeze 1.62, more than fixed wind 2. The dimmest place is a
hollow at dawn on a calm day, about breeze 0.57, roughly fixed wind 0.73.

Live title readings: `look.wind_here()` is 0.09 under both mappings (the field
is unchanged), which gives breeze 0.12 old and 0.73 new. In the low meadow it is
0.15 under both.

## A/B flag

`--grass-wind=old` restores the old mapping. Example:
`.\run-endless-flight.cmd --grass-wind=old`.

## What each CPU reader gets now

- The plane: unchanged. Nothing in its forces reads the field. Its wind comes
  only from the telegraphed features (`sky_currents`, `sky_world`, `trap`
  through `manual_landing`).
- `WindField.wind_at` and its users: unchanged. That covers `look.wind_here()`
  (and so the flight sound), `zs_wind_strength`, eddies (`endless_eddies`), the
  wind map, `look.drift` (motes) and `look.wind_direction` (clouds, balloons,
  weather, snow, motes).
- `zs_breeze` (published from `breeze_of`): raised. Only shaders read it
  (grass, flowers, trees, ruin growth, dust).
- `look._gust` (`zs_gust_distance`): runs about 2x faster in calm air. At w 0.08
  it moved 0.55 x AIR_SPEED and now moves 1.12 x. Above w 1.3 it is unchanged
  (capped). Two things notice this:
  - `grass_react` gets it as `travel`. That file belongs to another lane; I did
    not edit it.
  - The sea's cat's-paw patches drift faster on calm days. Their strength is
    unchanged.

## Proof

- `python tools/smoke.py studies/endless_flight.tscn`: PASS, 0 errors.
- Rendered stills of meadow_low, sun_away_low, coast, river and cruise, before
  (`--grass-wind=old`) and after, at the default hour (title 8.6) and at hours
  6, 14.5 and 21. All are in `scratch/wind/`, with side-by-side sheets
  `sheet_{default,h6,h14,h21}.jpg` (left is old).
  - The near grass and flowers lean in every view.
  - The far meadow paint shows rolling crests.
  - The sea, coast and lakes look the same in both.
- Motion: two meadow stills a second apart (`scratch/wind/meadow_{new,old}_{a,b}.png`,
  frame difference in `meadow_*_diff.png`). The lower-half mean frame
  difference is 24.4 new vs 17.5 old. Blades, far grass and spruce tops all
  move more.
- Title (`--title`, 240 frames): `scratch/wind/title_new.png` and
  `title_old.png`. The new grass is combed over and the flowers tip.

## Tests

None pin these numbers. I didn't run the suite, and no test is known to break.
There is no native twin of `wind_field.gd`.

## Unverified

- No one has played it, and the motion is judged from pairs of stills, not
  watched.
- At 14.5 on a breezy day (breeze 1.04), the near grass lays over about as far
  as fixed wind 1.4. If that reads too windy, lower `PLANT_RISE`. To change the
  floor itself, change `PLANT_FLOOR`. Change the GDScript constants and the
  shader constants together.
- I didn't check the Amberlands half of the doors world. Past the bake's reach
  everything falls back to the world's own wind, so it should be unchanged.
- I didn't check the faster cat's paws on the sea in motion.

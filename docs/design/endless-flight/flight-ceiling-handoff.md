# Flight ceiling round: handoff

The plane can now climb well over the tallest land, and the climb gets
slow near the top. The far land's haze now meets the sky cleanly when seen
from high up. No mountain was built in this round.

## What capped height before

- `plane.ceiling_y = SEA_Y + CEILING_OVER`, with `CEILING_OVER = 215`
  (`scripts/endless/land_field.gd`, set in `studies/endless_flight.gd`
  `_launch`). Above it, `SkyPlane.step` pushed the nose limit down to
  level (`CEILING_NOSE`) over `CEILING_FADE` (25 m). There was no other
  cap: no thrust or lift falloff, no camera clamp, and the world did not
  break above it.
- The climb under the cap worked like a lift. At full back plus Boost the
  speed only dropped by `SWING/THROTTLE x climb`, about 7 m/s, so the
  plane rose at 25 to 40 m/s.
- Measured through the play loop (`scratch/ceiling.gd`, air start 163 m
  over the sea, seed 1, full back plus Boost). The plane stopped at 239 m
  over the sea for off, light and medium, and 246 m for heavy (it
  overshoots). It got there 3 to 4.3 s after the stick was pulled.
- The tallest land in reach (a 24 km square round the start) was 245 m
  over the sea on seed 1, and 257, 292, 280 and 310 m on seeds 2 to 5.
  So the highest peaks stood above the old ceiling.

## What changed

**Thin air** (`scripts/sky_plane.gd` `use_thin`, `top_y`, the THIN_*
constants). Up to `THIN_OVER` (215 m over the sea, the old ceiling) the
flight is unchanged; every new term is exactly 0 there. Above it, `thin`
rises from 0 to 1 at the preset's top, and:

- the climb costs up to `THIN_SWING` (12) times more speed, scaled by the
  square root of `thin`;
- the engine pulls the speed back toward its target `THIN_PULL` (60 %)
  less;
- the nose comes up no further than the best sustained climb at that
  height, eased over 0.4 s. That angle is `asin(target x pull / (2 x
  cost))`: near 69 degrees low in the band and about 7 degrees at the
  top. Holding full back therefore gives the best climb, at about half
  the speed;
- when slow (in the soft band), the plane sinks up to `THIN_MUSH`
  (3 m/s) more;
- over the band's last 15 % (`TOP_FALL`), the climb fades from 10 m/s to
  nothing.

Dives are not affected: the climb cost only applies to climbing. The old
nose fade still sits at `ceiling_y` as a backstop.

**Tops** (`CEILING_OVER = 760` m over the sea, and the FlightWeight
`ceiling` knob, which is the share of the thin band a preset climbs
through):

| preset | ceiling knob | top (m over sea) |
|---|---|---|
| off | 1.0 | 760 |
| light | 1.0 | 760 |
| medium | 0.94 | 727 |
| heavy | 0.85 | 678 |

`--ceiling=m` still sets the top. At 215 m or below it turns thin air off
and gives the old ceiling. `--old-land` also gives the old ceiling.

**Sky** (`shaders/reference_sky.gdshader` `ground_horizon`, set to 1 by
`EndlessLook`). On screen, the dome below the horizon now keeps the
horizon's colour, which is the colour the land's depth fog fades to.
Before, from 700 m with view 1, the hazed land's far edge (147,195,233)
met a darker band of sky below the horizon (130,173,206). That band is
gone. The radiance map, and so the light on the land, is unchanged.

## Numbers after (full back from the 163 m air start, seed 1)

Time to reach each height (m over the sea). "Stall-out" is the last time
the plane gained 0.05 m in 12 s.

| preset | Boost: 400 / 500 / 600 / 700 | top, stall-out | no Boost: 600 / 700 | top, stall-out |
|---|---|---|---|---|
| off | 11.6 / 22.4 / 37.2 / 57.6 s | 760, 115 s | 91 / 141 s | 760, 226 s |
| light | 11.7 / 22.6 / 37.4 / 57.8 s | 760, 126 s | 91 / 142 s | 760, 226 s |
| medium | 12.3 / 23.7 / 39.6 / 61.9 s | 727, 112 s | 96 / 151 s | 727, 208 s |
| heavy | 13.2 / 25.7 / 43.6 s / not reached | 678, 100 s | 106 s / not reached | 678, 188 s |

A medium climb with Boost goes like this: speed falls from 57 m/s to about
28 m/s, and the pitch eases from 1.2 rad to 0.12 rad. Climb rate is
13 m/s at 435 m, 6 m/s at 600 m and 3.5 m/s at 700 m, then fades out.
Every preset climbs past 620 m, twice the tallest land measured.

**Low band.** The low-band script (cruise, full turn, level, pull, push,
Boost, Boost turn) gives identical results before and after: 32 phase
rows, every speed, turn, height change and pitch the same to the digit.

I also ran climb, dive and back down to about 100 m over the sea before
the same script. Every phase matched the fresh run within 0.12 m/s with
identical turn angles. The only exception is the first settle phase, which
is +1.6 m/s from the dive's leftover speed.

## How to feel it

`.\run-endless-flight.cmd`, hold back and Boost. You go up fast to about
215 m over the sea as before. Above that, the nose lowers itself, the
speed drops to about half, and the climb slows over a minute or so until
it stops at the top. Push the nose down and the height turns straight
back into speed. Press V to cycle the presets: heavy tops out about 80 m
under light.

## Still open at height

- **Land LOD has no geomorphing.** LOD is picked by 3D distance from the
  eye, so a climb coarsens every ring at once. I judged this only in
  stills; popping in motion is unverified.
- **Faint far edge at view 1.** At view 1 (the low-end default), the far
  land's fogged mountain silhouettes still read faintly darker than the
  sky behind them. The dark band is gone.
- **High wind sound.** It is full by 215 m (`flight_sound.gd`
  THIN_HEIGHT) and does not change above.
- **No altimeter on the HUD.**
- **At the very top.** Holding full back there flies level at about
  28 m/s with the nose 7 degrees up.
- **Unverified headless.** All the look checks are rendered stills
  (`scratch/shots`, Windows, Forward+, at 330 m and 700 m over the sea,
  views 1 and 2, `--cloud-cover=1.6`), not a film. From above, the cloud
  layer and the camera showed no breaks.

## Tests

The smoke check of `studies/endless_flight.tscn` passes. These pass
headless: test_sky_plane, test_knife_drift, test_glide_camera,
test_world_scale_guard, test_flight_metrics, test_flight_study and
test_sky_painted_ridges. I know of no test that breaks.

## For the tall-mountain round

- **Height clamps.** The land height has no clamp
  (`LandField.height`). The plane reaches 678 to 760 m over the sea
  depending on the preset; raise `CEILING_OVER` (and so every preset's
  top) if the summit sits higher than about 600 m. The climb from 215 m
  up to about 600 m with Boost takes 30 to 45 s.
- **LOD near high ground.** `LandStream._distance` measures height from
  `SEA_Y + 20`, not from the ground under the chunk. Skimming ground at
  height H therefore gets the LOD of an eye H m up. On today's 300 m
  peaks that means 4 m quads near the plane instead of 1 m. On a 650 m
  summit it would mean 8 m quads, which a landing at the summit lake
  would show. Measure `dy` from the chunk's ground: a cached min height
  per chunk, or one field sample at the chunk's nearest point.
- **Fog.** Depth fog is distance-only (begins 120 m, ends 7600 x view),
  with no height falloff. A far mountain's summit hazes out exactly as
  fast as its foot, and the haze doesn't thin with height. I haven't
  judged how a tall peak reads from far off.
- **Clouds.** The march's slab runs from the sea to 1250 m over the sea
  (`EndlessClouds.TOP`). Today's cumulus bases sit at 26 to 190 m over the
  sea, and their tops at up to about 450 m. A layer part way up the
  mountain is new work in the march's field (bases are measured over the
  sea, apart from the meadow lift).
- **Far plane.** The camera's far plane is `FOG_END x view x 1.04` (7.9
  or 15.8 km). The sea sheet reaches about 12.3 km round the eye.

# Handoff: wind motes (visual polish round, lane "particles")

Prototype round. Smoke check passed (native and `--native-react=0`), no tests
added.

## What was added (scripts/endless/endless_motes.gd)

A third swarm, **drift**: grass blades and flower petals lifted by the wind
itself, drawn as one MultiMesh (`WindDrift`, the kick's blade strip and
`shaders/grass_bit.gdshader`).

- **Puffs, not snow.** A puff picks a spot among slow gust patches rolling
  downwind with the air's travel (`_gusty`, CPU value noise shaped like
  `zs_gust_band_at`; it does not line up with the grass's own bands, whose GPU
  sine hash has no CPU match at world coordinates). Three spots tried, the
  gustiest kept, then kept only with that gust as its chance, so calm stretches
  stay empty. A puff lets 6-16 bits go over 0.5-1.4 s from a 2-4 m patch
  stretched along the wind.
- **Riding, then settling.** Each bit rises out of the grass, rides 1.8-3.8 m
  over the ground on a spring (bobbing), carried at 0.75-1.25 of the air's
  speed, tumbling, for 1.4-3.8 s. Then it lets go and falls, fluttering and
  rocking flat, exactly like a kicked bit. Its ground is a line along the wind
  (two probes per puff), so it follows a slope.
- **Petals.** A flower drift (EndlessPatch `bloom`, weight over 0.4-0.75)
  adds to a spot's draw, and that puff's bits are mostly petals, coloured with
  the drift's wash (`Patch.KINDS[kind][2]`). They're small, round and cupped
  (colour alpha 0.5 marks a petal for the shader) and fall at 0.3 of a blade's
  fall. The prop wash also throws petals instead of blades over a drift
  (`PETAL_WASH`, up to 55%).
- **Led ahead.** Flying fast, puffs line a corridor 6 m to 1.6 s of travel
  ahead (at most 70 m), ±14 m to the sides. Slow (the title), it's a 24 m disc.
  Rides and lives shorten with the eye's speed (`DRIFT_PASSED`), so the pool
  holds the ones ahead.
- **Wind and height.** Puffs per second = 1.7 · (air/6 m/s)^1.3 (k capped at
  2) · (1 + eye speed/5) · height fade (none from 40 m over the ground,
  thinning from 12 m).
- **Near fade (shader).** Any bit within 1.5-4.5 m of the camera shrinks
  away. The title's eye sits in the grass, where blades filled the screen.
  This also applies to the kick's bits.

Counts and caps: pool `DRIFT` 360 (oldest dropped), at most 18 puffs alive,
1 new puff a frame (3 land probes: grass, downwind ground, tint), 18 bits
born a frame. No probes per bit. `bloom` is called 3 times per puff try and
once per wash frame.

Measured counts (headless, low flight about 36 m/s, 6 s): `--wind=0.3`
peaks at 46 bits, `--wind=1.0` at 145, `--wind=2` at the 360 cap. At
Boost (about 57 m/s), `--wind=1.0` keeps about 50 bits on screen in the
chase view. At the title (still), 60-90.

Flags: `--no-wind-blades`, `--wind-blades=X` (the puff rate), `--no-petals`,
`--petals=X` (the petal share, drift and wash). Petals alone still puff over
drifts.

## Native

`ZenScapeMotes` v2 (native/terrain_kernels/flight_fx.h). The kick's loop
became `fly(pool, buf, ...)`, shared by the kick and the drift (`drift_add`,
`drift_step`, `drift_count`, `drift_records`). Bits gained ride, lift, carry,
fall and a ground slope, as an optional tail on the record (BIT_REC_DRIFT 38).
A kicked bit's numbers are unchanged. The GDScript twin is `_fly`.

- **Parity.** A scratch driver fed the same bits to both and stepped them 600
  frames: worst buffer difference 0.0.
- **Built here** (Windows, MSVC + SCons 4.8.1, godot-cpp copied to scratch),
  debug and release. **The binaries under native/terrain_kernels/bin are
  git-ignored: copy both `zenscape_kernels.windows.template_*.x86_64.dll` to
  the main checkout at merge. The Mac needs its own build.** With an old v1
  library, `native_wanted()` is false and all motes run in GDScript.

## Cost

| Measure | Result |
|---|---|
| Frame time, rendered `look_views` meadow_low, `--wind=1.0` | 7.72 ms on, 7.68 ms with `--no-wind-blades --no-petals` (noise level) |
| CPU of the drift step (`FrameLog` mark `m_drift`), headless driven flight at Boost about 3-5 m up, `--wind=1.0`, native | mean 0.12-0.16 ms, p95 0.31-0.48, worst 0.7-1.1 (single frames, under a parallel rendered run) |
| The same step in GDScript (`--native-react=0`) | mean 0.81 ms, p95 1.5 |

New marks `m_pollen`, `m_kick` and `m_drift` split the motes in a
`--frame-log`.

## Tests

None reference the motes, ZenScapeMotes or grass_bit. No known breakage.
The full suite was not run.

## Unverified

- **A hand flight.** Every flight here was driven in a straight line.
- **Petals against the drawn flowers: a known mismatch.** In the drift flight
  (`--at=640,470 --heading=0`, about 30 m before the cosmos drift), a puff of
  pink-red petals rises from grass with no drawn flowers under it. It does
  this even after gating petals to a drift's heart (`PETAL_EDGE`). So
  `EndlessPatch.bloom` reports a strong drift there that `endless_grass.gd`
  doesn't draw (thinned batches, a distance band, or the twins disagree). The
  cause wasn't found. The next round should compare `bloom` with the flower
  batches' own placement.
- **Other worlds.** Not checked on the amberlands or Peak worlds, or over
  snow (motes run there as before).
- **The Mac build** of the kernels.

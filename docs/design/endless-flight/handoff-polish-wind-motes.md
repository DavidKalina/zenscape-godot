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

## Follow-up: the "stray petal puff" (2026-11-14)

**Cause: it isn't motes.** The pink-red "puff" beside the plane about 30 m
before the cosmos drift (`--at=640,470 --heading=0 --alt=5 --wind=1.0`,
Boost, film from frame 110) is drawn flowers: a small crimson cosmos patch
(`bloom` kind 5, cosmos variant 0.4, a 15 m-layer drift centred near
(644, 346)). Seen from the chase camera at a grazing angle and at speed, its
flat heads on stems hidden by the grass read as petals in the air.

Evidence (scratch drivers, uncommitted):

- The same flight filmed with `--no-petals`, with `--no-motes` (no motes at
  all) and with the motes on gives the same red cluster. Saturated red pixels
  in the right half of frames 4-7: 446/954/2537/8096 with motes,
  449/953/2518/8059 with `--no-motes`. With `--no-motes --no-flowers`:
  1/2/5/4.
- A still from 14 m (camera of its own, same frame) shows about 40 crimson
  cosmos standing at that spot. The grass's flower batches hold 30 cosmos
  within 4 m of it.
- Every petal puff checked against the flower instances the grass really
  placed (its flower MultiMesh buffers, by kind, within 4 m of where the puff
  is born), in three flights: the lupine and cosmos drifts here, a kind-5
  cosmos and dandelion run (`--at=908,820 --heading=0`), and poppy, lupine,
  cosmos, daisy and buttercup (`--at=640,470 --heading=90`). 57 petal puffs,
  none over fewer than 16 flowers of their own kind (typically 40-130). Puffs
  over grass with no drift (`bloom` under 0.4) carry no petals. So (a) to (e)
  in the brief are ruled out for the motes. `bloom` matches the grass's
  placement, the offset convention agrees, and puffs are born where they're
  picked.
- What the motes do add: petals ride the wind. About 10% of petal samples sit
  over no flower of their kind, a median 8-13 m downwind of the patch they
  rose from. That's the intended ride, not a stray birth.

**Fix: none to the motes.** No code changed and native wasn't rebuilt, so the
drift step's cost is as measured above. Whether that small crimson patch
should look less like a cloud of petals from the chase camera is a flower or
look question for the user. It might mean fewer stray patches, shorter
stems, or flowers not drawn edge-on. This round didn't decide it. Petals are
off-limits to that question and the colour lane is changing the colour areas
right now.

**Seen in passing (unexplained).** The headless smoke of
`studies/endless_flight.tscn` fails now and then with three engine errors
("Initializing already initialized RID", "Parameter mem is null",
"unimplemented base type encountered in renderer scene cull"). It failed in
3 of 9 runs with the motes on, 2 of 6 with the drift off
(`--no-wind-blades --no-petals`) and 0 of 6 with `--no-motes`. So it isn't
the drift swarm. Whether the older swarms (pollen, kick) cause it, or whether
it's chance, isn't known. There was no GDScript backtrace and it wasn't
chased here.

## Round 3: blades and petals that read, and a far layer from height (2026-11-14)

Prototype round (smoke passed, native and `--native-react=0`; no tests added).
**Native was NOT rebuilt**: no C++ changed. The near drift's flight is untouched
(spawning only changed), and the new far layer flies on the GPU.

### Diagnosis (default flags, `--at=640,470 --heading=0 --alt=5`, chase camera)

Measured per frame with a scratch driver (`scratch/motes_seen.gd`: bits in the
frustum, projected size in a 1440x900 view, on-screen time by nearest match)
and by drawing the bits magenta and counting blobs in the film.

| Boost pass, before | |
|---|---|
| pool alive | 237 (cap 360) |
| behind the camera | **80%** of the pool |
| on screen | 36 a frame |
| projected length / width, median | 7.4 px / **2.6 px** |
| height over ground, median | **2.0 m** (eye 9.3 m): 3 m under the eye, seen against sunlit grass |
| magenta blobs of 9+ px a frame (1080x675 film) | **8.6**, nearly all lying in the grass near the camera |

So they were there but not seen: thin pale-green slivers riding in and just over
grass of the same value, mostly behind the eye. Cause by cause: at speed the
ride was shortened by `DRIFT_PASSED` (0.5-1.4 s at Boost), most of it the
rise out of the grass, so bits barely got up before falling; the corridor
started 6 m ahead of the camera, so many were passed at once; the pale straw
matched the sunlit grass; and a 0.18 m blade at 23 m is 2-3 px wide.
On-screen time was fine (median 0.48 s). The near fade was not the problem.

### What changed

- **Ride height follows the eye** (`DRIFT_OVER` 0.6-1.7 of the eye's height
  over the ground, at least `DRIFT_RIDE`, at most 12 m): flying low they cross
  the view at and above the plane's height, against sky and horizon.
- **Met already up** when the eye is fast (`DRIFT_FAST` 8-25 m/s), and they
  **ride until the eye has passed them** (+0.25-0.8 s), then fall short
  (`DRIFT_UNSEEN`), so the pool holds the ones ahead. Corridor's near end is
  the eye's travel over 0.35 s (`DRIFT_NEAR_LEAD`, about 20 m at Boost), half
  width 19 m (`DRIFT_SIDE`); a puff is a stream 2.6x its size along the wind.
- **Bigger and contrasting**: blades 0.4-0.8 m by 0.15-0.22 m; faces cream,
  straw, a dry brown and tan (darker than sunlit grass), pale tip
  (`DRIFT_PALES`); 30% of blades are white seed fluff (round, `--wind-fluff=X`);
  petals 0.15-0.22 m. More of them: `DRIFT_PUFFS` 2.4, 10-22 bits a puff, 24
  puffs, 24 births a frame.
- **Grow with distance** (shaders/grass_bit.gdshader): from 6 m to 40 m a bit
  grows up to 2.8x across and 1.5x along (a petal 2.8x both ways), so a far bit
  is a fleck, not a hair. This also applies to the kick's bits, but they sit at
  about 12 m, where it is about 1.1x.
- **Far layer** (new, `WindFar`, shaders/wind_fleck.gdshader): streamers of
  flecks 70-520 m out in a +-57 degree sector about the view, placed by the
  puffs' logic (`_gusty`, more in stronger air, petals over `bloom` drifts in
  their wash colour, fluff and cream/brown/tan flecks). 56 slots x 48 flecks
  (2688 instances, one MultiMesh). A streamer's flecks are written once at
  birth (`set_instance_*`), and each flies **on the GPU** from where and when it
  was let go (drift with the air, bob, swirl). The CPU per frame is one uniform
  (`now`), plus at most one streamer try (2 `bloom` calls, 3 land probes: grass,
  ground downwind, tint). A fleck is a camera-facing streak along its own way
  across the screen, 4.2 px across at any distance, with fog. It fades in by
  size over 45-85 m from the eye, where the near drift's real blades take over
  (the near drift now runs to 60 m over the ground, thinning from 20 m:
  `DRIFT_HIGH`), and out over 520-700 m.
- Flags: `--wind-blades=X`, `--no-wind-blades`, `--petals=X`, `--no-petals`
  (unchanged), plus `--wind-fluff=X` and `--far-drift=X` / `--no-far-drift`.

### Numbers after (same flights)

| | Boost before | Boost after | Cruise before | Cruise after | Title before | Title after |
|---|---|---|---|---|---|---|
| on screen a frame (mean / max) | 36 / 107 | 98 / 201 | 26 / 66 | 67 / 206 | 3.6 / 14 | 4.5 / 11 |
| behind camera | 80% | 57% | 81% | 61% | | |
| height over ground, median | 2.0 m | 7.6 m | 2.1 m | 8.7 m | 1.9 m | 2.2 m |
| above the eye | 24% | 58% | 22% | 70% | 14% | 36% |
| length / width px, median | 7.4 / 2.6 | 12.5 / 6.8 | 8.5 / 3.2 | 10.8 / 7.9 | | |
| magenta blobs 9+ px a frame (film) | 8.6 | 35 (before the last palette/rate step) | | | | |

(The before cruise's px median printed by the driver after the shader change
assumed the new far growth. 8.5/3.2 is from the first, honest run.) At 60 m
and 120 m over the meadow: before, nothing (the drift stopped at 40 m). After,
the far layer at heading 90 holds about 590 live flecks, 310 on screen (60 m).

Default wind fills the near pool to its 360 cap at Boost (`--wind=1`, `2`,
`gusty --hour=14.5` all cap; puffs 22-24). The cap is the ceiling, the oldest
(behind the eye) go first. `--wind=0.3`: peak 102 bits, 6 puffs.

### Cost

| | before | after |
|---|---|---|
| `m_drift`, headless driven Boost, native (mean / p95 / worst ms) | 0.122 / 0.31 / 0.50 | 0.183 / 0.38 / 0.58 |
| `m_far` | n/a | 0.014 / 0.07 / 0.38 (a birth frame writes 48 instances) |
| frame time, rendered `look_views` meadow_low (median wall / gpu ms) | 7.81 / 7.76 | 7.84 / 7.79 |

Parity: `scratch/motes_parity.gd` (feeds `_drift_bit`'s bits to both and steps
600 frames): worst difference 0.0. (The driver hangs after its RESULT line and
times out. That's harmless.)

### Films (scratch/motes2, chase/play camera)

before_boost / after_boost (Boost, cosmos and lupine drifts), before_cruise /
after_cruise, before_title / after_title, before_h60 / after_h60 and
before_h120 / after_h120 (heading 90 over the river meadow), after_descent
(120 m to 5 m). Driver: `scratch/motes_seen.gd` (`--film`, `--probe-far`,
`--magenta`, `--hold-to` for the descent).

### Tests broken

None that reference the motes or the two shaders (grep over tests/). The full
suite was not run.

### Unverified / caveats

- **No hand flight.** All flights are driven straight lines.
- **Descent hand-over without a pop**: the film shows flecks through the
  descent, but its frames are 0.6 s apart. A pop of one or two frames could not
  be seen in it, and no per-frame check of the 45-85 m band was made.
- **From height it's subtle.** On sunlit pale-green meadow the far flecks read
  mostly as moving cream and white streaks, clearer over water, forest edges
  and sky than over open grass. Streamers only spawn over grass (none over
  forest), so a forested view stays empty. Tune with `--far-drift=X` (rate),
  `FLECK_PX` and `FAR_FLECKS`.
- Near the camera, the dry brown blades can look like wood chips (title).
- A shader gotcha found here: in wind_fleck, `max(size, ...)` with
  `size = length(MODEL_MATRIX[0].xyz)` drew nothing (the cause wasn't found).
  The fleck's own size was dropped, since it never shows past the hand-over.
- The pool still caps at 360 at default wind and Boost. Raising `DRIFT` wasn't
  tried.
- Other worlds, snow and the Mac weren't checked.

## 2026-11-14: far layer off by default

The user saw the far layer in flight: "way too blobby". It is now off unless
`--far-drift` or `--far-drift=X` is passed; `--no-far-drift` still works. The
follow-up lane on it was stopped with nothing committed.

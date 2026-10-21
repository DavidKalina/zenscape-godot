# Handoff: home isle (prototype)

Branch `iter/home-isle`. The heist level now starts at home, a landmass
far out in the same sky. The heist isle can't be seen from home, and home
can't be seen from the heist.

## Play it

`./run-heist.command` (throwaway ledger in /tmp). You start on foot beside
the parked plane on home's strip.

Flags (after `--`):

- `--home-far=<m>`: how far home is from the heist isle's middle.
  Default 1800, about 2 min at cruise.
- `--hunt-seed=<n>`: sets the heist's bearing from home and where the
  landmarks go. Without it, every run (and every restart) draws a new seed.
  The log prints it as `home: hunt seed N`.
- `--haze=<from>,<to>`: the haze range in metres. Default 380,760.
- `--no-haze`: turns the haze off.
- `--cue-far=<m>`: how far the cues draw. Default 1500.
- `--no-home`: the heist as before. You start on its landing and bank by
  flying clear.

## What's there (`studies/heist_home.gd`, node `Home`)

- **Land** (`home/land`): the lower world's sea-cliff tableland
  (`scripts/sea_cliffs.gd`), 180 m across, hanging in the sky. It has
  layered walls, stacks and an arch. A 150 m strip is levelled across its
  top, along the contours, as landing turf. The plane parks at one end.
- **Lake** (`home/lake`): a lake islet (`scripts/landform_lake.gd` and
  `scripts/islet_lake.gd`) set against the tableland's low side. Its rim
  is at the tableland's edge. It spills off its far rim as a fall, with
  the fall's thread running down to the cloud sea.
- **Landmarks** (`home/landmark_<n>`): 9 crag rocks, each with a ruin on
  top. Three are roughly on the line between the isles, offset to the
  side; three are round each isle, 420 to 700 m out.
- **Cues** (`home/cue_home`, `home/cue_heist`, using
  `shaders/home_cue.gdshader`): a white spray column hanging under home's
  fall, and a smoke column over the vault. Both ignore the fog and fade out
  past `--cue-far`.
- **Haze**: depth fog in the sky's haze colour, taken each frame from
  `celestial.surface_fog_color` and tinted by `HAZE_TINT`. It doesn't touch
  the sky itself. Past the haze's end plus 150 m, no land mesh is drawn at
  all (`range_out`). Without that, a far isle still showed as a faint
  ghost shape.
- **Banking**: the run banks once the loot is home. That means the plane is
  stopped on home's turf, or you're on your feet there, with loot in the
  bag (hitched or worn) or in the keep. Landing at the heist doesn't bank.
  Being caught or lost works as before.

Shared code changed (small and opt-in):

- `greed_run.gd`: a host hook `greed_banked()`.
- `crag_reach.gd`: a hook `place_strip()`. Ruins, loot and burrows keep off
  the heist landing's strip, not the plane's start.
- `crag_reach_greed.gd`: uses `place_strip()`.
- `landscape_lighting.gd`: the sky stays at half resolution under fog that
  has `fog_sky_affect` 0.
- New: `studies/heist_level_sky.gd`. Home is one of the sky's places, so
  cloud towers keep off it.

## Proved

Smoke checks (headless, 0 errors) passed for:

- `heist_level`
- `heist_level --no-home`
- `crag_reach --greed-run`
- `crag_reach --olmec`
- `aqueduct_isle`

`scratch/home/trip.gd` is a round trip through the real input, headless,
`--hunt-seed=3`, with 12/12 checks passing:

- You start by the plane at home, board with Space and take off.
- The plane flies 1870 m out in 111 s.
- It lands on the heist landing and you get out. Nothing banks there.
- The loot is bagged with E. Getting placed beside it was setup, not play.
- You take off again, fly home in 113 s and land on the strip: "Banked 25".

`scratch/home/fps.gd` is rendered: frames held at 16.7 ms (vsync) on foot
at home, approaching home, between the isles, approaching the heist and
over the heist.

Load time goes from about 7 s to about 11 s. Home builds in 3.6 s on the
main thread.

## Stills (`scratch/home/shots/`, git-ignored; copies in `captures/home/`)

- `03_home_approach.png`: home from the air at 420 m. Cliffs, lake, the
  fall and the spray column all read.
- `04_home_fall.png`: the cliff and the fall from below the rim.
- `02b_home_toward_heist_level.png`: the view from home's strip toward the
  heist. Only clouds, a cloud tower and home's own spray show.
- `sheet_reveal.png`: from home, then 1300 m, 800 m and 600 m from the
  heist.
  - At 1300 m you see only the smoke and one landmark.
  - At 800 m you see a pale shape in the haze.
  - At 600 m the isle comes through.
- `05_heist_0420.png`: the heist at 420 m, clear.

## Tests

None run beyond the smokes. No existing test references the heist, the
crag, the greed run or the sky-resolution switch.

## Known gaps

- You walk on the lake bed. The lake has no swim here, and the plane could
  in principle land on the bed.
- The lake islet's own shore wall is a plain sandy face in front of the
  tableland's layered walls.
- A walker who drops from the strip onto the lake terrace (about 4 m down)
  can't climb back up. R resets.
- At the haze's far end, the haze colour is a fixed tint of the sky's haze
  colour. It's close at midday; dusk or weather may show a mismatch until
  `range_out` drops the mesh.
- The heist's lock-on circle (700 m) is the only lock target, so locking
  near home locks onto the heist.

## What the harness lacked

No flight helpers. The fly-to and land-on-a-strip autopilot was copied
from an old scratch driver into `scratch/home/trip.gd`. A `fly_to` /
`land_on(strip)` pair in drive.gd would serve every isle round.

## Next steps (not this round)

A marking tool, a map, random isle placement or generation, more clues,
the lake's swim, and building home on a worker to cut the load time.

## Round: water

Branch `iter/home-water` (on `iter/home-isle`).

### What changed

- **The lake is in the tableland.** The separate lake islet is gone. The
  tableland's own recipe carries the lake, dug as a basin
  (`scripts/islet_lake.gd`, the lake's new opt-in `basin`): an oval about
  34 x 60 m, sought on a 3 m grid for the spot nearest a rim (leaning to
  the low side) whose oval stays a bank's width inside the cliff's brink
  and whose banks keep clear of the strip and its fade. The level stands
  0.9 m under the lowest land round it. The land comes down over 13 m to a
  beach, then the reed shelf, then the deep (3.2 to 4.2 m), with an isle
  sometimes. It spills through a notch in the layered cliff toward the
  nearest rim. Its shores are the tableland's own ground and walls: no
  sandy slab face. Seeds where the low side is too narrow put the lake on
  the high side (it then stands a few metres over the strip).
- **The water** is the kit isles' still sheet (`KitWater.still`, the
  aqueduct isle's water), 0.5 m a cell: turquoise shallows to slate-blue
  deep, the bed read through it, shore lap, chop with the wind, and churn at
  the lip. The islets' plain pond is taken off. Reeds and bank grass are
  sought in the basin's box, so the shelf has them.
- **The fall** is the SkyIslets curtain and its thread to the cloud sea,
  in the live falls' painted look (`painterly`, veil 0.35): streak columns
  sliding down it, not a plain white slab. `home/cue_home` hangs under it
  as before.
- **Swimming**: the lake is a pool for the walker's ground
  (`HeistHome.pool`, appended in `heist_level._add_life`). A pool may now
  give an `inside` callable (`pilot_physics_ground.gd`, opt-in), so only
  the lake's own water in its box is wet.
- **The plane**: the lake bed is not turf (rock to the plane, ground to
  the walker), so `floor_at` finds nothing to land on there. The water
  surface is a collider on `WATER_LAYER` (1 << 12) that only the plane's
  `plane_ground` reads (as the cloister tarn's): it skims the water at
  its skim height and can't dive in.
- `sky_islet.gd`: the lake bed and beach paint go before the sea cliffs'
  own paint when the islet has both, and only inside a basin.
- `home/lake` now names the lake node (the basin's middle). Moved in the
  world view, the basin is dug there on the next load. Deleted, home has
  no lake. No saved layout uses it yet.

### Proved

- Smoke, headless, 0 errors: `heist_level` (seeds 3, 71, random),
  `--no-home`, `aqueduct_isle`, `cloister_tarn_isle`, `motif_yard`
  with `editor_tarn_peak` and `plumb_well`.
- `scratch/home/water_trip.gd` drives real input, headless, 13/13 at seeds
  3, 1 and 5:
  - He walks from the plane to the bank (route).
  - He wades in and swims the deep (`swimming`, wade 0.58), then swims
    across and walks out on the far bank.
  - He walks back up onto the strip.
  - `floor_at` over the water is NAN.
  - The plane takes off, goes round and lands by hand on the strip.
  - A landing aimed at the lake skims at 0.9 m over the water, is never on
    its wheels there, and comes down on the far bank.
- The last round's `scratch/home/trip.gd` (seed 3) still banks 25 on
  landing home.
- Tests `test_landform_lake`, `test_landform_cliffs`, `test_sky_islets`,
  `test_sky_fall_thread`, `test_character_study` and
  `test_aqueduct_under` pass. No test is known broken.

### Stills (`scratch/home/shots/`, git-ignored; seed 3, `scratch/home/water_look.gd`)

- `w01_lake_air.png`, `w01b_lake_air_out.png`: the lake from the air.
- `w02_shore_play.png`, `w02b_shore_eye.png`: on its shore.
- `w03_swim_play.png`, `w03b_swim_side.png`: swimming.
- `w04_fall_below.png`, `w04b_fall_lip.png`: the fall from below the rim
  and at its lip.
- `w05_approach.png`, `w05b_approach_side.png`: home on approach.

### Gaps

- **Not from this round:** at some hunt seeds the strip is a stub, because
  the tableland's outline has a bay across its line. Seed 6 gives 11 m,
  seed 7 15 m and seed 4 39 m (checked with the lake deleted). That breaks
  the landing-turf rule. The strip should be sought (angle and offset) for
  the longest clear run.
- The bed's 2 m grid shows through the clear water as big flat facets at
  the shelf's drop.
- Up close, the fall's sheet ends in a ragged cut where the thread and
  the spray cue take over.
- The water sheet is laid in the land node's frame. A layout that turns
  `home/land` would turn the chop with it.
## Round: grass (`iter/home-grass`)

Home's top now carries the isles' carpet grass. All of it is in
`studies/heist_home.gd`; no shared file changed.

- **Grass** (`_grass`): `KitFlora.Grow` with `aqueduct_isle_flora.gd`
  `carpeted`, then `calm`, as the crag units do. Tussocks, thatch, seed
  heads, flowers, contact darkening and the rolling height all come with
  it. The probe is the islet shape's own ground (no physics): open land,
  off water, trunks and stones, no steeper than the palette's rock slope.
  It grows over the tableland and over the lake islet's banks (nothing
  within `BANK_BARE` 0.35 m of the water). The old orange drift tufts are
  off (`drifts` 0, tableland and lake).
- **The strip**: the long grass keeps `STRIP_CLEAR` 11 m off the strip's
  line. The strip has a short mown grass of its own (`StripGrass`: 3
  tufts a m2, 0.3-0.5 of a tuft, no tussocks, no wild rim). Trees were
  already kept off it by the recipe's `clear`.
- **Ground tint**: both tops are softened with `LineBuild._soften_top`
  (colour runs across the turf, no triangle quilt), and home's ground
  material takes the carpet's calmer settings (`ground_dry`, `ground_patch`,
  `ground_mute`).
- **Summer green**: home's tree and grass batches, the landmarks' and the
  ground are `LineBuild.evergreen` copies, so the current season's gold
  doesn't show on home. (Winter stays off, as before.)
- **Trees**: the tableland's count 10-16 up to 20-30.
- **Landmarks**: `"grass":1.0` (was 0.0, bare ochre turf), so their crowns
  grow the unit's own carpet. Each draws it within the unit's own
  range (220 m); farther, the top shows its plain green turf.
- **Heist isle**: left greybox (`"grass":0.0`), as asked.
- Flags: `--no-home-grass` (the old look), `--home-grass=<share>` (0.2 of
  the carpet's tufts), `--home-grass-range=<m>` (70, the carpet's is 220).

### Cost

- Instanced triangles, all tiles: 4.5M on the land (1.1M of it the strip's
  short grass), 54k on the lake. Only tiles within 70 m (fade over 15 m)
  draw, and frustum culling applies.
- Rendered counts (`scratch/home/fps.gd`), primitives / draw calls with
  grass against without: on foot 3.28M / 308 against 1.97M / 185; 30 m
  over the middle 3.56M / 257 against 1.79M / 134; 80 m up, 120 m out
  2.10M / 221 against 1.78M / 202. GPU time isn't measurable on this
  machine's counters (reads 0), so no ms figure.
- Build time: about +4 to +5 s on home's build (the grass is grown in
  GDScript on the main thread: 3.8 s land, 0.25 s lake); the heist scene
  was ready in 12.8 s without the grass and 17 s with, in the smoke. Moving
  the grow to the worker (`plain` site, `KitFlora.batch_node`, as
  `hall_line_build.gd` does) would cut that; not done.
- Share 0.2 and range 70 are a compromise: 0.55 at 120 m was 9.4M
  triangles and 8.5 s.

### Stills (`captures/home_grass/`, git-ignored; `scratch/home/shots.gd`)

`air.png`, `air2.png` (home from 230 m and 170 m), `foot.png` (on foot by
the plane), `strip.png`, `rim.png`, `lake.png`, `mark.png` (a landmark).

### Not done / rough

- The lip: no wild grass spills over the tableland's rim (its edge is the
  palette's orange earth).
- The lake banks stay sandy where the lake's own bed tone paints them; the
  grass only grows on the green. The water and its shader are untouched.
- `_soften_top` also runs on the lake's top (colours only); if the water
  agent recolours the bed in `IsletLake.bed_tone`, it is still softened.
- Grass is grown only once at build, so Layout moves of `home/land` carry
  it (it is a child of the node).
- Smokes pass: heist_level, `--no-home`, `--no-home-grass`; 0 errors.

## Round: grass LOD (`iter/home-grass-lod`)

Home's top now carries the carpet at its own density (7.8 tufts a m2, the
aqueduct isle's look and grade). Distance rings set the cost, not a thinner
carpet.

### The rings (KitFlora Site `lod`, opt-in, off by default)

- **Near ring:** every tile's grass, minus the mid ring's share, drawn with
  the full tuft. Over `lod.x`..`.y` m (home: 30 to 55), each tuft shrinks into
  the ground at its own distance. The distance comes from a hash of its root
  (reference_surface `grass_ring`), so the density falls evenly across the
  band, with no edge and no alpha pass.
- **Mid ring:** `lod_share` of the tufts (0.25), drawn by lot per tile, in
  a batch of their own. They use the cheaper tuft (`GrassTuft.build_lite`:
  11 one-row blades, 33 triangles against 80). Across the near band they grow
  `lod_grow` (1.5 wide, 1.25 tall; `grass_ring_grow`), so the sparser ring
  keeps its cover. They thin out the same way over `lod.z`..`.w` (110 to 170
  m).
- **Far:** past 170 m, only the turf is drawn: home's ground material, the
  shared one with `calm`'s grade. From 300 m it reads as a green meadow top
  (`lod_out300.png`). No ground-shader grass texture was needed.
- A ringed tile stops drawing (visibility range, no fade) one tile
  half-diagonal past its band's end, when all its tufts are gone. No CPU
  work a frame.
- Flowers and wheat keep their own range (65 m, as before).

### The other changes

- **Off the main thread:** the grass grows as plain sites (`Grow.parts`) on
  3 threads of home's own (`GRASS_THREADS`). They are not on the worker
  pool, so the heist's own build doesn't queue behind them. Each job covers a
  column of whole tiles, `GRASS_COLUMN` 24 m (Site `box`, opt-in), and the
  jobs nearest the plane go first. `_process` stands the batches
  (`KitFlora.batch_node`) within 4 ms a frame and calms each frame's share. A
  restart stops the threads.
  - The probe got about 30% cheaper: one `_locate` for both on_land and
    ground_at, and the trunks and stones filed by 4 m cells.
  - In the runs, the grass had stood about 0.15 s after the scene was ready.
- **Rim spill** (Site `spill`, opt-in, `GRASS_SPILL` 3 a metre): wild tufts
  are rooted 0.05 to 0.35 m in from the rim, lean 40 to 70 degrees outward
  and are 1.2 to 1.9 times a tuft. They hang over the lip of the tableland
  and of the lake islet.
- **Lake banks:** `BANK_BARE` went from 0.35 to 0.12. Most of the lake
  islet's dry land lies within 0.35 m of the water, so its banks had only 1
  tuft a m2. Now they carry the carpet. The basin, the water and its shader
  are untouched.
- **Summer, fixed at the cause:** the heist pins summer with
  `choose_season(2)`, but the calendar glided there from the date's season.
  On 20 October that is autumn, 0.64 to 0.375 the long way round. That glide
  walked the plants through autumn's gold and winter for about 90 s.
  `KitWeather.choose_season(index, snap)` (an added arg, default false) now
  snaps when the heist asks, and `zs_season` shows summer from the first
  frame. All of home's `LineBuild.evergreen` copies are gone: the grass,
  the trees, the landmarks and the ground (`islets.ground_source` is the
  shared ground again). `calm`'s olive grade stays.
- Shared code, all opt-in or added only:
  - `kit_flora.gd`: Site `lod`, `lod_share`, `lod_grow`, `lod_soft`, `box`,
    `spill`; `ringed`, `lite_tuft`, `ring_material`; `batch_node`'s `ring`
    arg.
  - `grass_tuft_mesh.gd`: `build_lite`. `_clump` takes rows, taper and
    width, and its default output is unchanged.
  - `reference_surface.gdshader`: `grass_ring` and `grass_ring_grow`
    (0 = off).
  - `kit_weather.gd`: `snap`.

### Flags

- `--home-grass-lod=x,y,z,w`: the rings. `0` turns them off: every tuft is
  drawn to `--home-grass-range` (default 220).
- `--home-grass=<share>`: the share of the carpet's density (default 1.0).
- To get last round's state: `--home-grass-lod=0 --home-grass=0.2
  --home-grass-range=70`.

### Cost

Rendered, `--hunt-seed=3` (`scratch/home/lod.gd`; primitives and draw calls
from Godot's monitors). Frame wall time is only rough, about vsync, and GPU
time isn't readable here.

| view | rings (now) | last round (0.2, 70 m) | no grass |
|---|---|---|---|
| on foot by the plane | 4.67M / 288 | 3.03M / 258 | 1.97M / 185 |
| 30 m up over the middle | 4.80M / 323 | 3.54M / 251 | 1.78M / 122 |
| 150 m out, 50 m up | 3.36M / 299 | 2.32M / 229 | 1.97M / 204 |
| 400 m out, 140 m up | 0.39M / 125 | 0.39M / 125 | 0.39M / 125 |

- Without the rings, the full carpet drawn to 220 m is 9.1M primitives at
  30 m up.
- All instanced triangles, the whole tile set: 13.5M, 1.44M of them the mid
  ring's. Last round: 4.9M.
- Build, headless smoke: home builds in about 4.9 s (5.0 s without grass).
  The grass grows in about 5.3 s on its threads, alongside the heist's
  build. Ready in 13.1 to 13.8 s, against 11.3 to 12.4 s with no grass and
  last round's 17 s. The extra ~1.5 to 2 s is the threads slowing the main
  thread's build (the heist's units and the Olmec place graph). Fewer
  threads didn't help.

### Stills (`captures/home_grass_lod/`, git-ignored)

- `lod_foot.png`: on foot by the plane.
- `lod_pass.png`: a low pass over the strip.
- `lod_along.png`: along the strip.
- `lod_across.png`: across the lake, on the ground through the handovers.
- `lod_low.png`: 30 m up.
- `lod_out150.png`, `lod_out200.png`, `lod_out300.png`: from 150, 200 and
  300 m.
- `lod_rim.png`: the tableland's lip.
- `bank_rim2.png`: the lake islet's lip and banks.

### Switching it on for another isle

On the isle's `KitFlora.Site`, after `Carpet.carpeted(site)`:

1. Set `site.lod = Vector4(near_from, near_to, mid_from, mid_to)`.
2. Optionally set `lod_share`, `lod_grow` and `spill`.
3. Grow as usual. The Draw splits the grass batches, and `Carpet.calm`
   handles the ringed batches as before.

For a worker grow, also set `plain = true`, then stand `job.parts` with
`KitFlora.batch_node(key, tile, count, buffer, range, part.get("ring", {}))`.

### Tests

These headless tests pass:

- `test_sky_islets`
- `test_ground_look`
- `test_breeze`
- `test_pilot_wake`
- `test_landform_cliffs`
- `test_motif_sky`
- `test_kit_time_weather`
- `test_isle_hall_chain`
- `test_aqueduct_isle_sky`

`test_aqueduct_isle_look` fails, but it fails the same way on the base
commit (the carpet over its 1.2M budget, and others), so this round didn't
cause it.

### Rough

- The strip's mown grass stays sparse and short, by design. Its edge to the
  long carpet reads as a line from the air.
- From 300 m the top is a plain green, with no grain in it.

## Round: merge, strip, bed, fall (`iter/home-merge`)

Branch `iter/home-merge` merges `iter/home-water` and `iter/home-grass-lod`.

Play: `./run-heist.command`, or
`python tools/godot.py --rendered studies/heist_level.tscn -- --no-title --hunt-seed=4 --ledger=/tmp/home.json`.

Both rounds' flags still work: `--no-home`, `--no-home-grass`,
`--home-grass=`, `--home-grass-lod=` and `--home-grass-range=`.

### The merge

- **One grow.** The grass grows once, over the tableland and the lake dug in
  it (`_grass(land, shape)`). The lake islet's grass, `BANK_BARE`'s old
  meaning and `lake_spec.drifts` went with the islet.
- **Off the water and the beach.** No tuft grows where the ground stands
  under `IsletLake.BEACH_TOP + BANK_BARE` over the level within `BANK_NEAR`
  (2.5 m) of the water. Those are the faces sky_islet paints as the bed and
  the beach. The grass grows down the banks to there. At seed 3 that leaves
  0 tufts in the water or on the beach and 17k on the banks.
- **The rim spill** runs along the cliff lip. It keeps `SPILL_NOTCH` (6 m)
  off the water, so no tuft hangs in the fall's notch. This uses KitFlora
  Site `spill_off`, a new opt-in Callable.
- **The reeds.** The lake's reeds and bank grass are the islet's own, as
  before.

### The strip at every seed

- **The outline holds a full strip.** It leans to hold one along the
  contours, through `scripts/island_outline.gd` form `spine` (opt-in). The
  spine is a line the land leans to hold: land within 26 m of it is taken
  first (`SPINE_PULL` 0.45), so a bay can't cut across it.
- **The strip's heading and offset are sought** on the shaped ground
  (`_seek_strip`):
  - It tries headings every 10 degrees, then every 2.5 degrees near the best,
    with offsets 3 m apart.
  - It takes the longest clear run, up to 150 m. A run is clear while the
    turf lies 6 m in from the shore and its fade is on the land. The strip's
    ends stop 16 m short of where the run stops.
  - Each metre of earthworks costs 1.5 m of score. Turning off the contours
    costs a little.
  - The search takes about 150 ms.
- **When it is levelled.** The strip is levelled in a new opt-in sky_islet
  recipe hook, `shaped`, before the lake is dug, so the basin keeps off the
  line that was found.
  - The hook also runs before the trees are planted, so the recipe's `clear`
    now really keeps them off the strip. Before, it was set after planting
    and did nothing.

Strip length at hunt seeds 0-20 (`scratch/home/strip_seed.gd`, swept):

| seeds | strip (m) |
|---|---|
| 0-20, every one | 150 |

At every seed:

- The bump is 0.0 m. That is how much `floor_at` varies along the strip's
  middle and 6 m to each side.
- No point along the strip is off the turf.
- The lake's water and beach stay 29 to 51 m off the strip's middle line.
  The turf runs 10 m each side of that line.

Before this round, seed 6 gave 11 m, seed 7 15 m and seed 4 39 m. With the
search but no spine, seeds 1, 2, 8, 9 and 17 got 122 to 148 m.

### The lake bed's facets: the cause and the fix

I found four causes by shooting the lake with the water hidden, then the bed
hidden, then each of the water shader's switches toggled.

1. **The bed was terraced.**
   - The shelf fell to the deep over 2.4 m (`DROP`), which is one cell of
     the 2 m grid. So the shelf's rim ran along the grid's triangle edges as
     a straight-sided step.
   - The isle stood on a flat apron 0.5 m under the water, ending in a 3.5 m
     cliff.
   - Seen through the clear water, these were the big flat triangles.
   - Fix: a recipe `drop` (opt-in; home uses 7 m), so the shelf slopes into
     the deep. With it, the isle's flank runs on down too (`ISLE_CROWN`).
2. **The ground was lit face by face.**
   - The ground material has `flat_faces` on and `facet_soft` 0.65. Sand and
     silt don't get the grass's soft light, so each 2 m face of the bed
     showed as a flat facet.
   - Fix: `IsletLake.fine_bed` (opt-in). It takes the bed and beach faces
     out of the top and draws each again as 16 faces.
   - Those faces are bent onto a smooth surface (Phong tessellation from the
     smooth normals). The bend fades to flat at the bed's edge, so the bed
     meets the faces round it edge for edge.
   - They are coloured point by point, fading from the colours round them at
     the bed's edge to the bed's own colour inside.
   - They are drawn in a copy of the ground material with `facet_soft` 1
     (the `LakeBed` node). The banks within 9 m of the water go into that
     mesh too, unchanged, so they are lit smooth with it.
   - Their faces stand with the rest of the top, so collision has them.
3. **The water's per-pixel depth read drew pale panes.**
   - With `depth_read` on, the shader drew pale panes with straight edges
     across the shallows. They stayed from every view, with shadows off and
     with the rock under the bed hidden. I didn't find their root cause.
   - Fix: home's sheet turns `depth_read` off, so the depth comes from its
     own vertices. Those vertices sample the smooth bed
     (`IsletLake.smooth_height`) every 0.25 m (`LAKE_CELL`, was 0.5).
   - The colour now runs smoothly from the shallows to the deep, and the
     bed shows through the shallows by the blend.
4. **The water's chop wove a pattern seen from the air.**
   - Its faces lined up on the regular grid.
   - Fix: KitWater `jitter` (opt-in; home uses 0.3) moves each vertex off the
     grid by a hash. From 22 m straight down, the chop is now an irregular
     grain with no checker.

Also: above the water, `bed_tone`'s sand and gravel stripes showed as
hard-edged pale bands in the ground's look. The fine bed paints the beach
evenly instead (`_fine_tone`).

### The fall

- **The sheet runs the whole wall.**
  - Before: the islets' own sheet stopped `depth*0.5+7` m down, which is
    mid-wall at home. The thread faded in behind it, which left the hole and
    the ragged cut.
  - Now: `_long_fall` lays the sheet down to the rock's foot under the notch,
    plus 4 m (86 m at seed 3). The sheet's broken tail is no wider than the
    sheet.
- **The thread takes over** at the same width and carries on to the cloud
  sea. Its spread is counted from the lip, so its width at the lip is set
  narrower to make up for that.
- **The veil** is 0.2 (was 0.35), so the sheet reads fuller.
- **The spray cue** (`home/cue_home`) now hangs from where the sheet breaks.
  - Its foot is 14 m wide (was 26).
  - It fades in from 160 m to 420 m away, through the home_cue shader's new
    `near` (off by default). Near the fall you see the fall itself; from
    afar the column still marks home.
  - Its far end is unchanged: 60 m wide and 300 m long.

### Other changes

- **`LAKE_DRY` is 0.15 m** (was 0.05). On the curved bed, a fine beach face
  just over the coarse waterline could count as turf. Once, the plane's
  wheels touched down there for one frame.
- **Load time.**
  - Home builds in about 5.2 s; of that, the fine bed takes 0.1 s and the
    0.25 m sheet 0.5 s.
  - In the smokes the heist was ready in 15.4 to 17 s, against 13 to 14 s
    last round. Part of that is other runs loading the machine; I didn't
    measure how much.

### Proved

- **Smokes**, headless, 0 errors:
  - `heist_level` at seeds 3, 4, 6, 7 and a random seed
  - `heist_level --no-home`
  - `heist_level --no-home-grass --hunt-seed=6`
  - `zenscape.tscn -- --no-title`
  - `crag_reach`
  - `cloister_tarn_isle`
  - `motif_yard` with `editor_aqueduct_gorge` and with `editor_tarn_peak`
- **`scratch/home/water_trip.gd`**, real input, passes 13/13 at seeds 3, 4
  and 6:
  - He walks to the lake, swims, walks out and walks back to the strip.
  - `floor_at` is NAN over the water.
  - The plane lands by hand on the strip.
  - A landing aimed at the lake skims it and is never on its wheels over
    the water.
  - The driver now swims to the deepest water it finds, because the
    basin's middle can be the isle (seed 4).
- **`scratch/home/trip.gd`** at seed 3: every check passes, and it banks on
  landing home.
- **Headless tests that pass:** `test_landform_lake`, `test_landform_cliffs`,
  `test_sky_islets`, `test_sky_fall_thread`, `test_character_study`,
  `test_aqueduct_under`, `test_kit_water`, `test_ground_look`, `test_breeze`,
  `test_pilot_wake`, `test_motif_sky`, `test_kit_time_weather`,
  `test_isle_hall_chain` and `test_aqueduct_isle_sky`.
- **`test_aqueduct_isle_look` fails** with the same four lines as on the
  base: the plants' triangle budget, the catalog multimeshes, a plant on a
  path, and plants off the turf. Not touched.

### Stills

In `scratch/home/shots/` (git-ignored), from
`scratch/home/look.gd --rendered -- --seed=N --tag=T --parts=lake,fall,home,strip`:

- **The lake now:**
  - `final_s3_lake_air.png` from the air
  - `final_s3_lake_down.png` straight down
  - `final_s3_lake_eye.png` and `final_s3_lake_eye2.png` from the shore at
    eye height
  - `final_s6_lake_*` and `final_s4_lake_air.png` at other seeds
- **The lake before:** `before_s3_lake_*.png`. `dry*_s3_*` show the bed with
  the water hidden.
- **The fall now:** `final_s3_fall_below.png`, `_side`, `_foot`, `_lip` and
  `_far`. The fall before: `fall0_s3_*`.
- **Home:** `final_s3_home_30.png` (30 m up) and `final_s3_home_300.png`
  (300 m out).
- **The strip:** `final_s4_strip_approach.png`, `final_s4_strip_side.png`
  and `final_s6_strip_*`.
- **Contact sheets:** `sheet_final_s3.png`, `sheet_lake46.png`,
  `sheet_strip.png`.

### Rough

- **The bank by the near shore** is dark brown, with crisp pale triangles in
  it, seen from the air. The fine bed doesn't change them; they come from
  the ground shader's look, not the bed's colour. Not chased.
- **The waterline.** With `depth_read` off, it follows the 0.25 m sheet, not
  each pixel.
- **The panes elsewhere.** The `depth_read` panes probably show on the other
  isles' KitWater too, such as the aqueduct isle's. Only home turns
  `depth_read` off.
- **The outlines changed.** The spine makes the tableland a little longer
  along the strip at every seed, so each seed's outline differs from last
  round.
- **The strip's heading.** The strip runs at the heading the search found.
  At seed 4 that is 10 degrees off the contours, with 2.7 m of earthworks.

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

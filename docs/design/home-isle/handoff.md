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

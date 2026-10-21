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

## Round: hub

Branch `iter/home-hub` (off `iter/home-isle`). Home now has land round it
to fly through, under and round: `studies/home_hub.gd`, node `Home/Hub`.

Play: `./run-heist.command`, or with a seed, `godot --path .
studies/heist_level.tscn -- --no-title --hunt-seed=3 --ledger=/tmp/x.json`.
`--no-hub` turns it off.

### What's there

All of it is laid in the strip's own frame (its middle, its way, the lake
on the -v side), read from `home.strip_a/strip_b` at build time, so it
follows the strip wherever home puts it. Each piece is named
`home/hub/<piece>` and moves in F4.

- **gate**: a wide rock arch, 32 m clear (toy 16), ahead-right of the
  climb-out. Its hole faces the strip's far end, so you see through it
  from the strip.
- **hoop**: an 18 m arch (toy 9) between the gate and the ridge, its
  hole lined up on the ridge's pass.
- **ridge**: a mountain (the massif landform, grown to 80 m radius,
  summits 105 to 125 m over its foot) on the dry side. Its pass is 20 m
  wide (toy 10), with its floor about at strip height, turned to run out
  from home. The summits stand over the plane's ceiling, so you go
  through or round.
- **horn**: a smaller mountain on the lake side, with a 16 m notch
  (toy 8) about 14 m under the strip.
- **stacks**: 7 sea-cliff stacks (home's own wall look) off the
  climb-out's left, tops staggered from 20 m under to 24 m over the
  strip, with 18 to 30 m gaps. It's a slalom.
- **downs**: rolling hills low on the lake side (80 m radius, crests
  about 26 m under the strip), for skimming.
- **needle**: a snug 14 m arch (toy 7) at the downs' far end, low.
- **window**: a 22 m arch (toy 11) 40 m over the strip on the way back,
  its hole facing the strip. Come out of it and you're lined up to land.
- **shaft**: a sea-cliff tableland behind the strip on the dry side, with
  a 30 m hole (toy 15) through it to dive down.

Lines that chain:

- Takeoff, gate, hoop, ridge pass, round a peak, window, land.
- Takeoff, the stacks, horn notch, skim the downs, needle, window, land.
- The shaft, any time.

New shaping: `scripts/rock_arch.gd`. A natural arch is built as a stack
of rock beds, each a rounded slab whose rim wanders, with hard beds
bulging and soft ones notched. Two legs stand on a turfed sill over a
keel. It's coloured with the sea cliffs' bed tones in home's own walls
material. Its knobs are its F4 tunes: toy width, height, depth, legs,
crown, keel, dip. Its rim is never let into the opening, so the clear
width is `WorldScale.opening(toy)` at the floor and about 90% of it half
way up.

Every piece keeps out of a corridor off each strip end (400 m long, 35 m
either side at the end, widening 0.22 m a metre). It also keeps off
home's land, the lake, the fall and the landmarks. A piece in the way
moves to the nearest clear spot, and the log says so.

### Shared code (opt-in)

- `scripts/mountain_massif.gd`: the recipe's `massif.col_half` (m) sets
  the pass's half width. Without it, the pass is sized as before.
- The massif draws its own faces, which aren't in the islet's top, so the
  hub gives them collision. Home's own stand code doesn't need this.

The hook lines are in `studies/heist_level.gd`. There are none in
heist_home.gd:

```
const HomeHub = preload("res://studies/home_hub.gd")
		HomeHub.add(home)          # in _build_art, after home.build and the start
	return [["home",Vector3(c.x,TOP,c.y),c.z]]+HomeHub.places_of(home)   # home_places
```

### Proof

- Smokes (0 errors): `heist_level` at seeds 3, 7 and 42, `--no-hub`,
  and `--no-home`. `test_landform_mountains` and
  `test_world_scale_guard` pass.
- `scratch/hub/fly.gd` is real input. It takes off, threads the
  openings, then flies home and lands. Two courses at seeds 3, 7 and 42,
  0 bumps, landed every time. Clearance past the wingtips, and over and
  under the plane, flown through the middle:

  | opening | width | each wingtip | under | over |
  |---|---|---|---|---|
  | gate | 32 m | 13 to 15 m | 10.6 m | 13.5 m |
  | hoop | 18 m | 7.0 to 7.5 m | 7.3 m | 9.1 m |
  | window | 22 m | 8.5 to 10.6 m | 10.1 m | 13 m |
  | needle | 14 m | 5.7 to 6.4 m | 5.5 m | 7.2 m |
  | ridge pass (10 m over its floor) | 20 m | 9.8 to 11.4 m | 9 m | open |
  | horn notch (10 m over its floor) | 16 m | 5.3 to 9.6 m | 9.2 m | open |

- `scratch/hub/shaft.gd`: a dive down the shaft and out 70 m under it,
  0 bumps.
- Cost (`scratch/hub/cost.gd`, rendered, seed 3), hub against
  `--no-hub`:

  | view | draw calls | primitives |
  |---|---|---|
  | on foot on the strip | 194 against 176 | 1.53 M against 1.43 M |
  | takeoff, looking out | 262 against 174 | 1.63 M against 1.30 M |
  | hub middle, toward the stacks | 311 against 159 | 0.88 M against 0.64 M |
  | lake side, toward home | 264 against 189 | 1.38 M against 0.75 M |

  The hub builds in about 1.5 s, its islets on workers at once. Load
  time is in the noise (11 to 12 s either way).
- Stills are in `scratch/hub/shots/` (git-ignored):
  - `02_takeoff`: the hub from the strip.
  - `nohaze_03_overview`, `nohaze_03b_top`: overviews.
  - `04_*_lined_up`: lined up on each arch.
  - `05_ridge_pass`, `05c_horn_notch`: the passes.
  - `06_downs_low`: low over the downs.
  - `07_shaft`, `08_stacks`.

### Model budget (docs/art/model-budget.md)

- **Vertex-colour grime**: applies, and is used. Bed tones and moss are
  in vertex colours, so there are no textures.
- **Visibility ranges**: apply, through home's `range_out` (the hub is
  under Home). A shorter range for the arches' collision isn't needed.
- **Import LODs**: would help. The arches are about 6k triangles each,
  22k for all four. A coarser rim (EDGE 2.2 to 4 m) past 200 m would
  save about half, roughly 0.1 ms on a low-end GPU.
- **Sculpt and bake** and **parallax**: don't apply. The rock is
  flat-faced in the islets' style.
- Most of the added primitives are the islets' grass and plants: the
  downs and the 7 stacks. If cost matters, thin the stacks' planting
  (trees 0 to 2) or drop to 5 stacks, saving about 60 draw calls.

### Known gaps

- The arches are blocky up close: slab beds rather than a carved,
  wind-worn form. They read well from flying distance.
- The autopilot only steers, so the driver climbs over things between
  openings. A `fly_to` that routes round land would serve every round.
- The hub's islets aren't banked on (`home.over` is home's circle only).
  Landing on the downs works, but it isn't home.
- The ridge or downs can move 20 to 70 m on some seeds to clear home or a
  landmark. The lines still hold (driven at seeds 3, 7 and 42).

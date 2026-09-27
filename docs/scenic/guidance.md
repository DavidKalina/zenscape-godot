# Quiet guidance

Phase 3, slice 8 (`feature/quiet-guidance`, 2026-09-26). The world has a
regional beauty score that the player never sees. It nudges what emerges and
where water settles toward what reads well, without taking control. The goal is
for the world to feel like it has taste, not like it is arranging things.

Everything is in `scripts/quiet_guidance.gd`. The hooks are in
`scripts/emergence.gd` (planning and arrival) and `scripts/water_brush.gd`
(the pour's plan). `--no-guidance` turns all of it off for A/B.

## The regional score

`QuietGuidance.score(data, blend, plants, rect)` reads one rect on the biome
blend's 1 m grid. Each term lies in 0..1, and `total` is their weighted sum
(`WEIGHTS`).

| Term | Weight | What it reads |
|---|---|---|
| `relief` | 0.15 | The spread of heights (standard deviation and range). |
| `water` | 0.2 | Presence: water share, best between about 8% and 40%; none reads 0.35. Shore: on the blend's 0.25 m pond raster, thin water (one-cell tongues) and thin land (one-cell strips between waters), against the water's size. |
| `edges` | 0.2 | How straight the canopy's outline reads. The outline is trees splatted through a 3 m kernel. Its straightness is the axial coherence of the outline's gradient over 13 × 13 cells. Trees standing alone in an ordinary spot count against it. |
| `openness` | 0.15 | Open ground (no tree within 1.5 m), best between about 45% and 85%. Undergrowth with more than `CLUTTER_MAX` plants around it counts against it. |
| `variety` | 0.1 | The entropy of water, canopy, undergrowth, grass and bare ground over the rect's cells. |
| `framing` | 0.2 | Water seen from the overview camera, past any tree standing in front of it. The biggest trees standing on feature spots (below). |

The camera is the overview in `scripts/world_beauty.gd` (yaw 0.35, polar 0.82),
the view the plate is usually seen from. Its ground direction is almost +z.

**Feature spots** (`features`): a knoll (0.25–1 m above a ring 3 m out), a
shore 1–4 m back from water, or a rule-of-thirds point of the overview frame.
A tree there reads as placed.

**Where it runs.** Each emergence plan scores its region on the planner, over
the detached ground on the worker (`_plan_async`), and keeps the score as
`region.score`. Its terms set how hard three nudges lean. A region already
strong in a term is nudged less for it (`Guide.gain`: lone trees by `edges`,
sightlines by `framing`, and clutter by `openness`, each 0.6–1.0). The plants
the planner reads (`QuietGuidance.plants`) are taken on the main thread when
the plan starts. The planner has no object records.

## The nudges

Each nudge is a pure function of the ground, the salt and position hashes, so
the same strokes give the same world. Only emerged plants and new water are
nudged. Hand, pinned and generated work never is, and cells marked hand still
refuse every arrival.

### Water (`water_brush.gd`, on the pour's worker)

- **Level.** When a new pond's level floods a thin fringe, it may sit up to
  `LEVEL_TRIM` (5 cm) lower, in `LEVEL_STEPS`. A trim is taken only when it
  improves the pond's shore quality by more than `LEVEL_MARGIN` after paying
  `LEVEL_COST` for the share of water given up. That water soaks in, as water
  shallower than `MIN_DEPTH` already does. Never below the pond it replaces.
- **Hollow site.** Lost water scoops a hollow where it came to rest. The site
  may move up to `SITE_REACH` grid cells (1.5 m) to ground within
  `SITE_SLACK` (12 cm) of the chosen low. It moves when that leaves no strip of
  land thinner than `SLIVER_GAP` (2 m) between the new pond and existing
  water. A third of the overview pulls a little. Distance and height push back.
- **Hollow shape.** A hollow is a soft oval, `SCOOP_STRETCH` (1.1–1.35) long
  for wide, keeping the bowl's area. It lies along the contour where the
  ground slopes, so a pond lies along a hillside and is not cupped into it. On
  flat ground it lies at a hashed angle. The long radius stays clear of the
  rim, and the bowl deepens to hold its water.

### Edges (`emergence.gd`)

- **Forest edges.** Where the forest wish's own edge reads as a ruled line
  (`straightness` of the wish, `STRAIGHT` 0.72–0.93 over 9 × 9 cells), a
  candidate reads the wish a little way off, up to `WARP` × straightness
  metres along slow one-octave noise (`FRAY_FREQUENCY`, bays of about 5 m).
  The edge then wanders into bays and bulges both ways. A guided forest stroke
  plans candidates up to `WARP` past its bounds so a bulge can grow. The
  existing fray (scatter and lobes) still applies on top. A curved or round
  wish reads 0 and is not warped.
- **Lone trees.** A tree with no other tree likely within `LONE_RADIUS` (3 m)
  usually does not take (`LONE_DROP` 0.7 × gain). "Likely" counts candidates
  whose roll would pass on the planned ground, and trees already standing. A
  tree on a feature spot stays: it reads as a feature tree. Trees inside a
  wished forest are never counted as lone.

### Variant choice

- **Size.** A plant's size leans between two hash draws: toward the larger on
  a feature spot and toward the smaller in front of water.
- **Sightlines.** Outside a forest's core, a tree in front of water (within
  `SIGHT_REACH`, 4 m, toward the camera) keeps `1 - SIGHT_THIN × sight × gain`
  of its chance. Clearings keep their view of the water. A wished core is
  left alone.
- **Rotation** stays a plain hash. The models read the same from every side,
  so there is nothing for the score to choose between.
- **Kind** is left alone. Tree variety is still to be discussed with the user
  (PLAN.md, "Tree variety").

### Spacing

- **Clutter.** Undergrowth with `CLUTTER_MAX` (3) plants already within
  `CLUTTER_RADIUS` (1.2 m) usually yields (`CLUTTER_DROP` 0.6 × gain).

Refusals show in `emergence.refusals` as `sightline`, `lone` and `clutter`.
Size leans are counted in `emergence.guided_sizes`, and water changes in the
plan's `guided` entry (`trims`, `moved`, `ovals`).

## Tunables

All tunables are constants at the top of `scripts/quiet_guidance.gd`.

| Constant | Value | Meaning |
|---|---|---|
| `WEIGHTS` | see above | The score's term weights. |
| `REACH` | 4 m | How far a region's fields reach past its rect. |
| `STRAIGHT`, `STRAIGHT_WINDOW` | 0.72–0.93, 4 cells | Where an edge starts and finishes reading as ruled, and the window either side. |
| `WARP`, `FRAY_FREQUENCY` | 3 m, 0.18 /m | How far a ruled forest edge reads its wish off, and the size of its bays. |
| `OUTLINE_REACH`, `OUTLINE_WINDOW` | 3 m, 6 cells | The score's canopy outline kernel and straightness window. |
| `LONE_RADIUS`, `LONE_DROP`, `FEATURE_KEEP` | 3 m, 0.7, 0.5 | Lone trees. |
| `SIGHT_REACH`, `SIGHT_THIN` | 4 m, 0.55 | Sightlines to water. |
| `CLUTTER_RADIUS`, `CLUTTER_MAX`, `CLUTTER_DROP` | 1.2 m, 3, 0.6 | Undergrowth spacing. |
| `LEVEL_TRIM`, `LEVEL_STEPS`, `LEVEL_COST`, `LEVEL_MARGIN` | 5 cm, 5, 0.6, 0.04 | Pond level trims. |
| `THIN_WEIGHT` | 5 | How hard thin water or land marks a shore down. |
| `SITE_SLACK`, `SITE_REACH`, `SLIVER_GAP` | 12 cm, 3 cells, 2 m | Hollow sites. |
| `SCOOP_STRETCH` | 1.1–1.35 | Hollow ovals. |

`QuietGuidance.enabled` is false with `--no-guidance`. `water_enabled` turns
off only the water nudges, which the probe uses to hold the ground fixed.

## Probe and A/B numbers

`godot --headless --path . -s res://tools/probe_guidance.gd -- --plain-seed 7 --salt=12345`

On the plain, the probe paints a standard set of strokes: a hill, three pours
(at the hill's foot, on open ground, and beside the first), a ruled forest band
18 m long across the back, and a round copse. It lets emergence run to rest and
scores each stroke's rect and the plate. It does this three times: guided,
guided with the water nudges off ("plants only", same ground), and unguided.
It prints the scores, what emerged, the refusals and what changed. `--cases`
runs only the made-up water and edge cases.

Measured 2026-09-27, plain seed 7, salt 12345. The score deltas are guided
minus unguided.

| Rect | Unguided total | Plants only | Guided | What moved |
|---|---|---|---|---|
| Plate | 0.749 | 0.756 (+0.007) | 0.750 (+0.001) | Plants only: openness +0.039, framing +0.003, variety +0.007. Guided: variety +0.023, framing −0.018. |
| Forest band | 0.645 | 0.662 (+0.017) | 0.658 (+0.013) | Openness +0.08 to +0.11, variety +0.02 to +0.08. |
| Pour at the hill's foot | 0.685 | 0.690 (+0.005) | 0.704 (+0.019) | Openness +0.05 to +0.15. |
| Pour beside it | 0.642 | 0.646 (+0.004) | 0.621 (−0.021) | Guided: the pond it made unguided did not form (below). |
| Hill | 0.662 | 0.662 | 0.606 (−0.056) | Guided: the same lost pond. |
| Round copse | 0.440 | 0.440 | 0.440 | Nothing (a round wish is not warped). |

What changed, out of 166 emerged plants:

- **Plants only (the same ground):** 3 plants appear and 2 go. 33 plants change
  size (29 lean larger and 6 smaller). Refusals: 13 `clutter` and 8
  `sightline`. No tree was lone on this plain. Its woodland habitat is dense
  enough that every tree had likely neighbours.
- **Forest band:** the band's wish reads straight (0.86 mean over its edge
  cells), and the warp moves its wish by 0.69 m on average. 13 of its 98 tree
  candidates flip their roll. Most of those were crowded out either way, so
  the band ends with 34 trees instead of 35. Unguided, the score already reads
  the band's canopy edge as not straight (`edge_straight` 0). The existing
  scatter and lobes break it at the tree scale. The warp adds slower bays of
  about 5 m on top.
- **Guided, water too:** the two hollows are ovals, 213 terrain vertices
  differ, and 7 plants appear and 10 go. The oval at the hill's foot changed
  where the third pour ran. Unguided, that pour filled a new pond at (−5.5,
  3.5) and overflowed into the foot pond (level 0.189). Guided, it all ran
  into the foot pond (level 0.201). The plate reads the same (+0.001). The
  hill's rect reads worse because it lost that pond. No pond level was
  trimmed and no hollow moved on this plain.
- **Made-up cases (`--cases`):** a hollow whose water came to rest with
  1.2 m of land between it and a pond moves 1.5 m to (4, 0). It merges with
  the pond's edge instead of leaving the strip, as an oval stretched 1.21 at
  134°. A round pond with a one-cell channel running off it just under its
  level (0.25 m) settles at 0.21. That trims the 9-cell tongue, and its shore
  quality goes from 0.42 to 1.0. The edges term reads a ruled wood at 0.75
  (`edge_straight` 0.25), and the same wood with bays or a round copse at 1.0.
- **`--no-guidance` is the old path exactly.** `probe_emergence.gd -- 184`
  prints the same census as `main`. `probe_water_brush.gd -- --plain-seed 7
  --land` prints the same six plans. With guidance on, that water probe gives
  the same ponds, a few centimetres apart in level (the oval bowls) and up to
  0.5 m apart in seed position.

## Cost

- **Planning (worker).** A region's guide takes 1.8–2.8 ms on the emergence
  worker (fields, score and likely mates). A pour's plan costs the same with
  or without guidance (probe_water_brush: 26.7/63.4/33.4/88.2/83.5/33.4 ms on
  `main`, 26.6/62.6/34.4/88.9/82.0/23.1 ms guided).
- **Main thread.** Taking the plants for a plan is one pass over the records
  near the stroke. The plan's main-thread start was 0.42–0.93 ms guided and
  0.36–0.89 ms unguided across the profile runs. Arrival steps that plan nothing
  cost a p95 of 0.27 ms against 0.15 ms, and at most 0.94 ms against 0.56 ms
  (probe, 914 steps).
- **Frames.** Headless `tools/profile_stroke.gd --watch=25 --salt=12345`, two
  rounds each. The machine was shared with other agents, and the plain's
  draw differs per launch, so water runs differ in what they pour into.

  | Brush | Stroke max, guided / off | Settle max, guided / off | Settle frames over 16.7 ms, guided / off |
  |---|---|---|---|
  | Land | 10.3, 10.2 / 10.4, 10.1 ms | 18.3, 11.8 / 15.9, 11.3 ms | 1, 0 / 0, 0 |
  | Water | 10.0, 10.0 / 10.0, 9.8 ms | 16.7, 14.4 / 15.2, 13.7 ms | 1, 0 / 0, 0 |
  | Forest | 10.4 / 10.2 ms | 13.4 / 10.8 ms | 0 / 0 |

  The single 18.3 ms land frame (the first round, 8.8 s after release, not in
  a refresh stage) did not come back in the second round. Neither did the
  16.7 ms water frame. Settle medians are 8.33 ms in every run, and settle
  p95s are 8.5–9.1 ms in every run.

## Unverified

Nothing was rendered. Everything here is headless numbers. Still to judge on
screen:

- Whether a guided forest band's bays read as natural or as wobble.
- Whether oval hollows read as ponds lying in the land.
- Whether thinner trees in front of water read as a clearing that keeps the
  view, or as a gap.
- Whether bigger trees on knolls and shores read as placed.

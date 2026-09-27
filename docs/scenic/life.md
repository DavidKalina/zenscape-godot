# Life answers the land

Phase 3, slice 3 (`feature/life-answers`). Fish, frogspawn, frogs, birds and fireflies find their places in the world as it stands now, and arrive in their own time. Herons, deer, a rainbow and, very rarely, a glimpse of Bigfoot come when a place has become rich. Nothing is placed by the player.

- `scripts/land_life.gd`: the scheduler and the everyday creatures.
- `scripts/life_survey.gd`: what the land offers, read from the live world.
- `scripts/life_moments.gd`: the rare moments.
- `scripts/life_models.gd`: low-poly procedural meshes for the fish, frogspawn, heron, deer and the Bigfoot silhouette.
- `tools/probe_land_life.gd`: the headless probe.

`studies/fidelity_life.gd` builds `LandLife` after the fish and dead wood. It runs only on blank worlds: the Genesis plain and generated worlds. The Fidelity reference world keeps its authored birds, frogs and fireflies. `--no-life` turns the whole system off, for A/B timing.

## When the world is read

The editor reports change and LandLife re-reads the world. Nothing scans the world every frame.

- **Signals:** `play_geometry_changed` (every settle refresh, including emergence steps), `stroke_finished`, and `state_restored` (undo, load, new world).
- **Timing:** a survey starts once the editor is idle (not painting, no refresh pending, not forming) and has been quiet for `SURVEY_QUIET` (0.6 s). A finished stroke, an undo or a new world is urgent. Plain geometry changes, such as emergence stepping every 0.75 s, re-read at most every `SURVEY_GAP` (4 s).
- **Slicing:** a survey runs in slices of `SURVEY_BUDGET_USEC` (1.2 ms) a frame. The stages are: object buckets, heights row by row, pond triangles 64 at a time, stream beds one route at a time, slopes row by row, water bodies, water distance, then places row by row. A survey that is running finishes before the next one starts.
- **Planning:** a finished survey is planned one creature kind per frame.

### What a survey sees

The grid is 56×56 at 0.5 m, aligned with the terrain's cover cells.

- **Ground:** live heights (`data.ground_height`).
- **Still water:** the pond triangles the view drew (`GardenView.pond_vertices`). Each triangle's water stands at its vertices' height. This is free, and it matches what is on screen. Water from the water brush lands there as long as that branch draws its water through the pond mesh.
- **Flowing water:** stream beds from `data.streams`, marked as water 6 cm deep.
- **Plants:** trees and shrubs from `data.objects`, of every provenance, bucketed on a 1 m grid.

From these it derives:

| Place | Rule |
|---|---|
| Water body | 4-connected still water; at least `MIN_BODY_AREA` (1.5 m²) to count as a pond |
| Deep | inner cells of a body at least `DEEP` (0.22 m) deep |
| Shallow edge | body cells beside land, 0.02-0.2 m deep |
| Wading | body cells 0.05-0.32 m deep |
| Bank | dry cells beside a body, slope under 0.9 |
| Forest edge | open ground with grass cover ≥ 0.2, slope under 0.4, no tree in its own metre, a tree in the next metre, and at least 3 trees within 3 m, mostly to one side. `into` points into the trees. |
| Damp | dry ground within 3 m of water with grass ≥ 0.35, a shrub or trees near |
| Richness | water area /12 (≤1.5) + stream cells /30 (≤0.6) + trees /12 (≤1.5) + shrubs /30 (≤0.8) |

## Arrivals: conditions plus a delay

Each kind keeps sites keyed by survey cell. This works like emergence's candidates:

- **Choosing sites:** up to a capacity per water body. Sites that already stand keep their place while they still qualify. New ones are taken in position-hash order (`salt` is emergence's world salt) with a minimum gap. The same strokes on the same world bring the same life.
- **Arrival:** a site is born when its conditions first hold. Its creature arrives after `delay + spread × hash` seconds of the life clock.
- **Departure:** a site whose conditions go away sends its creature off. Fish sink and fade, frogspawn shrinks, frogs hop away up the bank, birds fly off into the distance, and fireflies dim. A site that has not arrived yet simply closes.
- **Settled worlds:** a new, regrown or loaded world starts settled. Its first sites start `SETTLED_HEAD` (85%) of the way through their delay, so a generated world comes alive within a few seconds. An undo keeps whatever still fits, and new sites wait their full delay.
- **The clock:** the life clock is real seconds and stops while the scene is paused or the world is regrowing. `pace` multiplies it for probes.

| Kind | Needs | Delay + spread (s) | How many |
|---|---|---|---|
| Fish | deep cells of a pond | 10 + 16 | one per 2 m², at most 7 a pond and 24 in all |
| Frogspawn | shallow still edges, not in winter (`SPAWN_SEASON` 1, 0.7, 0.3, 0) | 22 + 26 | 1 + area/10, at most 3 a pond and 9 in all |
| Frogs | a bank of water that already holds frogspawn | 16 + 22, counted from the spawn's arrival | 2 a pond, 6 in all |
| Birds | shores and woods | 6 + 24 | one per 14 bank cells + one per 10 trees + one for a stream, at most 8 |
| Fireflies | damp undergrowth | 12 + 22 | up to 64, 0.7 m apart |

What each creature looks like and does:

- **Fish:** low-poly koi (orange, gold, silver, cream) circle their home and never swim out of wet cells. Now and then one rises and leaves a ring, more often in low light.
- **Frogspawn:** clumps of pale beads with dark eggs, floating flat at the water level and following the level if it changes.
- **Frogs:** the Fidelity frog mesh and its pond loop. They sit on the bank, leap into the nearest water, paddle and hop back.
- **Birds:** the Fidelity gulls with their thermal flight model (`studies/bird_flight.gd`). They fly in from beyond the plate over three thermals, which rise above the two biggest waters and the highest ground.
- **Fireflies:** the scene's own 90 fireflies. On a blank world every one starts absent. `INSTANCE_CUSTOM.w` in `reference_fireflies.gdshader` is now absence, and each firefly fades in at its place. They glow at dusk as before. Leaving a blank world restores the Fidelity positions.

## Moments

Checked every `CHECK` (2 s) of life time. Each moment has its conditions, a delay after those first hold, a chance per check and a cooldown, so it stays rare. Every moment is logged in `moments.history` and emitted as `LandLife.moment(kind, position)`, which is ready for sound (slice 6).

| Moment | Conditions | Chance per check | Cooldown (s) |
|---|---|---|---|
| Heron lands | a pond with ≥ 2 fish settled for 30 s and wading water; daylight > 0.25; rain < 0.3 | 0.06 | 240 |
| Deer at dawn | ≥ 6 trees; a forest edge that has stood 25 s; celestial phase 0.2-0.36; rain < 0.3 | 0.25 | 300 |
| Rainbow after rain | ≥ 8 s of rain above 0.25 that then stops (< 0.06); richness ≥ 1.2; daylight > 0.35 | 0.6 once per rain | none |
| Bigfoot glimpse | scenery mode and Bigfoot not resident; ≥ 14 trees; richness ≥ 2; dawn (phase 0.2-0.36) or dusk (phase 0.64-0.8); an edge with ≥ 8 trees near, at least 18 m from the camera, seen from the open side | 0.006 | 1200 |

What each moment looks like:

- **Heron:** glides in from off the plate along a curve over 7 s with slow wingbeats, legs trailing, then brakes and lands with a ring. It stands in the shallows 45-90 s, and its neck strikes at the water every 7-14 s. It flies off early if rain comes or the water goes.
- **Deer:** a doe, and half the time a fawn, step out of the trees to the edge at 0.42 m/s. They graze, head down for 5-11 s and up for 2-4 s, for 25-45 s, and leave when their time is up or the sun climbs. They walk back into the wood and fade inside the trees.
- **Rainbow:** `celestial.moment_bow`, a new term in `studies/celestial.gd` next to `rainbow_strength` and `weather_bow`, rises to 0.85 over 6 s, holds 30 s and fades over 10 s. It is never saved.
- **Bigfoot:** a dark procedural silhouette about 2.1 m tall stands just inside the trees for 5 s, turns and walks back into the wood, and is gone about 9 s after it appeared. It uses no model or rig, only faceted spindles in one colour. The resident Bigfoot is untouched.

`moments.force(kind)` starts one now for probes. It skips the delay, chance and hour, but not the place it needs.

## Models

`life_models.gd` builds everything from faceted spindles (a bipyramid over a 4-7 sided ring) and flat fans, with vertex colours and a slight per-face shade. It uses the Fidelity frog's own `reference_surface` material (flat faces, scene palette), so the models sit in the painted look and share a pipeline that is already compiled.

| Model | Triangles |
|---|---|
| Fish | 12 + 2 fins |
| Frogspawn clump | 22 icosahedra |
| Heron | 5 parts, the wings shown only in flight |
| Deer | 7 parts: body, neck and head, 4 legs |
| Glimpse | 1 mesh |

Fish, frogspawn, frogs and rings are MultiMeshes with fixed slots. The heron, the two deer and the glimpse are built once at setup and hidden.

## Cost

Measured headless, CPU only, on 2026-09-26:

- **`tools/probe_land_life.gd -- --pace=6 --watch=20`:** a plain with a dug pond and 14 trees.
  - LandLife per frame: median 0.07 ms, p95 0.11 ms, max 1.7 ms (a survey slice).
  - A survey is about 21 ms of work in total, spread over about 20 frames. The worst single step is 1.5 ms.
  - The only frame over 16.7 ms is the editor's own synchronous undo refresh (about 50 ms, LandLife 0.1 ms in it).
- **Generated worlds** (`--world-seed=198` marsh, `--world-seed=79` glacial valley):
  - LandLife p95 0.22 ms per frame.
  - A survey is 17-25 ms in total, worst step 1.7-2.9 ms.
  - All frames under 12 ms.
  - Everything settled arrives within about 5-11 s of the world appearing.
- **`tools/profile_stroke.gd -- --mode=land --watch=60`, with and without `--no-life`:** the same shape.
  - Stroke frames p95 10.3 / 10.8 ms, settle p95 9.0 / 9.4 ms.
  - The one slow settle frame is emergence's first plan (22-31 ms) either way.

## Probe

```
godot --headless --path . -s res://tools/probe_land_life.gd -- --pace=6 --watch=20
godot --headless --path . -s res://tools/probe_land_life.gd -- --pace=1 --watch=12 --world-seed=198
```

The first command digs a pond on the plain and stands a small wood beside it. It prints a per-second timeline of what is present, the survey, arrivals and moments, then forces each moment. Last, it drains the pond (the water life leaves) and undoes the drain (it comes back after its delays). The second regrows a generated world and watches it come alive.

## Tunables

All of these are constants at the top of `land_life.gd` and `life_moments.gd`:

- `DELAYS`, `SETTLED_HEAD` and the per-kind caps and gaps.
- `SURVEY_BUDGET_USEC`, `SURVEY_QUIET` and `SURVEY_GAP`.
- Each moment's `*_DELAY`, `*_CHANCE`, `*_COOLDOWN` and `*_STAY`, and the `DAWN` and `DUSK` phase windows.

The survey's thresholds are at the top of `life_survey.gd`: `DEEP`, `SHALLOW_*`, `WADE_MAX`, `MIN_BODY_AREA`, `FOREST_*` and `DAMP_REACH`.

## Open

- Everything visual is unverified: the models, the palette they take, and how the heron's and deer's motion read on screen. Headless runs do not draw.
- Fish live in ponds only, not streams.
- Life is not saved. A loaded world starts settled instead.
- Deer need the dawn window. The plain's clock is frozen at its launch hour, so a plain launched at full day never sees deer until the day turns.
- Sound hooks: `LandLife.arrived` and `LandLife.moment` are emitted but nothing listens yet.
- `fidelity_fish.gd`, Bigfoot's catchable fish, still seeds from the Fidelity water once at startup. It is separate from these ambient fish and only matters with `--bigfoot`.

# Life answers the land

Phase 3, slice 3 (`feature/life-answers`). Fish, frogspawn, frogs, birds and fireflies find their places in the world as it stands now, and arrive in their own time. Herons, deer, a rainbow and, very rarely, Bigfoot come when a place has become rich. Nothing is placed by the player.

- `scripts/land_life.gd`: the scheduler and the everyday creatures.
- `scripts/life_survey.gd`: what the land offers, read from the live world.
- `scripts/life_moments.gd`: the rare moments, and when Bigfoot may come.
- `scripts/life_bigfoot.gd`: the Bigfoot sighting: where he stands, what he does, when he leaves.
- `scripts/life_models.gd`: low-poly procedural meshes for the fish, frogspawn, heron and deer.
- `tools/probe_land_life.gd` and `tools/probe_bigfoot_sighting.gd`: the headless probes.

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
- **Settled worlds:** a new or regrown world, or one loaded from a save that kept no life, starts settled. Its first sites start `SETTLED_HEAD` (85%) of the way through their delay, so a generated world comes alive within a few seconds. An undo keeps whatever still fits, and new sites wait their full delay.
- **Saved life:** the place's save keeps its life (`NativeGardenStore` `land_life`, from `LandLife.document`): `{"version": 1, "clock": s, "sites": {kind: [[key, delay, age, here], ...]}}`. `key` is the survey cell (a bird's slot), `age` the life-clock seconds since the site's conditions first held, and `here` whether its creature had arrived. Leaving and closing sites are not saved, nor are moments. On load, `restore_document` sends the old world's life away and holds the saved sites until the first survey of the loaded ground. That survey reopens the saved sites that still qualify ahead of new ones, with their own delays and ages. Creatures that had arrived come back at once, already grown in (frogs sitting on their bank). They count in `LandLife.resumed`, not `arrivals`, and do not emit `arrived`. Sites the save did not know wait their full delay. The life clock only moves forward on load, since moments keep their cooldowns on it.
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
| Bigfoot | see "Bigfoot: when he comes" below | up to 0.006 × light × weather | 1200 |

What each moment looks like:

- **Heron:** glides in from off the plate along a curve over 7 s with slow wingbeats, legs trailing, then brakes and lands with a ring. It stands in the shallows 45-90 s, and its neck strikes at the water every 7-14 s. It flies off early if rain comes or the water goes.
- **Deer:** a doe, and half the time a fawn, step out of the trees to the edge at 0.42 m/s. They graze, head down for 5-11 s and up for 2-4 s, for 25-45 s, and leave when their time is up or the sun climbs. They walk back into the wood and fade inside the trees.
  The deer are a rigged Blender model (`assets/models/zenscape-deer.glb`, built by `tools/blender_creatures/deer.py`, clips in `deer_clips.py`) played through `scripts/life_rigs.gd`: Walk synced to ground speed (the fawn's legs run faster), HeadDown into Graze, and HeadUp into Alert on the first lift of a visit, then Look or Idle in turn. Clips advance on the life clock. `--classic-life` brings back the code-built deer from `life_models.gd`.
- **Rainbow:** `celestial.moment_bow`, a new term in `studies/celestial.gd` next to `rainbow_strength` and `weather_bow`, rises to 0.85 over 6 s, holds 30 s and fades over 10 s. It is never saved.
- **Bigfoot:** the ambient model steps out of the wood, watches you and goes back in, or strides across in front of it like the 1967 film. See "Bigfoot" below. The resident Bigfoot (`--bigfoot`) is untouched.

`moments.force(kind)` starts one now for probes. It skips the delay, chance and hour, but not the place it needs. For Bigfoot the kinds are `bigfoot` (any sighting), `bigfoot_watch`, `bigfoot_listen` and `bigfoot_stride`.

## Bigfoot

The rarest thing in the world: a moment you might tell someone about. It is scenery mode only (`scenery_mode` and no resident), so `--bigfoot` and the old game never see it. The sighting is `scripts/life_bigfoot.gd`, owned by `LifeMoments`.

### When he comes

Every `CHECK` (2 s) of life time, while all of these hold:

| Condition | Rule | Why |
|---|---|---|
| A mature wood | ≥ 18 trees (`BIGFOOT_TREES`), richness ≥ 2.0, and a forest edge with ≥ 7 trees within 3 m (`BIGFOOT_EDGE_TREES`) | 18 trees fill the survey's tree share of richness (1.5), so 2.0 also needs undergrowth or water: a whole place, not a plantation. A dense edge gives him somewhere to come out of and go back into. A true edge has trees on one side only, so its 7×7 m count runs at about half the wood's density. 9 rejected the real edges of a 1.9 m-spaced wood and kept only gaps inside it. |
| Held a while | all of the above for 10 minutes of life (`BIGFOOT_SETTLE` 600 s) | The minimum session time. A wood has to have stood a while. Nobody paints a forest and gets him straight away. Loaded worlds wait too. |
| A quiet world | not painting, and no stroke for 45 s (`BIGFOOT_QUIET`) | He comes when you sit back and watch, not while you work. |
| Low light | dawn and dusk (phase 0.2-0.36 and 0.64-0.8) weigh 1; night weighs 0.6 (`BIGFOOT_NIGHT`); full day weighs 0, except in mist (fog ≥ 0.45, `BIGFOOT_MIST`), which weighs 1 | The classic hour is dusk. At night he is harder to see, apart from his eyes. |
| Weather | mist, or the 3 minutes after rain above 0.25 (`BIGFOOT_AFTER_RAIN`), multiplies the chance by 1.75 (`BIGFOOT_DAMP`); a downpour (rain > 0.5) keeps him in | A damp, grey wood is his weather. |
| Cooldown | 20 minutes after he leaves (`BIGFOOT_COOLDOWN` 1200 s) | So a second sighting is its own event. |

The chance per check is `BIGFOOT_CHANCE` (0.006) × light × weather. On a win he is "about" for 90 s (`BIGFOOT_ABOUT`). He shows at the first check that finds an edge the camera can see:

- 14-60 m from the camera, seen from the open side.
- A real edge: no trunk within 1.1 m of the line from him toward the camera for 8 m (`OPEN_REACH`, `OPEN_WIDTH`). The survey also calls gaps inside a wood "edges", and this check leaves those out. It applies to forced sightings too.
- On screen, inside an 8% margin.
- Camera no more than 55° above him.
- Walkable footing (below).

If no such edge comes up in those 90 s, he passed by unseen, and nothing counts against the cooldown.

**The numbers.** The world clock's day is 480 s. With its horizon linger, dawn and dusk take 37% of real time, night 37% and full day 26%. So a clear day averages light 0.37 + 0.37 × 0.6 = 0.59. That is 0.006/2 × 0.59 ≈ 0.0018 sightings a second of eligible time, a mean wait of about 9.4 minutes.

- **A player who sits back and watches a rich world:** first sighting after about 10 + 9 ≈ 20 minutes, and about one every 30 minutes after that (20-minute cooldown + wait). The chance of none in the first hour is under 1%.
- **A player who keeps painting half the time:** about 10 + 19 ≈ 30 minutes to the first, about one every 40 minutes after that, and a 7% chance of none in an hour.
- **Mist or after rain:** 1.75 × as likely, and mist lets him out by day.
- **Missed chances:** camera placement makes some "about" windows pass unseen, so real sessions run a little rarer than these figures.

That is the target: roughly once per 20-40 minutes of a rich world, rare enough to remember and likely in a long session.

The plain's clock must turn for any of this outside mist. `_phase()` reads `celestial.phase`, which is the world clock's, so dawn and dusk arrive once the plain's day runs.

### What he does

He stands 2.21 m tall at scale 1, the model's own height, next to 3-6 m trees. He faces +Z, and his root sits on the live ground height (`data.ground_height`) at his position every frame. The clips carry their own foot placement. `life._rng` picks the sighting: 40% stride, 40% watch, 20% listen. If that one finds no footing, the others are tried.

- **Watch** (about 25 s): he walks out of the trees (`Walk`, 0.336 m/s) from 1.8 m inside to 0.4 m outside the edge, turns to the camera and plays 9.5 s of `Watch`: the glance, the slow turn to face you and the long look. Then he walks 3.4 m back into the wood with `WalkGlance`, looking back over his shoulder.
- **Listen** (about 25 s): the same, with 9 s of `Listen`. His body turns 0.42 rad away from the camera, so the sound he finds with his head is you, off to his left.
- **Stride** (about 13 s): the film. An arc of about 12.5 m from 1.8 m inside the wood, out 0.6 m into the open along the edge, and back in. The edge must run side-on to the camera (`STRIDE_FACING`). He plays whole `Stride` cycles, then `StrideLookL` or `StrideLookR`, whichever looks toward the camera, then `Stride` again. The clips chain on the same heel strike with no blend, and the look is centred on the arc. He moves at the rig's `stride_speed_mps` (0.97 m/s), so the feet do not slide.
- **Leaving early:** if the camera comes within 9 m, closes faster than 5 m/s within 30 m, or a stroke lands within 10 m, he turns into the trees and strides 3.4 m in (`leave(why)`).
- **Appearing and going:** he grows over 0.6 s as he appears inside the trees and shrinks over the last 0.6 s, again inside the trees, as the deer do.
- **Eyes:** the eye surface keeps its dark amber vertex colour and gains an amber emission, 1.4 × (1 − smoothstep(0.03, 0.28, daylight)) (`EYE_GLOW`). This is the original game's darkness fade, so they glow only at night: two small amber points at 22 m, and nothing by day. At 0.55 they did not show at all.

**Footing.** Every point of a path must be:

- inside the plate (±12.8 m);
- on ground with a height;
- dry (`survey.wet_at`);
- gentle: a rise of no more than 0.45 per metre, sampled ±0.35 m around it. Steep rock fails this, and the survey's edge rule already asks for grass cover.
- clear of tree trunks: 0.5 m in the open, 0.32 m inside the wood.

**Peek not used.** `PeekL`/`PeekR` are authored against a 0.42 m trunk radius. The plain's emerged trees are much thinner, so he would grip air, and a thin trunk would not hide him. They can come in with the hero trees.

### Cost

- **Model load:** once, on a worker thread (`ResourceLoader.load_threaded_request`) when LandLife sets up. LifeMoments polls it on its 2 s check and builds it hidden: coat and eyes get `reference_surface` materials, and the AnimationPlayer runs in manual mode. Nothing loads on the frame he appears.
- **Hidden:** `visible = false`, and the AnimationPlayer is not advanced, so nothing runs.
- **Per frame while he shows:** one `AnimationPlayer.advance`, one ground sample and one camera distance.
- **Placement:** runs once, when he appears.
- **Measured headless (`tools/probe_bigfoot_sighting.gd`, 2026-09-26, 40 trees + 24 shrubs):**
  - Placement plus the first frame (`force`): 0.8-1.2 ms.
  - Per frame while he shows: median 0.05 ms, p95 0.10 ms, max 0.5 ms.
  - Building the model from the threaded load: 0.1-0.3 ms.
  - All frames p95 8.7 ms, max 13.5 ms.
- **Ground contact:** the lower foot's bone heads, less their rest height, sit -4 to +2 cm from the live ground over whole sightings (median about -0.7 cm). Paths never cross water, and the steepest ground under him was 0.1.
- **Shyness:** zooming the camera onto him sends him off ("camera closing"), and so does a stroke 3 m away ("painting near").
- **The dice:** at dusk with `--natural=50 --pace=30`, he settled at 10 minutes of life and came about 7 minutes later, then the cooldown held.
- **Rendered stills** (`--stills`, dusk and night, camera 22 m) show him grounded, in scale with the trees, and reading well: a Watch facing the camera at the wood's edge, the stride with StrideLookL, and the night Watch with the eyes lit.

### Forcing a sighting

- `moments.force("bigfoot")`, `"bigfoot_watch"`, `"bigfoot_listen"` or `"bigfoot_stride"` start one now. They prefer an edge on screen and fall back to any edge with footing.
- `--force-bigfoot` on the command line (or `--force-bigfoot=watch|listen|stride`) brings him as soon as the wood qualifies (the survey's trees and edge, not the hour, settle time or chance), and again 12 s after each sighting ends, for filming. Example: `godot --path . -- --force-bigfoot=stride`.

## Models

`life_models.gd` builds everything from faceted spindles (a bipyramid over a 4-7 sided ring) and flat fans, with vertex colours and a slight per-face shade. It uses the Fidelity frog's own `reference_surface` material (flat faces, scene palette), so the models sit in the painted look and share a pipeline that is already compiled.

| Model | Triangles |
|---|---|
| Fish | 12 + 2 fins |
| Frogspawn clump | 22 icosahedra |
| Heron | 5 parts, the wings shown only in flight |
| Deer | 7 parts: body, neck and head, 4 legs |

Fish, frogspawn, frogs and rings are MultiMeshes with fixed slots. The heron and the two deer are built once at setup and hidden. Bigfoot is the ambient model (`assets/models/zenscape-bigfoot-ambient.glb`, about 1,860 faces, 27 deform bones), loaded once on a worker thread.

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
godot --headless --path . -s res://tools/probe_bigfoot_sighting.gd
godot --headless --path . -s res://tools/probe_bigfoot_sighting.gd -- --natural=60 --pace=30
godot --path . -s res://tools/probe_bigfoot_sighting.gd -- --stills=/tmp/zs-bigfoot-sighting
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
- Moments (heron, deer, rainbow, Bigfoot) are not saved; they come round again on their own conditions.
- Deer need the dawn window. In creation mode the plain's day now turns (`scripts/cozy_regrowth.gd`, `PLAIN_DAY_LENGTH` 1200 s per day, the night eased through from phase 0.8 to 0.2), so a plain launched at full day reaches dawn within six to eight minutes. Generated worlds still hold their hour.
- Sound hooks: `LandLife.arrived` and `LandLife.moment` are emitted but nothing listens yet.
- `fidelity_fish.gd`, Bigfoot's catchable fish, still seeds from the Fidelity water once at startup. It is separate from these ambient fish and only matters with `--bigfoot`.

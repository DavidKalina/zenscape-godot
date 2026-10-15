# The generated layer, round 14: city layers (2026-10-14)

> Branch `layer/city-layers`, cut from `roguelike` at 6f57749a. This is
> step 3 of `game-v1-brief.md` ("The city into the generator"). It's a
> prototype round, so it has smoke checks and throwaway drivers in
> `scratch/` and no new tests.

## Play

```sh
./run-game.command                 # the title, then a city run (torch), every region underground
./run-run.command                  # two city regions (haze), then the sky
<godot> --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --world=under [--seed=N] [--knob=greybox=face]
```

N steps a region on, and Shift+N steps one back. The danger rises with the
region, so N twice from the start shows a layer-3 city.

## What changed

1. **Underground layers are made of city places.** The six city motifs are
   drawn as a deck: each one comes once before any repeats
   (`LayerPlan._draw`, with `_substitute` preferring motifs not used yet),
   and `UNDER_REPEATS` is 2.
   - Each layer has 2 or 3 neighbourhoods of 2 places each
     (`CITY_HOODS`, `CITY_HOOD`), plus a greed branch. That makes 5 to 7
     places, 3 or 4 of them on the way up.
   - The places are 150-250 m hillsides, so the city layer has a wider band
     (`CITY_BAND` 1100/420 m).
   - A city place climbs on its own: you go in at the foot and out at the
     top. So the tier step and the "the last isle is the highest" rule are
     off underground. With them on, 30 of 30 attempts failed on some seeds.
   - Plans take 2-12 s. Every seed from 1 to 10 lays, sprawl and ring.
2. **The sky kit is gone from underground.** The switch is
   `LayerWorlds.city(knobs)`, and `--knob=sky_kit=1` brings the old kit
   back.
   - Removed: the Loose Voussoirs (the route and the exit chain lay stones
     instead), the gust arrows, the Broken Viaduct, and the ferry (the ring
     links are serpent only).
   - New `scripts/roguelike/city_crossings.gd` builds the same plan
     geometry in city basalt:
     - stones become hex column tops on sunken shafts;
     - landings and slabs become squares on a corbel and a pier;
     - rope bridges become basalt causeway beams with a low curb and piers.
3. **A city start.** The base underground is
   `scripts/kit_isle/greybox/gb_city_landing.gd`, tagged `"base"` in the
   registry so it is never drawn into a pool.
   - It is a paved city pillar (44 m across) with a dais, six lit crown
     cressets, a rim on each face, and no head.
   - The aqueduct isle's own land is hidden and taken out of physics while
     a city layer stands, and its pools go with it
     (`run_layer._aqueduct_world`). It comes back for sky regions.
   - The walker waits at the spawn until the landing has stood (`_base_wait`).
   - The start spot doesn't place its gothic piers or lamp on it.
   - The HUD hint underground reads "Climb toward the gate's light...".
     There is no plane line.
4. **The city is always the sprawl shape.** `LayerShapes.after` returns
   sprawl underground. On a ring, the way up is one serpent ride and a
   link, which takes 3-4 min. `--knob=city_ring=1` brings the alternation
   back. `--shape=ring` still lays a ring as the first layer.
5. **Danger by height** (`LayerWorlds.danger`: 0 on region 1, +0.34 per
   region, capped at 1; `--knob=danger=` pins it). Each place's own Keepers
   are always there. On top of them:
   - The generator's wandering heads: 0 / 1 / 2 / 3 by region.
   - A body comes back after its head is left bare: after 6 s on region 1,
     down to 1 s at the top. Far spawns go from 20% to 45%.
   - The column-top gaps ease toward the greed branch's (`LayerPlan.mean`,
     up to 0.7), and the tops get smaller.
6. **The `--knob=greybox=<slug>` fix.**
   - The named motif is added to the pool in either world, and the first
     draw is that motif (it used to be any greybox). Before, the knob
     narrowed the sky "motifs" pool to the gorge plus the slug, and the
     slug was then filtered out, which gave "too few motifs drawn".
   - `missing` ignores the base.
   - run_layer lays the layer unforced if no seed holds the forced motif,
     and it never stands an empty plan (the old `spawn.face` crash).
   - 24/24 plan dumps place the asked motif (six slugs × sprawl/ring ×
     under/sky, seed 2).
7. **The gate underground.**
   - Its beam is 320 m tall and wider at the top, brighter, and not
     fogged.
   - A warm light sits on the threshold, with a lit crown cresset on each
     side.

## Layer times (rim to gate, through the real loop)

`scratch/pace.gd` drives the real input (the stick and the jump):

- It walks the landing and the approaches.
- On each crossing it presses the jump at each lip, top to top.
- It walks the exit chain into the gate, and the run loop takes it up.

Three parts of the time are not driven:

- **Inside each place.** My occupancy pathfinder can't follow the places'
  climbs and hollow ways. So the driver is set down at the place's way-out,
  and the time charged is that place's fastest route time from its own
  round's driver, which drove it through the real input in the yard
  (`brainstorm/round3-olmec-city/motif-*.md`):
  - court 78 s
  - face 51 s
  - colonnade 80 s
  - crossing 80 s
  - stair 57 s
  - pit 90 s
- **Serpent gulfs.** The time charged comes from the live serpent's real
  schedule: the wait at the pier plus the ride.
- **The chain cannon.** It is charged 8 s.

The "good player" column multiplies the walked and place time by 1.6, for a
good player who doesn't know the route yet.

| Run (seed 1, `--world=under`, layers in a row) | Region | Driver pace | Good player | Places on the way |
|---|---|---|---|---|
| Layer 1, seed 1 | 1 | 7.4 min | **10.9 min** | coliseum_pit, face, felled_colonnade, serpent_crossing |
| Layer 2, seed 2 | 2 | 6.8 min | **10.4 min** | face, stacked_court, lamplighters_stair, felled_colonnade |
| Layer 3, seed 3 | 3 | 7.2 min | **10.7 min** | felled_colonnade, stacked_court, serpent_crossing, lamplighters_stair |

All three went through the gate. Before the size change, layers were 3.6 and
5.1 min (good player 5.4 and 7.2 min). The plan-only estimate
(`scratch/estimate.gd`) over seeds 1-8 is 6.8-11.9 min, about 10 min on
average.

## Proof

- **Plan dumps:** `tools/sweep.py tools/layer_dump.gd --seed 1..10 --shape
  sprawl,ring --knob world=under --knob region=1`. 20 of 20 lay.
  - Every isle is a city place, and the base is the landing.
  - Edge kinds are stones, bridge (causeway), gulf, cannon and hard only.
  - There are no trap edges, no viaduct and no arrows. Ring gulfs are
    serpent only.
- **Smoke checks:**
  - `run_layer --world=under` on sprawl and ring, seeds 1-6: 12/12 passed,
    0 errors, the walker stood on the landing in all 12.
  - `studies/game_title.tscn` with run-game's flags passed.
  - `run_layer --world=sky` (seed 4) and with `--knob=greybox=face` passed.
  - The motif yard passed with `city_landing`, `stacked_court` and
    `editor_hill`.
- **run-run** (`scratch/runrun.gd`, seed 5): 3/3 checks.
  - Regions 1 and 2 stand on the landing with the aqueduct away.
  - Region 3 is in the sky, on the aqueduct isle, with the plane offered
    and the day look.
- **Stills** (rendered; downscaled in `layer-round14-city-layers/`):
  - `start.jpg`: the walker on the landing's paving, by the dais, the
    torch and the crown fires, under "THE CLIMB".
  - `start_toward_gate.jpg` (eye level): the next places' lit fires and
    stairs stand up in the murk, and the gate's beam rises over the far
    temple, 950 m off and 170 m up.
  - `mid_toward_gate.jpg`: from a mid-layer rim, the beam marks the exit
    chain's isle, and the serpent waits by the pier.
  - `region3.jpg`: region 3's start, with a lit crown cresset and the
    places' column silhouettes.
  - Judged: the way up reads, but the beam is a thin line at 950 m. I
    widened it after these stills; the wider beam hasn't been looked at.

## Tests this likely breaks (not run)

- **`tests/test_run_layer.gd` and `tests/test_layer_sprawl.gd`.** They open
  run_layer without `--world`, so they now play city layers, and they
  expect:
  - the aqueduct base;
  - rope bridges and the voussoirs;
  - both rides;
  - the roost.

  Their plan-only parts (region 0) are the sky's and are unchanged. A
  lock-in round should run them with `--world=sky` and add a city pass.

## Seams

- **The times inside places are borrowed, not driven here.** They come from
  each motif's own yard driver, times 1.6. The pace driver needed 3-4
  set-downs a layer, and 0-6 "saves" when a hop missed. A human playtest is
  the real number.
- **There is no city ring.** The ring's route underground was too short, so
  the city is all sprawl. The ring needs a real route (through several of
  its places) before it comes back.
- **Every place keeps its own Keeper.** A layer-1 city still has 4-6
  Olmecs; the danger scaling only adds the generator's heads and makes the
  bodies come back sooner. "Learnable" region 1 may need places to drop
  their Keeper by danger, which is a change in the motifs' files.
- **The landing is plain.** It is a paved pillar and six fires, with no
  turf, life or stele. A turfed or ruined landing is a dressing pass.
- **Rims are few.** Most places have one way in and one way out, so 40-60%
  of attempts fail ("no way onto"). More rims (the stacked court has 5)
  would make layers lay faster and vary more.
- **The causeways are plain beams.** They have curbs a hand high and no
  breakable bay, and their piers stop in the void. They could use the kit's
  `city_causeway` once its fixed spans can be fitted to a plan's length.
- **Column tops float.** Their shafts go 5-16 m down and stop in the haze,
  as the pillars' shafts do. They have no hanging roots or growth.
- **The aqueduct is hidden underground, not removed.** Its nodes stay in the
  tree: they are disabled and invisible. Its audio (the channel water) may
  still play near the landing. Not heard.
- **The gate is far.** The beam reads at 950 m but is thin there. There is
  no glow on the beam's top yet (the next region already has `_far_fire`).
- **Sky leftovers underground:**
  - the Plinth Ram on an arena;
  - the greed branch and chain cannons and their kegs. These are kept
    (the user keeps the ram and the cannon).
- **The aqueduct base is still the sky's.** It is also the ring's middle in
  the sky, as before.

## Open questions

1. How many Olmecs is right for region 1? Should places drop their Keeper
   below some danger?
2. Should the city get its own ring (a loop of places with a serpent),
   or stay sprawl only?
3. Is the landing what the start should be, or should it be a place with
   something to do?
4. Is 1.6× the motif drivers the right "good player" pace? The user's own
   playtest will set the size knobs: `CITY_HOOD`, `CITY_HOODS`.

## Knobs added

| Knob | Default | Does |
|---|---|---|
| `sky_kit` | 0 | 1 lets the sky kit back underground (voussoirs, arrows, viaduct, ferry, rope bridges, the aqueduct base) |
| `danger` | -1 (by region) | Pins the danger (0-1) |
| `city_ring` | 0 | 1 alternates sprawl and ring underground |

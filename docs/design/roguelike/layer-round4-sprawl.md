# The generated layer, round 4: the sprawl with an exit side (2026-10-12)

> Branch `worktree-agent-aae14c371e1287a44`, cut from `roguelike` at
> 90807441. Round 3 is layer-round3.md. Another agent prototyped a
> vertical column at the same time. This file covers only the sprawl.

The user, after round 3: "This is pretty good." This round is about
"I need to get over there": from where you stand you see the next region,
drawn far off and cheap. One side of the region is the exit side: "one
side of the region has a series of crossings that take you to the next
section."

## Run it

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=6
```

Without `--shape=sprawl` you get round 3's layout, unchanged. Its plans
are the same as before (test_run_layer passes).

Good seeds:

| Seed | Exit side | What you get |
|---|---|---|
| 6 | north | The cleanest line: base, then a gulf, then a neighbourhood, then the chain, then the next region, all heading north. The next region's landmark is 816 m off, the nearest of these seeds. Its spawn faces straight up the trail. |
| 15 | west | A serpent gulf (112 m), then a 5-crossing chain (stones, bridge, bridge, cannon, voussoirs). This is the test's seed. |
| 2 | south | A ferry gulf (199 m), then a 4-crossing chain. The next region's landmark is the colonnade. |
| 12 | west | The landmark is 876 m off. |

N, Shift+N, Backspace, the gate and the void all work as in round 3. The
shape carries over from layer to layer. Round 3's knobs still work
(`--knob=hoods=3` makes a longer sprawl). The card gains a line like:
`Exit side: north (stones, cannon, bridge, voussoirs, then the gate) ·
next region (layer 7) 816 m off, 90 m up`.

## What was built

- **`scripts/roguelike/layer_sprawl.gd`** (new) holds the shape.
  - **The lean.** Each seed rolls a heading. LayerPlan scores every isle
    and gulf placement higher the further it stands that way (1.5 points
    per 100 m, against a random 0-2), so the neighbourhoods march off to
    one side. The **exit side** is the direction from the base's middle
    to the last neighbourhood's middle.
  - **The exit chain** (`plan.chain`, edges of branch `exit`). It leaves a
    free rim of the last neighbourhood that faces the exit side and climbs
    on toward it. It has 4-5 crossings of existing pieces: a run of
    stones, a rope bridge, the Loose Voussoirs and a cannon, plus a fifth
    stones or bridge now and then, in a rolled order. The cannon is never
    first. Between crossings are floating slabs:
    - Waystones are 4.3 m (1.5 landing sizes).
    - The cannon's deck and its catch are 7.2 m. The cannon stands on the
      deck's middle with its kegs beside it, and its shot lands on the
      catch's middle 23-29 m on.
    - The threshold is 7.2 m and holds the gate.

    The way turns 10-24 degrees at each slab, alternating sides, so the
    chain zig-zags. Pieces are sized from the pilot as in round 2 (stone
    gaps 72-84% of his jump, footbridge grade, trap slabs, `_aim` for the
    cannon). Each one is checked clear of every isle, edge, ride tube,
    pier and cannon, and must move on toward the exit side. A draw that
    can't fit a chain is drawn again. The gate stands past every isle's
    middle on the exit side (tested).
  - **The next region** (`plan.next`). The next seed's plan is made in
    full and kept (`core`, a small cache). It is turned so its own exit
    side runs the same way, so the trail continues. Its base stands about
    180 m past the gate (pushed further until it keeps 120 m off this
    layer), with its base's turf 90 m over the gate.
    - If the line from the spawn's eye to the landmark (its highest
      isle's top) is blocked by this layer's isles, the planner first
      tries the base's clear spots within 70 m. If none sees the
      landmark, it raises the region 20 m at a time, up to 300 m.
    - The spawn moves to the first spot that sees the landmark and faces
      it, so **the first frame looks at the next region**.
    - Going through the gate takes the kept plan, so you arrive in the
      region you saw (tested).
  - `overview(plan)` draws the layout as text (below). `card(plan)` gives
    the card line.
- **`scripts/roguelike/next_region_lod.gd`** + **`shaders/next_region_lod.gdshader`**
  (new) draw the silhouette (next section).
- **`tools/layer_sprawl_map.gd`** prints the plan, card, LOD cost and maps
  for any seeds, headless:
  `godot --headless --path . --script tools/layer_sprawl_map.gd -- --seeds=6,15 [--no-maps]`.
- **Small edits** to the shared files:
  - `layer_plan.gd`: `_lean()` plus one score term each in `_step` and
    `_gulf`. With no `lean` knob the term is 0.
  - `studies/run_layer.gd`: `--shape=`, a one-line dispatch in
    `_plan_for`, `LayerSprawl.dress` after the stage, and the card line.
    The stage builds the chain's stones, bridges, trap and gate from
    `plan.edges` and `plan.exit` as it always did. `dress` adds only the
    chain cannon and the silhouette.

## The LOD: approach and cost

The silhouette is built from the **occupancy grids** only (the bake's
lowest and highest solid per 2 m cell, the rolled ring's from its plan).
No next-layer isle is built.

**How the hull is made.** Each isle becomes a closed hull over its cells'
middles (a dual grid):

- The top sits at each cell's highest solid and the keel at its lowest.
- Faces are made where 4 (or 3) neighbouring cells stand, and the outline
  is walled from top to keel.
- Normals are smoothed. A lone tall cell (a spire, a pier) tapers to a
  point instead of standing as a block, so it reads as a soft silhouette,
  not voxels.
- The landmark keeps its 2 m cells. Other isles are merged to 4 m.

**The material.** It is one mesh, one surface and one ShaderMaterial,
with no collision and no shadow casting. The shader:

- colours turf on what faces up, stone down the flanks and earth on the
  keel, lit by the scene's sun;
- mixes toward the sky's own colour (`zs_sky_down/up/glow`, the dome's
  gradient) with distance: `1-exp(-(d/1100)^2)`, up to 80%;
- adds up to 45% more haze down the keels;
- keeps the landmark 35% clearer.

Knobs are `MERGE`, `HAZE_*`, `KEEL_MIST` and `LANDMARK_CLEAR` in
next_region_lod.gd, and `DIST`, `RISE`, `APART`, `SPOT_NEAR` and the
chain constants in layer_sprawl.gd.

**Cost** (headless, seeds 1-15):

| What | Amount |
|---|---|
| Triangles | 9.3k-15.8k |
| Vertices | 4.7k-8k |
| Surfaces (draw calls) | 1 |
| Build time on the main thread | 11-21 ms |
| Test budget | 40k triangles, 1 surface, 80 ms |

From the spawn the landmark is 816-1250 m off and 33-45% hazed (the
budget is 60% at most).

## Build times (headless, this Mac)

| What | Time |
|---|---|
| Planning a sprawl layer (round 3's plan + the chain) | 0.7-7 s, about like round 3 |
| The first layer (it also plans the next seed) | 1.4-11 s (seed 6 the worst) |
| Each later layer through the gate (the next plan is kept) | one plan |
| Windowed | on the worker, as in round 3 |
| Standing the isles (flushed) | seed 15 11.5 s, seed 2 7.3 s |
| tests/test_layer_sprawl.gd | about 66 s |

## Checks

- **tests/test_layer_sprawl.gd** (`## suite: slow`, extends
  test_run_layer.gd to reuse its moves) **passes**.
  - Plan checks:
    - seed 15 planned twice from nothing gives the same plan, chain, gate
      and next region;
    - on seeds 15, 2, 1, 3 and 4: the last neighbourhood is on the exit
      side, the chain has 4-5 crossings including all four kinds, it
      leaves a last-neighbourhood rim, every crossing goes on and the
      chain climbs, the gate is on the threshold past every isle;
    - the chain cannon is aimed at its catch, and every crossing is
      within reach;
    - the next region stands past the gate and 50 m+ higher, its sight
      line is clear, the spawn faces it, the LOD is within budget and not
      over-hazed, and the landmark is the region's highest point.
  - Driven through the study's `tick` on seeds 15 (serpent) and 2
    (ferry):
    - a physics ray from the real start reaches the landmark through the
      built layer;
    - rims and corridors check out, and every route, greed and chain
      crossing is made on foot, with both voussoirs falling;
    - the chain cannon lands him on its catch (0.1-0.2 m off) and the
      greed cannon on the greed isle;
    - the gulf is ridden over on the serpent or the ferry (round 3's
      ride moves);
    - through the gate the next layer is the seen region (same seed, same
      isles where they were drawn) with a next region of its own; the
      void works too.
  - `SPRAWL_SEEDS=6,12` picks the driven seeds.
- **tests/test_run_layer.gd** (the default shape) **passes**, ~110 s.
- **test_world_scale_guard** passes. The import is clean. The full suite
  was not run.

## The shape from above and the side (seed 6, `tools/layer_sprawl_map.gd`)

Digits are isle indices (0 is the base). `.` marks route edges, `~` the
gulf, `:` the exit chain, `G` the gate, `S` the spawn, `#` the next
region, `@` its landmark and `'` the sight line.

```
From above (north up, a character 14 m across and 28 m down; 345 x 1214 m):
|                                               #####                                                          |
|                                               #####                                                          |
|                                              ##########                                                      |
|                                              ###########                                                     |
|                                               #########                                                      |
|                                               #####                                                          |
|                                                ##                                                            |
|                                                                                                              |
|                                                                                                              |
|                                              #                                                               |
|                                            #####                                                             |
|                                            #########                                                         |
|                                            #########                                                         |
|                                            #####@###                                                         |
|                                            #########                                                         |
|                                             ######                                                           |
|                                          #########                                                           |
|                                          ##########                                                          |
|                                               #####                                                          |
|                                               ########                                                       |
|                                               #######                                                        |
|                                               ########                                                       |
|                                               ########                                                       |
|                                                 '                                                            |
|                                                 '                                                            |
|                                                 '                                                            |
|                                                 ''                                                           |
|                                                  '                                                           |
|                                                  '                                                           |
|                                             G 5555555                                                        |
|                                            ::55555555                                                        |
|                                          44: 55555555                                                        |
|                                          44:455.5555533333                                                   |
|                                          44444...33~3333333                                                  |
|                                              444333~3333333                                                  |
|                                                  ' ~     3                                                   |
|                                                  ' ~                                                         |
|                                                  ' ~                                                         |
|                                               0000 ~                                                         |
|                                               00001~1111                                                     |
|                                              00000.11222222222222                                            |
|                                           0000000S.1....2222222222                                           |
|                                           000000000  2222222222222                                           |
|                                                                                                              |
From the side along the exit side (north to the right, up is up; a character 11 m across and 9 m up):
|                                                                         ''#@                       ###       |
|                                                                    ' '''######                  ## ###       |
|                                                       # ##   #####'   #########               #########      |
|                                                   #################  ##########               ##########     |
|                                                   ##############################             #############   |
|                                                   ##########   ### ##############           ################ |
|                                               '''' #########    ###################         ##############   |
|                                          ''' '      #######           ##       ##                #####   ##  |
|                                      ' ''              ###                      #                 ###        |
|                                  ''''                                                                        |
|                         44  ''' '                                                                            |
|      11               444444                                                                                 |
|      111            '444444455                                                                               |
|    111111      ''''  444444455555                                                                            |
| 0001211111 '' '      4.4..::::::G55                                                                          |
|000022211~~~~~~~~~~~~~~~435555555555                                                                          |
|0000S..211110        34443555555555                                                                           |
|0002.2221111         3344335555555                                                                            |
|   22222211            3333  5555                                                                             |
|  22222221                                                                                                    |
|    22221                                                                                                     |
|                                                                                                              |
```

## Unverified (headless can't see it)

- **The whole look.**
  - Whether a hull at 800-1250 m reads as "isles over there" or as lumps.
  - Whether the haze (my own curve, not the scene's air) matches the sky
    by day, at golden hour and at night. It mixes toward
    `zs_sky_down/up/glow`, which should track the sky, but this was never
    seen.
  - Whether the landmark stands out enough.
  - Whether clouds drift in front of it: the clouds keep off only the
    current layer's band, so they may cross the far region.
- **The shader never compiled.** The dummy renderer doesn't compile
  shaders. It is small and plain (global uniforms, varyings,
  ALBEDO/EMISSION). If it errors windowed, the region will be missing or
  pink. The fix lives in that one file.
- **The chain's look and feel:**
  - the zig-zag slabs and the cannon on a floating deck;
  - the gate's beam against the far region;
  - ranging the cannon with kegs on a 7 m deck. Kegs stand 2 m off the
    cannon, and walking near picks them up.
- **The spawn moved off round 3's spot** (to a base clear spot that sees
  the landmark). The first crossing may now be behind you or to the side.
- **The windowed timing.** The first layer plans two seeds on the worker,
  up to ~11 s while the aqueduct isle builds.

## Weak spots, honestly

- The chain is short (40-60 m) next to a 500 m layer. It reads as an
  "exit ramp", not a long gauntlet. More links (`LINKS`) and longer
  stone runs (`STONES`) are cheap to try.
- The next region is far (816-1250 m to the landmark). Its nearest reach
  is often 350-800 m off, because its base must stand 180 m+ past a gate
  that is itself 300-500 m from the spawn. Shrinking `DIST`/`APART` or
  using a nearer landmark would bring it closer.
- The landmark is just the tallest isle (usually the bell spires or the
  stair). There is no special beacon on it.
- Only 2 neighbourhoods on most seeds, as in round 3.
- The sight line is checked against occupancy and the test's physics ray.
  The camera sits behind and above the pilot, so it may see a little
  differently.
- A plan cache (`LayerSprawl._kept`, 4 plans) is cleared when the study
  leaves the tree. Without that, the engine aborted on exit.

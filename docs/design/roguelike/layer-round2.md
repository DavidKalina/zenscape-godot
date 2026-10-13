# The generated layer, round 2 (2026-10-12)

> Branch `worktree-agent-a5626d3c99bd1100f`, cut from `roguelike` at
> cb8eadb0. The first generated layer, played on foot: the aqueduct isle's
> look and sky, its layout drawn from a seed. Round 1 is
> motif-families.md (the template contract this builds on).

## Run it

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --seed=12
```

Without `--seed=` a seed is drawn. The aqueduct isle's own flags still work
(`--look=`, `--no-sky-clouds`, ...). The hall chain, the lodestone and the
dragon's roost are left out.

| Key | Does |
|---|---|
| N / Shift+N | the next / previous seed's layer |
| Backspace | this layer again (same seed) |
| everything else | the aqueduct isle's: walk, jump, sail, telescope, R back to the start |

Through the exit gate (glowing posts and a beam of light on the highest isle),
or down into the void under every isle, the next seed's layer comes up and you
start again at its spawn. A fall that lands on a lower isle is just a fall:
climb back. The card top left shows the seed, the runes taken (of 5), how long
the layer took to stand, and its isles.

## What a layer is

`scripts/roguelike/layer_plan.gd` `make(seed)`: plain data, the same plan for
the same seed (tested), about 0.2-1.5 s headless (mean 0.64 s over 30 seeds; a
seed that can't be laid in 60 draws moves on to the next seed, none of the 30
did).

- **The base**: the aqueduct isle, fixed. You start on it, a few metres back
  along the run-up of the rim where the route leaves.
- **The picks**: 3 or 4 motifs from a pool, by weight, none twice: the
  colonnade spine (3, a family: its seed and knobs rolled), the Sundered gorge
  (3), the stair to the clouds (1.5), the broken ring (1, a family) and the
  bell spires (1). Over 30 seeds: stair 26, colonnade 23, bell spires 23,
  gorge 20, ring 9 (the weights lose to what fits: see Weak spots).
- **The route**: base -> 2 or 3 isles, the last standing highest; its exit
  gate on that isle's highest free rim.
- **The greed branch**: off a route isle onto one more isle (never the hero,
  the colonnade), five runes in a ring over its roomiest perch.
- **Edges**, rim to rim, tens of metres (8-30 m): every one sized from the
  pilot's own numbers (`KitMotif.pilot()`, the motor at WorldScale's size):
  - stones: 4-9 floating stones (the aqueduct art's `floating_stones`), each
    gap 0.72-0.84 of his running small jump's reach at that stride's rise
    (`reach`), over the least that clears the next stone's face (`clears`),
    each stone long enough that his *pump* (the chained second jump, which a
    runner across stones gets) still lands on the next (`pump_reach`);
  - a rope bridge (Footbridge `live`, on the broken ring's stone anchors),
    2.6-5.4 of his hops, at most half the footbridge's grade, often after a
    run of stones to a landing slab;
  - the Loose Voussoirs (scripts/traps/trap_voussoirs.gd, its own knobs, 6-9
    slabs), level, lip to lip, usually after stones to a landing; one on every
    route; its `under` is "layer" when an isle is under it, else "void";
  - the greed branch: 3-6 harder stones (gaps 0.86-0.93 of his reach).
- **The cannon** (scripts/cannon/), on 30 of 30 seeds: behind the greed
  branch's rim, aimed at the greed isle, three kegs by it. The plan finds a
  power notch and pitch whose shot lands 2.5-6.5 m past the far rim, its arc
  clear of every isle; the cannon rests at its own default aim, so you range
  it with kegs. It is the cannon's own, its launch speed knob raised from 5.4
  to 6.6 of the pilot's run (`LayerPlan.CANNON_RUNS`) so a shot carries a
  greed gap of 20-28 m.
- **The Plinth Ram** on the roomiest arena (4.5 m+) of a route isle, 8 m from
  any rim used, when one has room (30 of 30 seeds).
- **Placement**: an isle is only moved, never turned. The next isle stands
  where its in-rim lands at the end of the edge; its occupancy (per 2 m cell,
  its lowest and highest solid) must keep 4 m from every other isle's, the
  edge's corridor (the pilot's body over it, the stones under it) clear of
  every isle and edge, and the isle clear of the edges laid before it.
  Candidates are scored on climb, standing over a lower isle (a soft fall),
  and staying near the base (within 240 m).

## What was built

- `scripts/roguelike/isle_probe.gd`: reads a built isle through physics:
  walked ground, rims (lip where the ground falls 0.2 m, clear air 10 m under
  to 4 m over out 8 m, run-up), clear spots, occupancy.
- `tools/bake_layer_pieces.gd` -> `data/layer/pieces.json`: the probe over the
  Sundered gorge, the stair to the clouds, the bell spires (rims, spots,
  occupancy), the colonnade (occupancy) and the aqueduct isle's near island
  (rims, spots, occupancy). About 20 s headless. Re-run it when an isle's art
  changes:
  `godot --headless --path . --script tools/bake_layer_pieces.gd -- --no-sky --no-life --no-flora --no-lode --no-chain --no-dragon-roost`
- `scripts/roguelike/layer_pieces.gd`: loads the bake. `kit_motif.gd`: a motif
  that isn't a family answers `sockets`, `footprint`, `height_span` from it
  (rims, perches, arenas; no cover). The gorge, stair and spires got a
  `build_cost`. A rim may answer `lip` (how far ahead its ground ends); the
  colonnade's rims now do (its flanks are slopes, the lip 1.6-2 m out, not
  the step its `at` stands in from).
- `scripts/roguelike/layer_plan.gd`: the generator. `layer_stage.gd`: builds a
  plan's stones, bridges, trap, ram, cannon, runes and gate, and stands in the
  study's `foot_pieces` slot round the aqueduct isle's own foot pieces.
- `scripts/kit_isle/motif_sky.gd` `setup_layer`: the motif sky with a
  generated list of isles in place of PLACES (the aqueduct scene unchanged).
- `studies/run_layer.gd/.tscn` (extends the aqueduct isle) and
  `studies/run_layer_sky.gd` (the aqueduct sky: clouds, open-air life, motes,
  isle tokens; no airships, ferry, CPU biplanes or serpent, which loop round
  the authored places). A new layer frees the old isles and stage, makes the
  sky's isles and its gull life again.
- The family gallery's fast paging: presses while an isle builds are queued
  and each page is built and shown in turn; `character_study.gd` stops its
  `_ready` if the scene left the tree during its physics-frame waits (the
  `:485` error).
- `kit_audio_life.gd`: a freed waterfall no longer errors (an old layer's).

## Checks

- `tests/test_run_layer.gd` (`## suite: slow`, about 60 s headless), seeds 3,
  4, 9, 12: same plan twice; a trap on every route; every edge within reach;
  every rim used stands on its ground with the ground gone 4 m out (past
  what the layer lays off it); every edge's corridor clear of everything but
  its own pieces; **every route edge and the greed branch crossed through the
  study's own `tick`** (the real motor stepping, the stage's traps stepped
  round it; jumping at the lip and each stone's far edge, holding the jump
  rising), the voussoirs falling behind him; the cannon at its found aim
  landing him within 0.3 m of its mark; the gate and the void each starting
  the next layer at its spawn. Also passed on seeds 1, 2, 5, 6, 7, 8, 10, 11
  (`RL_SEEDS=1,2,5 ...` runs others; `RL_TRACE=<seed>` prints a seed's
  crossings frame by frame).
- Ran: the import, test_run_layer, test_motif_families (passes),
  test_broken_ring_isle (passes), test_motif_sky: fails on `dragon_roost
  stands whole: art, grass and life`, the same on the untouched `roguelike`
  base (checked), so not this round's.

## How long a layer takes

Headless (this Mac, other agents' tests running): the scene to walking about
11-14 s (the aqueduct isle's own build); planning 0.2-1.5 s; the motif isles
built and stood whole on the main thread 8-11 s for three isles. Rendered (not
measured: no windows this round), the isles are built on a worker one at a
time, nearest first (the motifs' measured builds: gorge 1.9 s, stair 2.5 s,
colonnade 3.2-3.4 s, ring 1.3 s, spires 1.2 s), then stood a slice a frame, so
the first isle should stand 2-4 s after N and the layer 6-10 s; the pilot is
on the base at once. Watch for an edge reached before its far isle stands
(stones into empty air): the first isle is the nearest and builds first.

## Unverified (headless can't see it)

- The whole look: how a layer reads from the base, the isles' heights and
  spacing, whether the edges read as paths, the stones' and landings' look,
  the gate and its beam, the runes' glints, the card. Never seen windowed.
- The worker builds windowed: the timings above, hitches on N, the sky's
  gulls and clouds round a new layer, the old isles' sound fading.
- Playing it by hand: the bot jumps at exact edges; a player's timing, the
  camera on the stone runs, the cannon's camera aimed at a far isle, the
  ram's room on an arena next to the route.
- The plane: it is the aqueduct isle's, parked near the isle's old start and
  broken (the plane arc); fixed and flown it skips the layer. Out of scope.

## Weak spots, honestly

- **Few isles stand over others.** Only about 1 isle in 6 has any of itself
  over a lower isle (most of the soft falls are under the edges: the trap is
  "over the layer" on most seeds). The isles are big (keels 30-45 m deep) and
  the edges climb 1-4 m, so stacking needs the climb the stair and colonnade
  give inside themselves. A vertical edge (a stair of stones spiralling up, a
  cannon up) would let isles stack.
- **Rims face fixed ways** (no turning), so which isle follows which is
  limited by facing pairs; a seed retries up to 60 draws (the 4-isle layers
  fail more: 11 of 30 seeds got 4 picks).
- The greed isle is often entered high (the stair at its summit, then down).
- The pool weights are not what you get: the gorge (weight 3) lands on 20 of
  30, the ring (1) on 9.
- The bake reads the aqueduct isle's near island only; rims on the far island
  and islets are not used.
- No cover sockets on the baked motifs; the colonnade's tail rim is used only
  when both its bridges hold.
- The layer's sky tokens are the aqueduct isle's only (the motif isles' plane
  tokens are left out: they come and go).

## For round 3

- **"How the hell do I get there?"**: the plan has the hooks. An edge is a
  list of parts (`_shape`: stones, landing, bridge, trap); new parts slot in
  there with their own reach rule: a speed run-up over a long jump (the long
  jump: `LONG_SPEED`, `LONG_HEIGHT` in the motor), a launch off a slide, a
  wall-kick chimney, a cannon up to a visible prize over the route. The
  cannon here is one per layer on the greed branch; the solver (`_cannon_at`)
  works for any two points, so a "cannon-only" isle is a few lines. Prizes on
  perches that are *visible from the route* would want a sight check
  (`IsleProbe` rays) in the scoring.
- **The dragon** is next: the layer knows its isles, their rims and spots,
  its void height and its band (`LayerPlan.BAND` round `MIDDLE`); the roost
  could stand outside the band and his circuit run round it. Cover sockets
  exist on the families only (the bake has none).
- Re-bake (`tools/bake_layer_pieces.gd`) whenever a pool isle's art changes;
  the test catches stale rims (rim_ok) and corridors.
- More motifs into the pool: run the bake over them (add to its `MOTIFS`),
  add a POOL line; families answer their own sockets and may give `lip`.

# The generated layer, round 7: the ring, and a run that alternates (2026-10-13)

> Branch `worktree-agent-a7526f05df339f000`, cut from `roguelike` at
> 1dc0cacc. The sprawl is layer-round4-sprawl.md (4B-2) and
> layer-round5-roost.md; the run is stakes-experiment.md.

The user: "I also really like the ringed motif that we have in the
aqueduct isle [...] I wonder if we can do this cool stacked thing where you
have what we have now, maybe another that's a more horizontal one, and then
you can alternate between the two." And: the dragon's grip "works really
well in the original where it's like the ring of islands."

## Run it

```sh
# A ring on its own (its gate leads on to a sprawl, then a ring, ...):
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=ring --seed=4
# The alternating run from a sprawl: depth 1 sprawl, 2 ring, 3 sprawl, ...
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=3
```

Good seeds (ring):

| Seed | What you get |
|---|---|
| 4 | 4 isles 307 m out. Serpent loop 2.0 km past 4 piers; the ferry (380 m) from the stair to the gate on the colonnade spine; a cannon from the base out to the gorge (210 m). Plans in 0.4 s. Checked through the play loop (below). |
| 7 | 6 isles 297 m out, a pier on every one but the gate's (2.4 km loop); the ferry to the gate on the Sundered gorge. 0.75 s. |
| 6 | 5 isles 318 m out, rising 3-35 m; first draw, 0.3 s. |
| 9 | 5 isles; a cannon too. 0.8 s. |
| 12 | 4 isles; what sprawl 11's gate leads to (checked). |

For the alternating run: `--shape=sprawl --seed=3` (its gate stands up ring
4) or `--seed=11` (ring 12). `--shape=ring --seed=4` goes ring 4, sprawl 5,
ring 6, ...

Knobs (`--knob=key=value`, kept through the run):

| Knob | Does |
|---|---|
| `alternate=0` | keeps the one shape (`--shape=ring` rings all the way, `--shape=sprawl` as before) |
| `ring=<3-7>` | pins how many isles stand in the ring (rolled 4-6) |
| round 3's (`gulf`, `hoods`, `ride`, `rise`) | the sprawl's, as before; `ride`/`gulf` don't touch the ring |

Constants in `scripts/roguelike/layer_ring.gd`: `COUNT`, `RADIUS`
(275-325 m), `RADIUS_JITTER`, `BEARING_JITTER`, `RING_GAP` (110 m open sky
between ring isles), `BASE_GAP` (120 m), `LOW_RISE`/`GATE_RISE`/`GATE_OVER`
(the rise round the ring), `HELD`/`NEAR_PACE`/`BASE_LEAD`/`RING_LEAD`/
`BULGES` (the serpent's loop), `LINK_TURN`, `CANNONS_MOST`, `CANNON_GAP`.

## What a ring region is

`LayerRing.make(seed, knobs)` (`scripts/roguelike/layer_ring.gd`, new):

- **The ring.** The aqueduct isle at the middle (the arrival, as in the
  sprawl). 4-6 motif isles from the pool (families rolled, a non-family
  motif at most twice) stand round it, each one's middle 275-325 m out
  (the aqueduct scene's stand 345-480 m out), evenly spaced give or take
  9 degrees, 110 m+ of open sky between neighbours and 120 m+ from the
  base, solid to solid. Moved only, never turned, as every layer isle.
- **The rise.** Each isle's foot (its lowest rim with a run-up) is set by
  how far round it stands: the low isle 3-9 m over the aqueduct isle's
  turf, rising round both ways to the **gate isle** across the ring,
  22-36 m up (+4). A horizontal shape: 25-35 m from low to gate, against the
  sprawl's 50-80 m.
- **The gate** on the gate isle's rim that faces out (furthest out, high).
  `plan.heading` is the way out from the middle through it; the next region
  stands beyond it (the sprawl's `_spawn_view` and `_place_next`).
- **The ring serpent** (`_ring_serpent`, `_ring_loop`): one rune serpent on
  its own closed loop, the aqueduct scene's idea. It runs from a pier on the
  aqueduct isle out through the gap in the ring the pier faces, round the
  ring past a pier on every ring isle but the gate isle (passing the gate
  isle's side with no pier), and home through the same gap. By each pier it
  runs straight and level, slither held, three quarters pace (LayerPlan's
  gulf-loop grammar), now 5 control points long where the coast allows
  (`HELD`): its middle, where a rider sits, passes the pier with its head
  still held, so it is at the pier's pace (with 3 points, as the gulf
  loops, the bot overshot the ring piers at 12-13 m/s). Between piers it
  leads out over open sky off each rim, then follows the arc round the
  middle (straight for the two legs to and from the base). Loops are 1.4-2.4
  km: about 2.5-3.5 min a lap. Rims are pre-checked for a pier
  (`_pier_ok`: the run and its corners clear of the coast); only 5 of the
  aqueduct isle's 14 rims take one. A loop that meets an isle moves that
  isle's pier to its next rim, or drops it; meeting the base, it tries the
  next base rim.
- **Links** (`_links`): every ring isle the loop doesn't pass (always the
  gate isle, sometimes one more) gets a gulf from a ring neighbour on its
  own honest ride (LayerPlan's `_ferry_loop`, the ferry first, else a gulf
  serpent), kept off the other rides' tubes where it can be, its rims
  allowed to turn up to 65 degrees off the line if none does within 50;
  from the base only if no neighbour works (seeds 3, 5, 13, 15: then the
  ferry runs from the start straight to the gate isle).
- **Cannons** (`_cannons`): "cannon" gulfs (no ride, only a cannon; LayerPlan
  `_gulf_cannon` at up to 16 runs) from the base out to a ring isle or
  between ring neighbours, where a shot carries; at most 2, the narrowest
  first. The ring is wide, so about 1 seed in 3 gets one.
- **Greed branch, ram:** round 3's (hard stones off a ring isle but the
  gate's, the rune set, its cannon; the Plinth Ram), the stones kept off
  every ride's tube.
- **The dragon's roost** apart beyond the ring (LayerSprawl `_roost`
  unchanged: 150 m+ clear, over every isle, in sight, off the exit side):
  480-680 m from the start.
- **Reachable:** every ring isle by the serpent or a link (else the draw is
  laid again); the serpent's base pier is by the spawn. Spawn: back along
  that pier's rim's run-up, then moved by `_spawn_view` to see the next
  region.
- **The dragon's grip, a flag for later** (`isle.grip`, `_grip`): the room
  rule of docs/design/dragon-grip/round1.md read off the occupancy (not the
  built shape): a rim 35 m+ (ROOM x size/0.85) from the isle's middle whose
  chin band (3-16 m in, x1.76) is 75%+ solid near the rim's height with at
  most 2 samples 2 m+ over it. `{room, rim, out, open, tall}`. The card
  lists the ring isles with room. Over seeds 1-16 (80 ring isles) only the
  Sundered gorge has room (17 of 17; rim `r13_s`, 53 m out, all open); the
  colonnade spine (32; its best rim 21 m out), the stair (18), the bell
  spires (8) and the broken ring (5) never do. So a ring has 0-2 grippable
  isles. Unverified against the real `_best_turn` on built isles.

Plans (headless, this Mac, shared): seeds 1-16 all lay, 0.3-8.5 s each
(mean about 3 s, 0-26 redraws; the serpent's loop is what redraws). The
gate's next region (a sprawl) takes one sprawl plan more (2-6 s), laid on
a worker after the layer stands, windowed, as the sprawl's own.

## Alternation (`scripts/roguelike/layer_shapes.gd`, new)

- `LayerShapes.make/core(shape, seed, knobs)` dispatch to round 3's,
  the sprawl's or the ring's. `after(plan)` is the shape past its gate:
  the other of `RUN = ["sprawl","ring"]`, or the same with
  `--knob=alternate=0`.
- **The next region is laid in its own shape:** `LayerSprawl.next_plan`
  now asks `after(plan)` and lays that shape's plan (each shape keeps its
  own small cache), so the far silhouette past a sprawl's gate is a ring
  (the aqueduct isle in its middle, its isles round it, its roost) and past
  a ring's gate a sprawl. Going through the gate takes the kept plan, so
  you arrive in the region you saw.
- **The study** asks the next layer in a shape: the gate (run_loop) asks
  `after(layer)`, N asks `after(layer)`, Backspace the layer's own shape,
  a new climb (death card) `--shape=`'s. Depth 1 is always `--shape=`'s.

## Shared files touched (small edits)

- `scripts/roguelike/layer_sprawl.gd`: **only `next_plan`** (3 lines: the
  next plan in `LayerShapes.after`'s shape, via `load`, so no preload
  cycle). Nothing else in it changed; the ring calls its `_spawn_view`,
  `_roost`, `attach_next`, `_place_next`, `dress`, `sight_clear`,
  `compass`, `overview` as they are.
- `studies/run_layer.gd`: preload `LayerShapes`; `_plan_for`/`_plan_job`/
  `request_layer` take a `shape` (`shape_asked`); `_plan_for` dispatches
  through `LayerShapes.make`; the run loop starts for `--shape=ring` too;
  `LayerShapes.dress` replaces `if layer.has("chain"): LayerSprawl.dress`;
  `LayerShapes.card` replaces the sprawl card line; N / Backspace pass a
  shape.
- `scripts/roguelike/run_loop.gd`: preload `LayerShapes`; the gate's
  `request_layer` passes `LayerShapes.after(study.layer)`.
- `scripts/roguelike/layer_rides.gd`: a gulf's isles to wait on are
  `edge.stops` if it has them (the ring serpent opens when every isle it
  passes stands, and builds each pier as its isle stands: `auto_build`);
  a `"cannon"` gulf makes no ride; the card's schedule reads every pier of
  a many-pier serpent; piers already built aren't built again.
- `scripts/roguelike/layer_plan.gd`: two knobs in `KNOBS` (`alternate`,
  `ring`). No plan changes (the knobs feed no roll).
- New: `scripts/roguelike/layer_ring.gd`, `scripts/roguelike/
  layer_shapes.gd`, `tools/layer_ring_map.gd` (plans, cards, grip flags,
  silhouette cost and text maps headless:
  `godot --headless --path . --script tools/layer_ring_map.gd -- --seeds=4,7 [--no-maps] [--trace] [--knob=...]`).

## Checks (prototype round: no committed tests)

- Headless import clean.
- `run_layer.tscn` 300-400 frames headless with no script errors:
  `--shape=ring` seeds 2, 4, 7 (and 4 with `--plan-away`, the worker
  path), `--shape=sprawl` seeds 6 and 11, round 3's shape seed 15.
- A throwaway play-loop check (`tools/_ring_check.gd`, extends
  tests/test_run_layer.gd for its moves; left uncommitted in the
  worktree), passing from sprawl 11 and from sprawl 3:
  - the run begins on a sprawl, its next region drawn;
  - placed at the sprawl's gate, the next layer is a ring, the very region
    seen (same seed and isles), a layer deeper, with a sprawl as its own
    next region;
  - flushed: the ring serpent's isles stand, a pier on every one it passes;
  - walked up the base pier's steps, a running jump onto the serpent as its
    middle passes, carried 33-36 s round to the first ring pier, a jump off
    onto it, down its steps onto the isle;
  - (from sprawl 3, ring 4) the ferry walked aboard, carried 90 s over the
    380 m gulf to the gate isle, walked off; the base's cannon lands him on
    the gorge 2.3 m off its mark;
  - placed at the ring's gate: a sprawl, depth 3.
- `--knob=alternate=0` on ring 4: its next region is ring 5.

**Existing tests this may break (not run):**

- `tests/test_layer_sprawl.gd`: a sprawl's next region is now a ring by
  default. Its checks on the next region (stands past the gate and 50 m+
  higher, landmark the region's highest, ray to the landmark, "laid later
  is the one laid at once", through the gate the seen region) should still
  hold for a ring but were tuned on sprawl regions and weren't run. Setting
  `--knob=alternate=0` in the test (its `LayerSprawl.make(s, {"alternate":0})`
  and `layer_knobs`) would restore the old behaviour exactly.
- `tests/test_run_layer.gd` (round 3's shape): untouched paths; KNOBS gained
  two keys (plan.knobs shows them). Expected to pass; not run.

## Unverified (headless can't see it)

- **The whole look:** whether 4-6 isles 300 m out read as the aqueduct
  scene's ring "across the middle", whether the rise (25-35 m) reads as
  horizontal, the serpent's 2 km loop sweeping round, its lead-outs at
  each pier, and the ferry's long gate crossing (up to 380 m, 90 s).
- **The next region's ring silhouette** 1-1.5 km off: a ring of lumps round
  a big one may read oddly; and the sprawl silhouette past a ring's gate.
- **The arrival:** a ring region's spawn on the aqueduct isle faces between
  the serpent's base pier and the gate isle (StartSpot), not necessarily at
  the next region; whether the start reads.
- **Windowed timing:** a ring's 5-7 isles build nearest first; the base
  pier stands at once and each ring pier as its isle stands, but the
  card's schedule says "still rising" until all have (the ride can be
  boarded before). The gate's next region comes a few seconds after.
- **Riding by hand:** the bot boards and gets off at exact moments; the
  piers' pace is the gulf loops' at the 5-point runs, the gulf loops'
  faster at the 3-point fallbacks.
- **Rides crossing:** the ferry's or a link serpent's tube is kept off the
  ring serpent's where it can be, else laid anyway; they may pass through
  each other in the sky.

## Weak spots, honestly

- In 4 of 16 seeds the gate is linked from the base, so the start's ferry
  goes straight to the gate isle (the ring is then optional).
- Cannons are rare (the gaps are 200-380 m).
- The gate isle tends to be a big motif (gorge, stair) since those take
  links; the low-to-gate rise is set by order, not by the motifs' heights,
  so a tall motif low on the ring can stand over the gate isle's foot (its
  top may still be higher: the stair's 95 m peak).
- Planning time varies with redraws (up to 8.5 s on a shared machine).
- `isle.grip` is an occupancy approximation of `_has_room`.

## For the dragon's grip in the ring (next rounds)

- The ring is the shape the grip was tuned on: isles in a ring round open
  sky, approached across the middle. `plan.ring.order` gives the isles in
  turn round it, `isle.grip.room`/`rim`/`out` the ones with room and their
  best rim (the way the grip faces: from the isle's middle out through that
  rim), the aqueduct isle at the middle never a target (its 60 m rule).
- A circuit for `DragonWake` round the ring falls out of the plan: the arc
  between the ring isles at about `plan.ring.radius`, kept off
  `plan.tubes` (the serpent's loop runs inside and outside it, the
  ferry's lanes 44 m either side of its line), landing at `plan.roost`.
- The serpent's loop passes every non-gate ring isle: its piers are
  natural "the dragon is on that isle, ride past it" moments.

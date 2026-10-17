# Air ring: handoff

A prototype with no committed tests. It builds on the slam spring
(docs/design/slam-spring/slam-spring-handoff.md).

## What it is (the reading taken)

A flat ring of worn stone blocks hangs in the air with a band of light
round its inside. Fly up through it and three things happen: the updraft's
bar (the wind gauge, 3 segments) fills to full, the updraft's air chain
starts again (so the next Q rises a full 3.2 m, as it would off the ground,
not 0.6x that), and you're popped up 2 m with the spring launch's hang at
the top. The drop under you is forgiven, so a miss doesn't stun you. The
ring goes dark in a burst: a light hoop thrown outward, motes off the rim,
the updraft's gust ring and an air swirl round you. It lights back up after
2.5 s.

Each step between rings takes two updrafts, and the bar holds three. So
when you reach a ring, the bar you came with can't do the next step, and
only that ring's refill can. This holds from ring 2 on, whatever you came
with. For ring 1 to ring 2, it holds unless you reach ring 1 with 2 or
more segments still unspent.

## Play it

```
./run-zenscape.command --no-title --foot-at=slabs --ledger=/tmp/air_ring.json
```

1. Hop onto the first slab (the nearest).
2. Build a segment if your bar is empty (side flips and long jumps fill
   it).
3. Press Q, then crouch at the top: that's the slam. The slab throws you up
   through ring 1 with no Q needed.
4. At the top of the pop, press Q, then Q again at the next top, steering
   west toward ring 2.
5. Do the same to ring 3, and the same again onto the perch, a turfed
   floating block with a standing stone, 29 m over the meadow.

The rings step west back over the near island's rim, so a miss lands on
the meadow with no stun. To get down off the perch, use the sail (Space
with room under you). Otherwise it's a stun-height drop.

## Code

- `scripts/interactables/air_ring.gd` is the reusable piece. Its tuning
  knobs are `HOLE`, `POP`, `COOL`, `CHEST` and the look constants. It has
  no collision.
- `foot_pieces.gd`: `air_ring(at, seed, yaw, tip)` places a ring, and a
  ring can be tipped. Rings advance in `before`. In `after`, a ring is taken
  when his chest crosses its plane inside `HOLE` (1.5 m); it then refills,
  pops (`motor.launch`) and adds the step event `"air_ring"`.
  `rings_taken` counts the takes.
- `updraft.gd`: `refill(at)` fills the charge, resets `_air_ups`, lifts
  the burst lock and adds a gust ring.
- `aqueduct_foot_route.gd`: `RINGS` and `PERCH_AT` hold the positions,
  built from the `RING_*` and `PERCH_*` constants.
- `character_study.gd`: the swirl on `"air_ring"`. There is no sound: the
  kit has no hook that fits.

## Numbers (size 1, measured on slab 1 with real input)

| | |
|---|---|
| no spring: jump + 3 updrafts + twirl | feet 7.1-7.3 m over the slab top (chest 8.0-8.2) |
| slab launch, 6 pumps (the other slabs) | 7.5-8.1 m |
| slab 1 launch, 7 pumps (`RING_SLAB_PUMPS`) | 9.25 m (chest 10.15) |
| ring 1 middle | 9.1 m over the slab top |
| step | 7.5 m up, 3 m out (west, slightly north) |
| from a ring: pop + 1 updraft | 1.74 m short of the next ring's plane |
| from a ring: pop + 2 updrafts | 2.15 m past it |
| perch | 4.5 m over ring 3, 3.6 m on; top at TOP + 28.9 |

**Flag:** slab 1 now throws one pump higher than the other slabs (7 against
6). At 6 pumps, a launch tops out only 0.4-1.0 m above what you can reach
without the spring, which is too thin a margin for a ring to sit between.
The alternative is ring 1 higher and reached by launch + 1 Q, which means
having 2 segments before the slam.

## Proved (headless, real input, scratch/air_ring_chain.gd)

- The full chain, done in `aqueduct_isle.tscn` and `zenscape.tscn
  --foot-at=slabs`: slam, then the launch alone through ring 1, then Q,Q to
  ring 2, Q,Q to ring 3, Q,Q onto the perch. 3 rings taken, the bar back to
  1.00 at each, no fall stun. Same result across 6 slab bob phases.
- Without the spring, ring 1 is not taken (jump, 3 updrafts and a twirl,
  full bar).
- With one updraft from ring 1, ring 2 is not taken (1.74 m short).
- With ring 2's refill undone (the counterfactual), ring 3 is not taken
  (3.71 m short).
- After each miss, he lands on the meadow with no stun.
- Smoke check: headless import, then `zenscape.tscn` and
  `aqueduct_isle.tscn` for 400 frames each, 0 errors.
  `test_foot_interactables` and `test_aqueduct_isle` pass. No known test
  breaks.
- Rendered stills, checked by eye: the stone ring with its light band
  reads, and the chain reads from the side. The first burst hoop drew as a
  thick white disc; it's now a thin hoop that only widens outward. That fix
  has no new still yet.

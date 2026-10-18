# Movement tuning: handoff

This is a prototype round with no committed tests. It sits on top of the ring
route (docs/design/ring-route/) and on side slam round 3, which is merged in:
the ground side slam now costs one segment.

## Play

```
./run-zenscape.command --no-title --foot-at=ring_route --ledger=/tmp/ring_route.json
```

## What changed

- **A side flip fills a segment** (`scripts/updraft.gd` `FLIP_GIFT`,
  `_flip_gift`). Segmented charge only. When the flip fires, the charge goes
  up to the next whole segment, capped at full: from 0 to 1, from 1.4 to 2,
  from 1 to 2, and full stays full. A small gust ring shows round his feet.
  It is only drawn and pushes no ropes (`_blast_ring` `look_r`). The updraft
  emits `gifted(segment)`, and the gauge (`scripts/wind_gauge.gd` `gift`)
  snaps that segment full and throws a bright flash out past the arc
  (`GIFT`, 0.5 s). Every other charge source is unchanged.
- **A slam plants him** (`scripts/pilot_motor.gd` `SLAM_PLANT`, `planted`).
  On the touch his flat pace is zeroed. With crouch still held he stays
  crouched where he hit, and he doesn't slide or surf, even on a slope,
  until crouch is let go and pressed again. A slab launch after a slam goes
  straight up. In the air he steers with the stick as before.
- **Ring tops are trampolines** (`scripts/interactables/air_ring.gd`
  `try_bounce`, `BOUNCE` 5 m, `FLEX_*`; `foot_pieces.gd` `_bounce_ring`).
  Coming down onto the stones bounces him back up every time, with no
  cool-down. His flat pace is kept, the charge is refilled, and the bounce
  is forgiven by the fall stun. The ring dips along its axis, rings out, and
  its stones squash. He squashes as he would on a landing (`body.land`), and
  you get a stone thump and a swirl (`character_study.gd`, "ring_bounce").
  Flying through the hole works as before. For a ring on edge, the "top" is
  the stones' upward face, which is in practice its upper rim.

## Proof (real input, headless; drivers in scratch/, git-ignored)

- `scratch/flip_gift.gd`. Segments after a flip: from 0 gives 1.000, from
  1.4 gives 2.000, from 1 gives 2.000, from 2.6 gives 3.000, and from 3
  gives 3.000. The charge is set one frame after the flip fires, and the
  gauge fills snap at once.
- `scratch/dash_slam_cost.gd` (side slam round 3): 20/20. One dash slam from
  full leaves 2 segments.
- `scratch/slam_plant.gd`: a slam with crouch held is planted, with 0 m/s
  pace and 0 m moved over 30 frames with the stick held.
- `scratch/ring_bounce.gd`: 5 bounces in a row on ring B, with a Q spent on
  each rise, and the gauge is full at every bounce. The apex is about 5.2 m.
  There is no stun. One bounce off ring A's upper rim also refills the gauge.
- `scratch/ring_route/route.gd`, both forks: 18/18 in aqueduct_isle and
  18/18 in zenscape. Lip pace is about 13.0 m/s. In 2 of 7 runs, leg 3's
  sail landed him on top of the sarsen marker standing on the perch. That
  counts as a failed check by name, but it is still the perch. The first of
  those two came before the ring change.

## Farming and shortcuts

- **Side flip.** It needs the ground and a skid, so it can't be done off a
  ring's boost. On any ground, three flips fill the gauge in about 6 s. That
  gives more Qs and earlier side slams, but nothing that skips a leg.
- **Ring bounce.** From a standstill on ring B, a bounce plus three Qs
  peaks about 13 m over the ring. Sailing from there for the far crag
  arrives about 20 m below its top (`scratch/ring_skip.gd`), so the slide's
  speed is still needed. On the ring stair, a bounce plus Qs can climb more
  than one ring per refill. That is a different way up, not a skip.

## Tests (headless)

- `test_slam`: one new failure, which is expected from the plant: "Crouch
  still held, he slides out of it". The same two updraft checks fail as on
  main.
- These pass: `test_pilot_motor`, `test_foot_interactables`,
  `test_aqueduct_isle`, `_life`, `_sail`, `_sky`, `test_sky_tepui`, and the
  wind tests that touch the updraft.
- These fail on things outside the files this round touched:
  `test_aqueduct_isle_plane` ("R3 puts the camera back") and
  `test_aqueduct_isle_look` (the plant triangle budget, plant placement).
  They weren't compared against a baseline.
- Smoke: zenscape and aqueduct_isle each ran 400 frames with 0 errors.

## Not judged by eye

The rendered capture of the bounce came out fogged by cloud at the ring's
height, so the ring's flex and his squash haven't been checked by eye.

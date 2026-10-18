# Ring course: note

> 2026-10-17, branch `course/ring-course`. The user's start (7022ddad,
> made in the world view) finished in `layouts/aqueduct_isle.json` only.
> Play: `./run-aqueduct-isle.command --foot-at=slabs` (you stand on the
> near island's east side; the course lane is 11 m south along the rim, at
> z -7.2, past the floating stone).

## The intent I read

The line runs **east, off the near island's rim, on throws rather than
climbs**. A hop up onto the lodestone's floating stone, then down onto
the big slab, which is slammed. Its spring goes up through the 45° ring,
which throws him up and east into the 75° ring. That one throws him flat
and fast east (16 m/s), and he sails down onto the raised kicker over
crag 1. There another slam springs him up through the flat ring over it,
and he sails on to the outcrop. From there the ring route runs as it was:
the outcrop's ring stair, the slide rock's perch, the slide and ring A, the
far crag, the last slab and ring, the bell spires' turf. That is the end.

The other reading was that the course stops at crag 1, with the kicker
and its ring as the finale. But the flat ring over the kicker throws
nowhere unless the outcrop follows, and the ring route was left whole
past the kicker. So I read the user's pieces as a new opening for the
route, not a separate course.

Played as saved (before my changes), it already ran end to end through
real input (19/19 checks). The changes below make it cleaner and fairer.

## What changed (their pieces)

| Piece | Was | Now | Why |
|---|---|---|---|
| added/bob_slab_1 (big slab) | (135.6, 29.2, -7.2), yaw -2.35 | (134.1, 29.2, -7.2), yaw 0 | 1.5 m west: a plain jump off the floating stone (0.8 m jump, 2.1 m drop) now lands on it. As saved, only a jump and the sail reached it. A plain jump hit its side and he climbed up. Turn squared. |
| added/air_ring_1 (45°) | (136.7, 35.7, -7.2), yaw -95.94 | (135.2, 35.7, -7.2), yaw -90 | Moved with the slab (same offset). Yaw squared, so it throws due east, not 6° off. |
| added/air_ring_2 (75°) | (140.85, 39.45, -7.05), yaw -95.94 | (139.35, 39.45, -7.2), yaw -90 | Moved with the slab, lined up on the lane (z -7.2), yaw squared. |
| ring_route/kicker_slab | yaw -78.54 | yaw -90 | Turn squared. Position and size (6.15 m) kept. |
| added/air_ring_3 (flat, over the kicker) | (186.2, 45.2, -5.4) | (188.4, 44.6, -9.15) | As saved, it hung 3.75 m to the side of the kicker's middle. The launch rose past it and took it **falling back** (-7.7 m/s), or he landed on its top and bounced. Now it sits on the kicker's centreline, 2.15 m east of the middle (the way he travels), 0.6 m lower. The launch takes it rising (+7.6 m/s) in every run. It stays clear of the sail-in onto the kicker. |

Untouched: crag 1, the islands, the tokens, balustrades and rope the user
moved, and every deletion.

## What I added

- **added/air_ring_4**: a small flat ring (radius 1.4) lying low on crag
  1's south turf, at (186.0, 32.45, -14.7), as a retry. A miss onto crag 1
  leaves him under the kicker, 5.6 m up, with no way back. A jump onto this
  ring's top bounces him 5 m and refills the bar. One Q puts him on the
  kicker, then a jump and a slam springs him.

## Sections and the moves they ask for

All measured through real input (`scratch/ring_course/course.gd`, from the
`--foot-at=slabs` spot):

0. Walk from the start down the rim to the lane (z -7.2).
1. **Rim, stone, slab, two rings.** Jump up onto the floating stone, run
   and jump off it, then slam over the big slab. You can also open the
   sail at the top of the hop and slam over the slab. The spring takes the
   45° ring, which throws you through the 75° ring. Asks for: jump, jump
   (optional sail), slam.
2. **Ring 2's throw to the kicker.** 16 m/s east, bar full. Sail toward
   crag 1 and slam over the kicker. Passes with 0 or 1 updraft (with none,
   he comes in about 1.2 m over the slab: a slam right away). Asks for:
   sail, slam, optional Q.
3. **Kicker to the outcrop.** The spring takes ring 3 if you steer 2 m on
   east while rising. Then one Q and the sail onto the outcrop (47 m).
   Asks for: steer, Q, sail.
4. **Outcrop's ring stair to the perch** (unchanged): hop off and slam the
   stair slab, then a Q per ring through four rings, a Q and the sail onto
   the slide rock's perch.
5. **The slide** (unchanged): off the perch's step, slam into the slope,
   crouch-surf, then off the lip through ring A, two Qs and the sail onto
   the far crag.
6. **Last slab and ring** (unchanged): slam it, up through the ring, a Q
   and the sail south onto the bell spires' turf.

Checks run: the full course from the start spot, 20/20, in 4 variants
(plain hop or sail-hop × 0 or 1 Q after ring 2), headless. One rendered run
also passed 20/20. The trampoline retry passed 3/3 headless. Smoke of
`studies/aqueduct_isle.tscn` with the layout: PASS. With 2 Qs after ring 2
he arrives high, sails past the slam point and drops onto ring 3's top. The
bounce refills the bar, so it isn't a dead end, but the driver doesn't
cover it.

## What I'd ask the user to judge

- The hop off the floating stone. Is it right that a plain jump now
  reaches the slab (2.1 m gap), or should the sail stay required?
- Ring 3's new spot (east of the kicker's middle instead of to the side).
  It reads as "spring on through it", which matches the course's
  direction.
- The trampoline ring on crag 1. Is it readable as the way back up?
- Falls. A miss anywhere respawns at the scene's start spot
  (`--foot-at=slabs`), which is close for section 1. From the outcrop on,
  it is a long way back. The layout can't place a checkpoint or move a
  respawn. Also, `--foot-at=ring_route` is still coded to the east islet's
  old spot, which now drops him onto the big slab's east edge.
- Past the outcrop, the old route still climbs a vertical ring stair. If
  the tipped-ring throws are the new style, that stretch could be redone
  in it next.

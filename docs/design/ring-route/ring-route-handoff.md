# Ring route: handoff

This is a greybox prototype with no committed tests. It builds on the slam
spring and the air ring (docs/design/slam-spring/, docs/design/air-ring/).
The route goes on foot from the aqueduct isle's east islet to the bell
spires, using crags of the isle's own turf and rock, the slam-spring slabs,
the air rings and a rock slide.

## Play it

```
./run-zenscape.command --no-title --foot-at=ring_route --ledger=/tmp/ring_route.json
```

You can also start partway: `--foot-at=ring_slide` puts you on the slide
rock's perch, and `--foot-at=ring_far` on the far crag. `--no-ring-route`
leaves the route out.

## Change to the air ring (the user's ask)

The ring's boost is now **6 m** (`AirRing.POP`; it was 2 m). Measured from
the take, his feet rise:

- 6.0 m on the boost alone
- 9.7 m with one updraft
- 12.2 m with two
- 13.3 m with three

He keeps his flat pace the whole way, and the bar is still refilled.

- **The aqueduct's 3-ring chain** keeps its 7.5 m step, and now each step
  takes one Q. The boost alone falls 1.46 m short of the next ring, and the
  boost plus one Q clears it by 2.2 m. The perch is reached off ring 3's
  boost alone. Proved with real input (scratch/ring_route/air_ring_chain.gd):
  slam, the launch, then one Q at each ring, onto the perch with no stun.
  With no Q, ring 2 is missed and he lands on the meadow with no stun.
- **Why the destination is the bell spires.** They are the nearest motif
  isle east, in line with the existing slabs and the east islet: about 290 m
  away, with their turf 12 m above the isle's. The cloister tarn (south) is
  about as far, but the ferry's home leg and the serpent's route both run
  across that gap. The ferry loops round the bell spires' west side
  (z 14 to 80), so the route keeps north of it (z about -12) and comes in
  from the north at x 410 to 420.

## The route (west to east, world x)

| Leg | What | Numbers (size 1, measured) |
|---|---|---|
| Start | East islet (x 131-139, top 31.9) | Faces east. The bell spires show on the horizon. |
| 1 | Three springing slabs, 2.6 m below the islet edge, 6 m apart, each 0.3 m higher | A hop off the edge gives the 1.8 m of air a slam needs. Each launch tops out about 7.7 m up. Slamming over the next slab chains them. Slab 3's launch, sailed, lands on crag 1 about 27 m on. |
| 2 | Crag 1 (x 186, r 6.5, top 32), then the kicker slab off its east edge | The kicker's launch, sailed, covers 38 m to the outcrop (x 233, r 5, top 30), with about 5 m to spare. |
| 3 | The ring stair: a 7-pump slab off the outcrop, with four rings stepping 7.5 m up and 3 m back west over the outcrop | The launch carries him through ring 1. After that it's one Q per ring. Off ring 4 with one Q his feet reach about 68 m, and he sails 60 m east onto the slide rock's perch (top 54.5). A miss from the stair lands back on the outcrop. |
| 4 | The slide rock: the perch, a 2 m step down, then a 35° slope 20 m long falling east, 13 m wide, to a lip at about 41 m | Hop off the step and slam into the slope (2.4 m of air). The slam plants him crouched where he hits (see "Later changes"). Let go of crouch and press it again: he boot-surfs from a standstill and leaves the lip at about **13.0 m/s**. Landing on the slope crouched without a slam surfs at once, as before. |
| 4A | North lane: a standing ring 1.6 m past the lip, its face tipped back 0.15 rad | Slide straight through it: the boost and refill, two Qs (apex about 53 at x 347), then the sail. He lands on the far crag (x 410, r 7.5, top at lip height) about 97 m from the lip. |
| 4B | South lane: a flat ring 3.7 m past the lip and 3.6 m above it | Slide jump at the lip, then Q: his chest rises through it. Then the boost, three Qs (apex about 57.6 at x 357) and the sail, onto the far crag. Branch B needs one segment saved for the Q at the lip. |
| Catch | The catch crag 11 m below the lip (x 333, r 6), with a slab and a 3-ring stair | A fork miss sails down onto it. The stair (one Q per ring, then two more Qs) and the sail take him back out to the far crag. |
| 5 | The far crag's last slab (7 pumps, off its south edge) and one ring above it | Launch, ring, one Q, then sail about 40 m south onto the bell spires' north turf (about x 416-419, z 48, y 42). |

**The slide speed is needed.** He runs down the slope uncrouched and goes
off the lip at a run (4.8 m/s), jumping at the lip, so ring A is still
taken. Even with all three Qs, he reaches the far crag's x about 16 m
below its top and falls. At 13 m/s with only two Qs, he lands on it. The
reason: the sail keeps his pace and bleeds it slowly. Measured from 15 m/s,
he's still at 9.5 m/s after 4 s of sailing (scratch/ring_route/measure.gd).

The sail glides 4.3 m on per metre of drop, at 6.55 m/s and sinking
1.5 m/s. A 6-pump slab launch reaches 9.0 m up, 3.6 m on, and comes back
to its height 8.0 m on without the sail or 44.7 m on with it.

## Proved (headless, real input: scratch/ring_route/route.gd)

- **The whole route, start to finish, both forks, no stuns:** 18 checks
  each, in `aqueduct_isle.tscn` and in `zenscape.tscn`. That's 6 slab
  launches and 6 rings (7 in zenscape, where an aqueduct ring was crossed
  too).
- **Standing launch:** short of the far crag, as above.
- **Catch recovery:** a fork miss lands on the catch crag, and its stair
  leads back onto the far crag.
- **Smoke:** headless import, then `zenscape.tscn` and `aqueduct_isle.tscn`
  for 400 frames each: 0 errors.
- **Tests:** `test_foot_interactables`, `test_aqueduct_isle`,
  `test_motif_sky` and `test_aqueduct_isle_life` all pass. No known test
  breaks.
- **Rendered stills,** checked by eye: the start, the slide rock with the
  standing ring at its lip, the far crag with the bell spires behind it, and
  an overview. They're in scratch/ring_route/ in the main checkout. The
  slide rock first drew its sides as walls standing up from the perch's
  height. It now hangs them from the rim (`hang`).

## Code

- `scripts/interactables/ring_route.gd` holds every position, as constants
  and small static functions, with the measured numbers in its comments.
  `build(study, host)` adds the landforms (`Art.island` / `KitLand.island`,
  turf registered for grass, turf lips) and the pieces (on FootPieces). The
  motor-set offsets go by `WorldScale.wanderer`, while the two ends stay
  fixed. Only size 1 is proven.
- `aqueduct_foot_route.gd` builds the route after the aqueduct's ring chain
  and merges its spots.
- `air_ring.gd` has `POP` 6.0.

## What doesn't work yet / notes

- **The route's first slam (old note, before the plant).** On the slide rock, a press too soon after
  hopping off the perch (under 1.8 m of air) is not a slam. He still lands
  crouched and slides, but without the slam's hit.
- **Branch B's ring sits where a 12 to 15 m/s slide jump plus a Q
  rises.** A much slower or faster lip pace passes outside its 1.5 m hole.
- **The fork has no divider down the slope.** The two lanes are only the
  two rings, 6.4 m apart.
- **The perch glide has thin margins.** From the stair top he reaches the
  perch's middle. Landing short of its west edge means a long fall, because
  nothing catches it there.
- **The aqueduct's old perch** (29 m over the meadow) could be sailed off
  east, skipping legs 1 and 2. Nothing was done about that.
- **None of the route's pieces stand on the bell spires.** Its landing
  strip, the ferry's loop and the parked plane's strip (x 107) are untouched.
  The hall chain's line runs north-north-east from the isle, well clear.
- **No sound for the new boost** (the kit has no hook that fits, as before).

## Later changes (round: movement tuning)

- **A slam plants him.** A slam's touch stops his flat pace, and the crouch
  held through it keeps him crouched in place, with no slide and no surf,
  until it's let go and pressed again (`PilotMotor.SLAM_PLANT`, `planted`).
  So on the slide rock: slam, let go of crouch, press it again, surf. A slab
  launch after a slam goes straight up, with his flat pace from the stick.
- **The rings' tops are trampolines.** Coming down onto a ring's stones
  bounces him 5 m back up, every time, and refills the gauge (`AirRing.BOUNCE`,
  `try_bounce`; foot_pieces `ring_bounces`, the step's "ring_bounce"). On
  ring A, which stands on edge, the top is its upper rim.
- **A side flip fills one whole segment** (`Updraft.FLIP_GIFT`).
- See docs/design/movement-tuning/movement-tuning-handoff.md.

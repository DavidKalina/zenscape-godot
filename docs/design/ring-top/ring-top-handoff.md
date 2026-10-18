# Ring tops and the low slam: handoff (prototype round)

Sits on the movement-tuning build (0c58a4ce). There are no new committed tests.

```
./run-zenscape.command --no-title --foot-at=ring_route --ledger=/tmp/ring_route.json
```

- **The whole top of a flat ring is a trampoline** (`air_ring.gd` `try_bounce` / `_bounce_disc`, `foot_pieces.gd`).
  Feet coming down anywhere on the disc bounce him: the hole, the inner edge, the stones, and out to the outer edge plus a sole.
  The check sweeps the feet's path between frames against the plane of the stones' top, so it doesn't depend on fall speed.
  A slam onto a ring throws him `SLAM_BOUNCE` 8 m. A plain bounce is 5 m. Every bounce refills the charge.
  Going up through the hole is unchanged: he takes the ring and gets a 6 m pop and a refill.
  He can rise into the hole and fall back without his feet clearing the top. If the ring is lit, he takes it as before. If it is dark, or his chest comes down through the stones, he bounces (`fell_in`), so nothing falls down through a flat ring.
  The cause was that only the stones bounced. Coming down through the hole took the ring like going up did. While the ring was dark (2.5 s after a take, so always on the fall back after its pop), he fell straight through.
- **Rings on edge** (`FLAT` 0.5; ring A): these work as before. They don't have the same leak, because the hole faces sideways. The height check is already a sweep.
- **Slam floor** (`slam.gd` `LOW`): lowered from 1.8 to 0.45 m (by size). This is under a plain jump's top: 0.8 m on the ground, 0.63 m off a bobbing slab, and 0.55 m for a 12-frame jump off a slab. 0.6 m wasn't reliable off slabs. A 2-frame tap (0.41 m) doesn't reach it.
  In the sail, a crouch press 0.45 m or more above the ground slams. Below that, crouch is the brake.
  A jump-pound is the weakest hit: strength 0.25, against 0.43 for `decent()` and 0.4 for the weakest kit break. It springs a slab for the full 9 m launch.

Proof (`scratch/ring_drop.gd`, `scratch/low_slam.gd`, `scratch/ring_route/route.gd`, all real input, headless):

- Every drop bounces: walk-off, terminal, slam, sail-slam, the inner edge, the stones, the outer edge, and a slam on the inner edge.
- From below he passes through, takes the ring and rises 5.2 m. After the pop he comes back down and bounces.
- In the route driver, a ring now counts as reached when he either takes it or bounces off it (`reached()`). On ring 3 of the stair he now bounces off the top instead of falling back through it.
- Smoke on `zenscape.tscn` passes.
- `test_foot_interactables` passes.
- `test_slam` has one new failure, "Q with crouch held in the air is the updraft": its 1 m crouch press now slams.
- The full route run is flaky from run to run, on the base too (4 of 6 passed there). Here it passed 6 of 10 across both forks. The misses were sail landings and a downstream divergence, and each leg passes when run alone.

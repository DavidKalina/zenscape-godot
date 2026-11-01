# A new body for the stomper

The stomper (`stomper-handoff.md`) still wears the archive's Olmec body, 250 m
tall and built to carry a 120 m head, so its 144 m torso looks no bigger than
the ruins' 120 m heads and smaller than their 200 m torsos. Replace it with a
new body of the same people as the ruins, about 500 m tall.

## Done looks like

Played in the default game, through the hall, on the real Amberlands
(`doors` world, the far side; force `doors._swap(1)` or really cross, or land and
look stay on the home side). `--world=amberlands` is a debug world on other land:
never judge anything by it.

- Seen beside any ruin, the walking body is plainly the larger: a ruin head would
  sit on its shoulders at about a quarter of its height.
- It reads as made by the same hands as the ruins: the same stone, masonry
  courses, pits, cracks and weathering as `elder_torso`, `warden_torso` and
  `mourner_torso`. Nothing of the archive's design remains: no loincloth slab,
  pectoral plaque or boulder shoulders.
- It has no head and no head-attaching. It is a torso on legs, with arms.
- It walks with weight: anticipation, a held drop each step, follow-through, and
  timing that matches its size (AGENTS.md, Animation). Feet still land on the real
  ground, on terraces and hills, by IK. Legs don't pass through the land.
- Everything the old body had still works at the new size: footfall, wake, shadow,
  solid body, camera sight, the route off the ruins, doors and ponds.
- The grass stays standing through a footfall (fixed at 9bd42b3e, keep it).

## Keep it cheap

About the old budget: one skinned mesh, 24,000 triangles or fewer, 13 nodes or
fewer. Build low meshes the way the ruins do (coarse field meshes, not Decimate,
which made star fans there) and carry the detail in baked normal and AO maps. List
`docs/art/model-budget.md`'s tricks in the handoff.

## Tasks, in order

1. **The still first.** Model the body in Blender with no rig or clip, built from
   the ruins' generator (`art/blender/giant_ruins/giant_head_build.py`: reuse its
   field and `weather()`). Render it beside the ruin pieces at true scale, with
   the plane as a marker. Stop there with a commit: the user judges the design and
   the scale before anything is rigged. Say which torso it grew from and why.
   Offer a second height only if 500 m has a real problem.
2. Bake it and stand it in the game at rest, on the real Amberlands. Stills of it
   beside a ruin, from the air and from the tunnel's mouth.
3. Rig and author the walk. Film it moving.
4. Walk it on the land: stride, step time, IK, route, the constants that came from
   the old size (`HEIGHT`, `MODEL_HEIGHT`, `HIP_X`, `SOLE`, `LENGTH`, `STANCE`,
   `SWING_CLEAR`, `DOOR_CLEAR`, `RUIN_CLEAR`). Check the worst ridge.
5. Rescale what it does to the world: footfall reach, shove, shake, prints, scuff,
   dust, `stomper_solid.gd`'s capsules, the shadow.
6. A pass on looks and cost: frame time beside the old body's, clouds at the new
   height, the legs near the ground. Smoke, then a handoff.

## Rules

- Smoke `studies/endless_flight.tscn` every iteration.
- Prototype rules hold: no committed tests, no full suite.
- Windowed runs pass `-- --no-title`. If a play or capture run needs a save, use
  `--pilot-file=/tmp/<name>.json`, never the real one. `--ledger` doesn't exist.
- The native kernels were rebuilt into this worktree; don't copy over them from the
  main checkout, which is older.
- The smoke failure in `stomper-handoff.md` is still unexplained. If it comes back,
  keep the whole log and put the message in your commit.
- Iteration cap: the skill's default.

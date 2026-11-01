# A new body for the stomper, and smaller heads

The stomper (`stomper-handoff.md`) still wears the archive's Olmec body. Its
scale is right: it stays about 250 m tall. Two things change:

- **The torso's design.** A new body, of the same people as the ruins.
- **Levels of giant.** The ruins are all one size today, with 120 m heads as big
  as the stomper's torso, so nothing in the land matches it. Add smaller heads
  that match the stomper, and keep the 120 m ones: the land holds giants of more
  than one size.

## Done looks like

Played in the default game, through the hall, on the real Amberlands
(`doors` world, the far side; force `doors._swap(1)` or really cross, or land and
look stay on the home side). `--world=amberlands` is a debug world on other land:
never judge anything by it.

- The stomper walks as it does now, at the same size, in a new body. It reads as
  made by the same hands as the ruins: the same stone, masonry courses, pits,
  cracks and weathering as `elder_torso`, `warden_torso` and `mourner_torso`.
  Nothing of the archive's design remains: no loincloth slab, pectoral plaque or
  boulder shoulders.
- It has no head and no head-attaching. It is a torso on legs, with arms.
- Lying about the land are heads of the size that would sit on its shoulders,
  about 55 m tall, in the same half-sunk, weathered way as the big ones. You can
  look at one and at the stomper and see they belong together.
- The 120 m heads and 200 m torsos stay, so at a glance the land has distinct
  levels of size. There are more small heads than big ones. No level smaller than
  55 m (the user's call).
- Sockets on the small heads that are meant to be flown through are sized with
  `WorldScale.opening`. A head too small to fly through is solid, with no false
  opening.
- The land's blank-slate shape stays, as do its flats, and pieces stay dispersed.
- Everything the stomper had still works: walk, footfall, wake, shadow, solid
  body, camera sight, route off the ruins, doors and ponds, and the grass stays
  standing through a footfall (fixed at 9bd42b3e).

## Keep it cheap

The new body: one skinned mesh, 24,000 triangles or fewer, 13 nodes or fewer. Fit
it to the **existing skeleton and `stomp` clip** in
`assets/models/stomper_body.glb`, keeping bone positions close enough that the IK,
`stomper_solid.gd`'s capsules and the constants in `stomper.gd` still hold. Change
those only where the new shape needs it, and say so in the commit.

Small heads add no Godot nodes (`giant_ruins.gd` draws through RenderingServer RIDs
with shared pose meshes) and few triangles: reuse the three faces and fewer poses at
a coarser stride. Scaling `giant_swells.gd`'s stamp and the distance grid with the
piece is expected, including each ruin's `ground` and `inside`. Check texture size:
the giants' maps are about 30 MB already.

Build low meshes the way the ruins do (coarse field meshes, not Decimate, which
made star fans there) and carry the detail in baked normal and AO maps. List
`docs/art/model-budget.md`'s tricks in the handoff.

## Tasks, in order

1. **The still first.** Model the body in Blender with no skinning yet, from the
   ruins' generator (`art/blender/giant_ruins/giant_head_build.py`: reuse its field
   and `weather()`), to the old body's proportions. Render it beside a 55 m head
   and a 120 m head at true scale, with the plane as a marker, front and three
   quarter. Stop there with a commit: the user judges the design before anything
   else. Say which torso it grew from and why.
1b. **Revise the still (the user's verdict on 567530d4: too cutesy, too uneven,
   the cracks are weird).** It must stop reading as a friendly golem or toy.
   - Stance and mass: smaller, less square fists; no finger slots like a mitten;
     heavier hips and thighs so the legs don't read stubby, on the same skeleton;
     a sterner, less rounded chest. Rethink the bead collar if it reads as a toy.
   - Stone: calmer and deliberately carved, with crisp planes and no bubbly, melted
     lumps. Larger blocks of varied size, not one even brick all over.
   - Cracks: fewer, straighter fractures that follow the stone's joints and break
     across it, with no worm-like wandering lines. Chipped corners and a few big
     missing pieces say age better than lines.
   - Small heads: their features must stay clear at 55 m: finer stone for the size,
     or a face rebuilt for it, with no blocky mush.
   The stone and cracks live in the shared `weather()`, so change them there and show
   them on the 120 m head too: the ruins are rebuilt to match in task 3. Same four
   stills, then stop for the user's verdict.
1c. **Reshape the body (the user's verdict on 9ed900c9: way too boxy).** Keep the
   carved block stone, but the figure must read as a body, not a block.
   - A real waist, clearly narrower than chest and hips, and a torso with front,
     sides and back that turn, with no flat slab faces.
   - Arms that hang apart from the trunk, with daylight between arm and side from the
     front, and readable shoulder, elbow and forearm masses that taper.
   - Sloped, rounded shoulders at unequal heights, with a neck base rising from them.
   - Legs that taper from thigh to knee to ankle, with a knee you can see.
   - Stone that wraps the form: courses follow the curve of a limb and step back
     with it, so the outline turns, with no stack of level square slabs. Rounded
     masses first, blocks on top of them.
   - Some asymmetry: a shoulder dropped, a side worn deeper, a great piece missing.
   Stay on the existing skeleton. Do no head work this round: no change to the 55 m
   heads, which stand in the stills for scale only. Same stills, then stop.
2. The user passed the shape at b0da2404, with two fixes to make first: feet that are
   hard, carved stone, not soft rounded slippers, and calmer stone on the legs and
   pelvis, which read as bandages and bulge from the side. Then bake it, skin it to
   the existing skeleton, and swap it in. Check the waist, elbows, knees and thumbs
   survive the 24,000 triangles, and fit `stomper_solid.gd`'s capsules to the new
   chest and shoulders. Stills on the real
   Amberlands from the air and from the tunnel's mouth, and film it walking.
3. The small heads in the land: poses, swells, spread, solid grid. Stills of the
   levels together, flown through the hall to see them as the player does. Fly any
   socket meant to be flown.
4. A pass on looks and cost: frame time beside the old build, the legs near the
   ground. Seen at 81c7d7bb and to fix: in the game the body is pale, flat sand, with
   far less of the carved stone than the Blender stills; the hip and knee smear and
   show a round plug; clouds pass through the arms. Judge the walk's deep crouch
   against the new body and flag it for the user rather than reauthoring the clip. Smoke, then a handoff.

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

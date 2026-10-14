# Olmec destruction, round 1

The experiment: does the headless Olmec body tearing through ruins feel good?
This round puts him on the colonnade spine and makes its piers and lintels
break, Nintendo-style. The breaks are scripted, not voxels.

Branch `feature/olmec-destruction` (off `roguelike`). It isn't merged or
pushed.

## How to launch it

    ./run-olmec-colonnade.command

This is the colonnade study with `--olmec`
(`studies/colonnade_spine_isle.tscn -- --no-title --olmec`). The flags it
takes:

- `--body-knob=k=v` and `--head-knob=k=v`, repeatable, as in the headless
  study.
- `--olmec-at=x,d` and `--head-at=x,d`: where he and his head start, as x
  along the axis and d across it.

R puts him and his head back where they started. What he broke stays broken
for the session. F1 shows his state and the break counts.

## What happens

- **The start.** He stands at the low east end of the way (x 127). His
  head heaves on the L3 plaza (x 58). You start just behind him.
- **The walk.** He walks up the colonnade to his head, about 45 s:
  - The cross lintels across the way (x 123.5 and x 81) are at his chest.
    He plows through them.
  - A pier standing just off his way draws him into it. This is a brute's
    veer of at most 0.34 rad, so he never stops to turn for it. He only
    veers on level ground on his own terrace, within 8 m ahead.
  - In a typical run he breaks 5 or 6 piers and 5 or 6 lintels before he
    reaches his head.
- **Whole again.** He hunts you (`chase` 1, the whole-body chase), so you
  can lure him through what is left. His pounce landings send shockwaves,
  and the shockwaves topple piers.
- **The terraces.** He strides up the terraces' 2.24 m step walls. In this
  study his `step` knob is 2.4 m, against 1.23 m elsewhere. With the old
  step he stalled at the L1 to L2 stair, his bulk held off its cheeks.

## What breaks, and how

`scripts/kit_isle/colonnade_breaks.gd`:

- **What can break.** Every plain pier and every standing lintel: 19 piers
  and 13 lintels. With `--olmec`, the colonnade (`Spine.colonnade(...,
  breakable)`) leaves them out of its one Build. Each is then built as its
  own Build: its own mesh, body and growth. Portal piers and their arches
  stay in the one Build and can't break.
- **What breaks them:**
  - His bulk box: shoulders and hanging arms across, knees to stump.
  - A lintel's length meeting that box.
  - His shockwave front, out to 0.62 of its reach. A pier near the wave's
    middle always falls; one nearer the edge falls by chance.
- **A pier breaking:**
  - It snaps at a drum joint near the hit: 0.9 to 1.9 m up from a body
    hit, 0.6 to 1.2 m from a wave. A stump stays, the kit's snapped pier
    with its ragged head (`RuinKit._pier` with `broken`).
  - The drums above the joint and the capital become pieces. They topple
    the way he pushed, or outward from the wave. The higher pieces go
    faster and spin, so it reads as a column falling over, not exploding.
  - The lintels it carried break in two near the lost end and fall. Each
    half has a slanted crack face. A half still resting on its other pier
    tips off it and often comes to rest as a ramp.
- **Weight:**
  - A hit-stop: 4 frames at 0.12 time scale.
  - He staggers. His speed is cut 55% at once and held down for 0.5 s,
    but he is never stopped dead.
  - A camera jolt.
  - A dust plume, stones kicked out, and a puff wherever a piece lands
    hard.
  - Placeholder synth sounds through the study's sound hook:
    `ruin_crack`, `ruin_fall`, `ruin_thud`.
- **Physics.** Pieces are Jolt `RigidBody3D`s with mass from their volume,
  friction 0.9 and almost no bounce. Each has a simple shape: a cylinder
  for a drum or the capital, a box for a lintel half.
- **Settling.**
  - A piece still for 0.25 s, or slow after 2.5 s, is frozen static in
    place. The walker and he both stand on it.
  - A piece that falls off the isle is freed.
  - When all of a break's pieces have settled, their meshes and the
    stump's are merged into one mesh (`RuinKit.merge`). The bodies stay,
    for collision only.
- **The cap.** `MAX_BODIES` 24, as in `native_explosives.gd`. Past it, a
  piece skips physics: it is laid on its side where it would land, a
  little way along the push, and frozen at once.
- **Routes:**
  - Standing breakables and flying pieces are left out of all his rays
    (`_skip`). His planner and his walls treat them as air: he paths and
    walks through them, which is why he plows rather than going round.
  - Settled rubble is ground to his feet and his planner.
  - When a break settles, every body's routes forget the columns round it
    (`BodyRoutes.forget`) and the route he is on is planned again.
  - His bulk and leg push-out wade through rubble rather than being
    shoved back by it. Before this he got stuck on a lintel half lying
    in the way.
- **Growth.**
  - Each unit grows its ivy at `IVY_SHARE` 0.16 of the detail. That keeps
    the colonnade's growth at 23.4k triangles, against the one Build's
    24.8k.
  - Strands are now spread a little differently: fewer on the piers, more
    on the portals and the fallen stones. This applies only under
    `--olmec`. Without the flag, the colonnade is built exactly as before.
  - Flying pieces grow nothing, since ivy hanging off a toppled drum points
    the wrong way. A broken pier's ivy goes with it into the dust, and the
    stump keeps its own.

The body hooks in `scripts/enemies/headless_body.gd` all hang off one field,
`breaker`. It is null everywhere but this study, so the headless isle and
the generator are unchanged.

## What it looks like

I took rendered stills from the walker's spot on L2, looking east, as he
came up L1. The PNGs are in `scratch/film/`, which is gitignored.

- The pier by his flank kicks out from the base in a dust plume.
- The lintel above it tilts and drops.
- The drums and capital go over his side and lie in the grass. A drum can
  end up stacked on a lintel half.

At his size (about 10 m), the 3.4 m piers read like fence posts going over.
It reads as weight, but small. A slower topple, or bigger dust on
the first frames, would sell it more.

## Checks

- **Import:** a headless import is clean.
- **Smoke:** each passed 400 frames with 0 errors:
  - `colonnade_spine_isle.tscn` with `--olmec` and without
  - `headless_body_isle.tscn`
- **Through the real play loop** (`scratch/olmec_stand.gd`, uncommitted;
  `python tools/drive.py scratch/olmec_stand.gd -- --scene-args --olmec`).
  All checks pass headless and rendered:
  - He breaks his first pier at 25 s.
  - Its pieces settle within 425 frames (peak 10 live).
  - A piece lies frozen static.
  - The walker, by real input (walk and jump), stands on a piece of
    rubble. In the last run that was a drum resting on a lintel half,
    1.3 m up.
- `scratch/olmec_watch.gd` logs his walk, what breaks and the frame times.
  `--lure` walks the walker up the way once he is whole.
- **Tests:** none run (prototyping). No test builds the colonnade with
  `breakable`. The default build path is unchanged, so
  `test_colonnade_spine_isle.gd` and the others that read the colonnade
  should be unaffected. That is unverified.

## Cost

| | Idle | During a break |
|---|---|---|
| Draw calls (rendered, same view) | 368 | up to 393 |
| Physics ms per frame (rendered) | 1.03 | 0.79 average, 1.57 max |
| Process ms per frame (rendered) | 17.9 | 18.4 average, 25.7 max |

- **Live bodies.** 9 or 10 at peak in every run, well under the cap of 24.
  One pier and its two lintels make up to about 8 pieces.
- **Draw calls.**
  - The study without `--olmec` draws 329.
  - Un-merging the piers and lintels adds 39 (+12%). That's 32 small
    meshes, each with a stone surface and, on some, a growth surface.
  - During a break, the flying pieces' own meshes push it to 393.
  - After a break settles and merges, 381.
  - Stone triangles are unchanged (35.6k merged vs 35.2k split).
- **The build hitch.** A break builds its stump and pieces when it happens:
  15 to 20 ms for a pier with two lintels. The hit-stop partly hides it.
  Building pieces ahead of time, or on idle frames for piers near him, is
  the fix if it shows.

## What's left or rough

- **Portals don't break.** They're the arches on the way at x 67.5, 88 and
  117.5. Whole and roaming, he can wedge against a portal pier, as he did
  at (63.8, -12) in one run. Breaking a portal needs its arch ring cut into
  a few chunks, which `_arch_ring` can't do as it is.
- **The temple's gable wall**, the giant wall with the small door, doesn't
  break, and he doesn't climb it. Whole and roaming west, he stalls at the
  foot of the grand stair below it (x 47.4) and bumps there. The user asked
  whether it should be destructible or climbed. See the decision below.
- **Rubble can't be kicked.** He wades through it, and his legs go through
  low pieces for a moment. Kicking it would need un-merging a heap.
- **The veer is a behaviour cheat.** No arm reaches out; his flank just
  meets the pier. A swat or shoulder clip would read better.
- **The seams are scripted.** The seam height is random near the hit, and
  the pieces are always drums plus a capital. True per-hit fracture
  wasn't attempted.
- The sounds are placeholder synths.
- His head's inhale still works on the walker as in the headless study.

### Decision for the user: the temple's gable wall

This is the rose gable at the temple gate (`RuinKit.rose_gable`, x 43.4 on
the podium). It's about 8 m wide and 5 m or more tall, with a small door.
Today he stalls below it.

- **Destructible.** A one-off set-piece break: he punches through the door
  and the gable falls in a few big slabs, with the rose window crashing
  down. It reuses this round's machinery: pre-cut slabs, rigid for a
  moment, rubble after, and the cap. The cost is cutting the gable into
  slabs, and keeping the temple's cover socket and look believable once
  it's gone. My pick: it's the most "Olmec" moment on the isle.
- **Climbed.** His climb takes walls up to 22 m, but the gable has no flat
  top to mantle onto (a pointed apex). He would need a climb target beside
  it: the cella walls or the podium edge. It's cheaper, but it reads as an
  obstacle course, not a giant.

## Models (`docs/art/model-budget.md`)

The new geometry is the kit's own pieces, built apart: drums, the capital,
the stump and the lintel halves (box plus crack face). Here's how each
trick applies:

- **Import LODs and visibility ranges:** apply. The 32 unit meshes are
  1,176 triangles per pier and 12 per lintel. A visibility range on the
  growth surface, or merging distant units back into one mesh, would win
  back most of the 39 draw calls past about 60 m. That's about 0.1 to
  0.2 ms on the render thread. Triangles are already low.
- **Silhouette geometry:** already used. The kit's chips and the crack
  face are real outline geometry; nothing more to save.
- **Vertex-colour grime:** already used. The kit stone shades by vertex
  colour. The pieces keep it.
- **Sculpt high, bake low:** doesn't apply. These are procedural cut-plane
  pieces with no sculpt.
- **Parallax depth:** doesn't apply.
- **Rigid parts on bones:** doesn't apply. Nothing is skinned.

## What the harness lacked

- **A camera override for drivers.** `shot()` uses the study's camera,
  which follows the walker at 7 m. To film the giant I parked the walker
  at a vantage point instead.
- **An outside camera.** A Camera3D of my own drew the study's near cloud
  layer across the frame, and setting the camera in `frame_pre_draw` had
  no effect.

A `--cam-at`/`--cam-look` in `drive.gd` would help.

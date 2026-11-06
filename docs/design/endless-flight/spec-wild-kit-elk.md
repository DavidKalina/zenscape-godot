# Lane spec: wild-kit elk (lanes `wk-elk-mind` and `wk-elk-body`)

The ground escort kind with its wilderness skin, the elk, built in two lanes
of loop `wild-kit` that meet at the contract below (skill `enemy-build`):

- **Mind**: branch `lane/wk-elk-mind`, worktree
  `/Users/davidkalina/Documents/Projects/zenscape-wk-elk-mind`. The herd's
  behaviour, proved through the real play loop. Commits:
  `ITER(wild-kit): lane elk-mind: <task>`.
- **Body**: branch `lane/wk-elk-body`, worktree
  `/Users/davidkalina/Documents/Projects/zenscape-wk-elk-body`. The model,
  rig and clips, proved by eye in rendered stills. Commits:
  `ITER(wild-kit): lane elk-body: <task>`.

Both branch from the loop's step 0 (placed sites). The loop's spec,
`spec-wild-kit.md`, is background: its **Settled** section holds here. Each
commit ends with **Notes for merge** (every line it touched in a file it
didn't create). Each lane is a short loop. Cap: the skill's default. The
user asked for both lanes at once.

Not an enemy: no attacks, no damage, no death, no drop.

## Done looks like

On the fast meadow at the placed site `wild/meadow_herd` (660, 145, facing
east down the meadow), a herd of five to nine elk grazes near the south
treeline: one or two bulls with antlers, the rest cows.

- **Fly over high or slow:** they graze, and the near ones lift their heads
  and track the plane.
- **Skim low past them, beside their line:** they break into a run alongside
  the plane, a gallop that throws up grass and dust, holding beside it for a
  stretch (a creek or a log to leap if the meadow has one), then peel off,
  slow, halt and look back.
- **Fly straight at them low:** they bolt, scatter and break back into the
  treeline.

They run on the land (height from the ground), keep to the meadow and the
wood's edge (no cliffs, no water), and keep off each other. The plane passes
through or over them unharmed; they move off before it reaches them. A run
beside them scores nothing yet: say in the handoff how it could join the
line score.

**Speed:** the herd's top run is a knob. Read the plane's speed range off
the flight code and set the knob so a plane flown at its slow end can hold
beside a running herd, and a plane on Boost overtakes it. Say the numbers in
Decisions.

## Size

From `scripts/world_scale.gd`, as multiples of the plane's span (never a
copied metre figure): body length about 0.9 span, shoulder about 0.55 span,
eye about 0.62 span, a bull's antlers reaching about 0.45 span above the head.

## Code

- The mind: `scripts/endless/kinds/ground_escort.gd` (the kind, no skin of
  its own), its knobs in one dictionary at its top. Registered with one line
  in `KINDS` in `scripts/endless/kinds/kinds.gd`, after `marker`. The site's
  row in `scripts/endless/world/wilderness/placed.gd` swaps `marker` for
  `ground_escort`, skin `elk`, keeping the handle. `--elk=off` leaves the
  marker.
- The stand-in body: `scripts/endless/kinds/escort_standin.gd`, primitives
  (or `scripts/life_models.gd`'s deer pieces scaled to the size above) in the
  elk's size and silhouette, the sockets in place, `play(clip)` driving
  procedural key poses timed to the beats below.
- The real body: `scripts/endless/world/wilderness/elk_body.gd` on
  `assets/models/elk/elk.glb` (`art/blender/` is Godot-ignored), built by
  `art/blender/elk/elk_build.py` (the
  pattern: `art/blender/plane/plane_build.py`; `tools/blender.py` runs it).

## The contract

The only thing the two lanes share. Every name here is final once a lane
has built on it. Changing one is a `spec change` commit and a note to both
lanes.

### Clips

Times are seconds. Loops carry the ground they cover per cycle, in body
lengths (BL), so the mind can match the clip to the ground speed with no
foot sliding (play rate within about ±30%).

| Clip | Length | Loop | Ground per cycle | Beats |
|---|---|---|---|---|
| `graze` | 3.0 | yes | 0 | `graze.lift` 2.2 (head comes up a little, ears turn) |
| `alert` | 0.6 | no | 0 | `alert.up` 0.25 (head fully up, held from here) |
| `bolt_start` | 0.5 | no | 0.8 BL | `bolt_start.crouch` 0.15, `bolt_start.launch` 0.3 |
| `trot` | 0.8 | yes | 2.0 BL | `trot.plant` 0.0, 0.4 |
| `gallop` | 0.55 | yes | 4.0 BL | `gallop.plant` 0.05 (lead fore), `gallop.air` 0.35 (all feet off) |
| `leap` | 0.9 | no | 3.0 BL | `leap.takeoff` 0.2, `leap.land` 0.7 |
| `stop_look` | 1.2 | no | 0.5 BL | `stop_look.halt` 0.35, `stop_look.hold` 0.6 (head turned back, held) |

Each move reads at a glance, with anticipation, follow-through and holds
(AGENTS.md, Animation): the alert's snap and hold, the bolt's crouch before
the launch, the gallop's reach and gather, the leap's tuck and the landing's
give, the halt's slide and the look back.

### Sockets

`head` (the mind turns it to look), `chest`, `rump`, `foot_fl`, `foot_fr`,
`foot_hl`, `foot_hr`.

### Shape

No collider for the plane. The mind keeps the animals apart by the body
length. Eye height as in Size.

### Variants and effects

- Variants, set once at spawn: `bull` (antlers), `cow`.
- Effect `dust`, on or off: a puff of grass and dust at a foot socket on each
  `gallop.plant` and `leap.land` while on.

### The body's API

One script both bodies implement; the mind calls only this:

```
signal beat_reached(name: String)
func play(clip: String, rate := 1.0, blend := 0.15) -> void
func clip_length(clip: String) -> float
func socket(name: String) -> Node3D
func set_variant(name: String) -> void
func set_effect(name: String, on: bool) -> void
func look_at_world(target: Vector3, weight: float) -> void  # procedural head turn
```

### How the API plays

Both bodies follow AnimationPlayer's ways, so the mind sees no difference
(found building the stand-in):

- `play()` on the clip already playing keeps its phase and only changes the
  rate.
- `play()` on a finished one-shot starts it over.
- The body advances itself each frame; the mind puts it to sleep by turning
  its `process_mode` off, and wakes it the same way.
- A beat at a clip's time 0 fires when `play()` is called. Every beat fires
  once per pass of a one-shot and once per cycle of a loop.

## Mind lane: done and proof

The first task builds the stand-in body behind the API. Every later task
plays through it, so the real body drops in with no change to the mind.
Proof: the smoke check of `studies/endless_flight.tscn`. A throwaway driver
through the real play loop for each of the three passes (high or slow, low
beside, low straight at): the herd's states and distances logged, with a
rendered still or a short clip of each. Cheap: the herd sleeps when the
plane is far, and costs show under a `FrameLog.mark`.

## Body lane: done and proof

Built only from this contract and the stand-in's stills (pull them from the
mind lane's commits when they exist; don't wait for them):

- A model and rig in Blender, stylised and in the world's palette (no photo
  textures), with the clips above authored to their names and beats (beats
  as timeline markers), exported to `assets/models/elk/elk.glb`. Import it by
  hand after a build (headless import in the worktree).
- `scripts/endless/world/wilderness/elk_body.gd` implementing the API on the
  glb.
- Rendered stills of each clip's key poses and a strip per clip, judged
  against the animation bar and fixed before handing back.
- The handoff lists which `docs/art/model-budget.md` tricks apply, with
  triangle and frame-time estimates (AGENTS.md, Models). A herd of nine is
  on screen at once, so LODs matter.

## After both lanes

The orchestrator merges both into the loop's branch. The loop then swaps the
real body in behind the API (the stand-in stays behind a flag for
debugging), adds feet planted on the real ground and the head's look-at, and
re-tunes the mind's timings to the real clips.

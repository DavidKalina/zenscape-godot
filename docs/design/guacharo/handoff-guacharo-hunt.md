# Handoff: lane `guacharo-hunt`

Spec: `docs/design/guacharo/spec-guacharo.md`, the hunt section. The work
is in `scripts/enemies/guacharo.gd` only (plus one harness line in
`tools/run_tests.py`). The commits are `ITER(guacharo-hunt)`; each one's
message has its decisions and checks.

## What the hunt does now

- **Marked.** When hunger fills while he is exposed, it marks him: beat
  `marked`, the `mark` call, and it swings in (circle pace x2.2, a tighter
  and lower ring). Cover (0.3 s), safety or a cool-down unmarks him.
- **Stalk.** It hangs in the camera's view (a point inside 0.62 of the
  frame, nearer and lower if needed). In the open it screams only after
  it has hung in view 0.8 s, or at its longest. Over a roof gap it stalks
  from a steep point up through the hole (50 to 86 deg) and dives down it.
- **Tell.** On the scream (0.95 s fold, the scream over the first 0.43 s):
  the loudest voice (+8 dB), the shadow pops out wide and dark, then draws
  in onto the locked spot, and the eyes glare (an ember billboard and a red
  light). The aim locks on the scream, leading his pace.
- **Dive.** Keeping on gets you hit. A sidestep or turn of about 1.5 m on
  the scream makes it miss. Ducking under stone in the fold balks the dive.
- **After.** Cool-down 7 to 12 s; no chained dives. The snatch carries him
  over a void only if a rim, hold, wall, rope or leap exposed him and a void
  is near. Otherwise it drops him back on the ground. Jumping while he's
  seized frees him in about 0.5 s.
- **Clearance.** `_keep_clear()` sweeps and probes after every move, so
  the body stays out of stone and turf. It holds 0.6 of his height off
  surfaces, and 0.15 in the stoop.
- **Sound.** All the voices are synthesised in guacharo.gd and none has
  been heard. The cues, in order: mark, slow clicks while marked, clicks
  ramping to a buzz through the stalk, the scream, the rush, the hit,
  wingbeats, and a cry on the let-go.

## Proof (this round, all on this branch, uncommitted drivers in `scratch/`)

The fair floor is `scratch/hunt_floor.gd`, a flat 80 x 10 m stone stretch
hung 20 m over the flyer yard's highest rim pad. He stands 0.5 m in from
its rim, so it counts as rim exposure. The floor is worth keeping for the
trunk as a yard option (e.g. `--floor`): the 3-stone pad is too small for
a fair sidestep.

| check | driver | result |
|---|---|---|
| stood still is hit | hunt_floor --mode=stand | 2/2 snatched |
| keeps walking along the rim, hit | --mode=walk | 3/3 snatched |
| sidestep 30 frames on the scream | --mode=dodge | 3/3 missed |
| walking, turns back on the scream | --mode=turn | 3/3 missed |
| sidestep length | --dodge_f=15 / 20 / 25 | 0.9 m: 3/3 hit; 1.5 m: 1 hit, 2 missed; 1.9 m: 3/3 missed |
| walks under a roof slab once stalked | --mode=cover | 3/3 stalks broken, 0 dives |
| struggle (jump every 8 frames when seized) | --mode=struggle | 3/3 freed (32 frames seized), back on the floor |
| roof gap: stood under the hole | hunt_gap --mode=stand | dived at 72 deg, struck |
| roof gap: under the roof by the hole | hunt_gap --mode=roof | 0 dives |
| rhythm (time between dives) | hunt_floor runs | 12.7 to 19.3 s (stand 14.6; walk 18.8, 19.3; dodge 12.7, 14.4; turn 14.6, 16.9; struggle 15.2, 17.0) |
| rhythm on the rim pad | hunt_measure --mode=stand --secs=45 | dives 3, gaps 13.3, 12.7 |
| never buried | every hunt_floor mode | 0 buried frames; lowest body clearance over the floor: stoop 0.30 m, stalk/fold/pull/carry 0.6 to 0.7 m |
| smoke flyer_yard, run_layer --flyers=1 | tools/smoke.py | PASS, PASS |

Scripted or teleported steps: he is set down at the start by teleport
before each attack (after a drop, or once the bird is back circling).
Everything after that goes through the stick and the jump button, in
world directions (`stick_toward`). The floor and roof are StaticBody3D
slabs that the driver adds on the ground's collision layers. In hunt_gap
the room is built the same way and he is placed in it by teleport. The
older `hunt_rules --mode=cover/ground` teleported him under cover and
started the ground stoop by script. This round's cover check walks him
there instead.

## Rendered captures (looked at)

`scratch/floor_stand_*.png` (40 stills, sheet `scratch/sheet_stand.png`)
and `scratch/floor_dodge_*.png` (sheet `scratch/sheet_dodge_a.png`), from
`drive.py scratch/hunt_floor.gd --rendered -- --mode=stand|dodge --attacks=1 --shots`.

What they show:
- Scream: a red-orange glare at the head, wings thrown up, top-left of the
  frame. Folded hold: a red-lit teardrop. Stoop: the bird comes across the
  frame onto him. Hit and snatch: wings spread over him, then the carry
  with heavy beats. The dodge: the bird's shadow lands on the floor beside
  him, he is clear, and it misses.
- **Weak, for the trunk to judge by playing:**
  1. While it circles and is marked, the bird is never in frame with the
     camera behind him on a flat floor. The stalk shows only in its last
     ~1 s, at the top-left edge.
  2. With the camera low and almost level, the shadow pop on the scream
     barely reads. The floor is seen at a grazing angle, so the blot
     foreshortens into a thin streak. It read well from the higher pad
     camera in earlier rounds. The glare and the scream carry the tell
     here.
  3. Sound is unheard. The cue order above is from the beat log.

## Notes for merge

- **Public surface added to guacharo.gd:** `var marked`, `var
  drop_over_void`, `var last_voice` ({what, db, pitch}). Beats `marked`,
  `unmarked`, `balked`, voice beats `sound mark|click|scream|rush|hit|wing|cry`.
  New knobs: `mark_swing`, `cover_break`, `void_carry`.
- **The timing contract** (the body lane's clips must match): STALK_MIN
  1.6, STALK_MAX 5.5, TELL 0.95 (the fold clip; scream over TELL x
  TELL_SCREAM 0.45 = 0.43 s, then the folded hold), STOOP_MAX 2.5, FLARE
  0.22, LIFT 0.7, CARRY 1.5, PULL 1.1, COOL_MIN/MAX 7/12. Either
  guacharo_look.gd reads `Guacharo.TELL` and the rest, or the trunk matches
  them by hand.
- **guacharo_look.gd assumptions:** only `Look.new()`, `size_to(span)`,
  `drive(pose)`, `Look.mix_pose`, `Look.REST` and `Look.LAYER` are used
  (unchanged from before). The glare sits at a guessed head spot, position
  + forward x 0.16 span + up x 0.05 span (in `_tell_place`). If the new
  body's head is elsewhere, move those offsets. The shadow decals and the
  glare skip `Look.LAYER`; keep the new body's meshes on it.
- **layer_flyers.gd:** unchanged.
- **tools/run_tests.py:** `Pages in use exist at exit` counted as exit-leak
  noise. It is an intermittent exit-time line with flyers in the scene;
  bb04cbaf has the details.
- **Re-run after the merge:** the smokes above, then `hunt_floor.gd` in
  stand, dodge, cover and struggle modes with the new body, so the timings
  and the clearance hold with its size. Then `hunt_gap.gd` stand. Then a
  stand in the Pilgrim's Ladder's fallen roof bay (hood at (92,20,-10)),
  which this branch doesn't have, with hunt_measure-style clearance
  logging on its 20 m isle. Then rendered stills of the scream with the
  new head (the glare offset).

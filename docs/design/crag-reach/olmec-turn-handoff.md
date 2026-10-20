# Handoff: the Olmec turns on the spot with authored clips (prototype round `olmec-turn`)

**Play:** `godot --path . res://studies/crag_reach.tscn -- --no-title --olmec`.
The old stepped turns come back with `--body-knob=turn_clips=0`.

## What was wrong

A stood turn was chained from one generic step clip (`turn_open_*` /
`turn_close_*`, 0.66 s each, trunk and legs only). The figure's yaw ran on a
procedural curve beside it, and the feet were IK'd round after it. The
figure read as spinning rigid with little hops, and the planted feet slid
0.15-0.48 m/s (studio: 0.19-0.42).

## The clips (art/blender/headless_body/headless_body_build.py, "whole turns on the spot")

Six one-shot clips, each a whole turn. The root is yawed through the clip
(new channel `ry`), and the feet are keyed on the ground in the clip's start
frame (new channels `g{L,R}{x,y,z,a,p}`), so a planted foot stays put while
the trunk comes round over it.

- **`turn_90_l` (1.9 s):** loaded onto the right foot, a sink, and the
  shoulders wound right. The left foot opens back to the quarter as the
  shoulders lead round. It plants flat into a held squash, and the weight
  rolls onto it. The right comes round in front and plants. He rises, and the
  shoulders settle back past square.
- **`turn_180_l` (2.7 s):** three steps. The left opens to the quarter, the
  right swings all the way round in front to the half (the big one, the trunk
  thrown after it), and the left comes home. A deeper wind-up, and the same
  squash holds.
- **`turn_45_l` (1.1 s):** a low quick shuffle, two short steps.
- **`*_r`:** mirrors.

Each step's foot swings on an arc round the middle, from its stance at one
yaw to the next. The root's yaw is the feet's mean, eased from lift to just
past plant. A heel peels (toes kept on the ground) before each lift.
`TURN_PLANS` in the build lists each clip's steps.

Posing changes, all inert for the old clips:
- `pose_of` yaws the root when `ry` is given.
- `solve` flags a posed root.
- A turned leg keeps its frame's sign (`Pose.leg_x`), so the shin doesn't
  flip 180 degrees between keys.
- `_mirror` knows the new channels.

`bake_clips.py --check` shows idle, walk, hunt_stride, teeter, topple,
turn_open_l and climb bake identically to before.

The glb was re-exported by a full Blender run (`--blend`, so the .blend is
saved too). The Blender export and the plain-Python bake agree to 6e-8. The
model's geometry is unchanged, so the model-budget tricks don't apply.

## How they're picked and played

- **The pick** (`headless_body_steps.gd` `_whole_step`, knob on, STAND mode):
  the lag between the figure and the turn's goal (`_turn_goal`) picks the
  clip.
  - Under 0.2 rad (`WHOLE_EASE`), the hips ease round as before.
  - Up to 1.1 rad (`WHOLE_90`), `turn_45`.
  - Up to 2.25 rad (`WHOLE_180`), `turn_90`.
  - Past that, `turn_180`.
  - The lag's sign picks `_l` or `_r`.
  - A foot left far from under the hips with no turn to make gets `turn_45`
    with its yaw scaled to 0: a settling shuffle on the spot.
- **The yaw:** the look reads the root's yaw off each clip's track at build
  (`turn_yaw`, sampled at 60 Hz). The figure's yaw is `start + clip yaw x
  scale`, where scale is the wanted turn over the clip's own angle. So a turn
  of 60 degrees plays the 45 clip at 1.33.
  - The root's turn is kept out of the pose (`advance` resets the root's
    rotation while a whole turn has weight).
  - In STAND, the body's facing is the figure's yaw, as before. His facing,
    sight cone and stare beat follow the clip's progress.
- **The feet:**
  - The steps' foot lock holds each foot where it stands, except in the
    clip's swing windows (`TURN_CLIPS`, which mirrors `TURN_PLANS`).
  - In a swing window, the foot is carried to where the clip has it.
  - A foot's place round his middle and its yaw are scaled as the turn is, so
    a scaled turn still sets each foot down where the stance ends up.
  - The floor lift (`floor_at`, sole on steps and ledges) is unchanged on top.
- **Blending:**
  - The whole turns blend the whole body over 0.14 s (`WHOLE_FADE`), from and
    back to the idle under them.
  - If he leaves STAND mid-clip (walks off, or a state change), the clip is
    dropped and fades out under the walk, stride or state clip.
  - Hunting, they play at the existing `TURN_PACE_HUNT` 1.3: a 90 in 1.46 s,
    a 180 in 2.08 s, the shuffle in 0.85 s.

## The knob

`turn_clips`: 0 by default, **1 in `OLMEC_KNOBS`** (studies/crag_reach.gd).
olmec_field, whole_body_chase and the boss keep the old stepped turns. With
the knob off, the steps code runs exactly the old path, because every new
branch is gated on `whole`.

## Foot slip (a planted foot's flat speed)

| | old stepped turns | whole-turn clips |
|---|---|---|
| studio, 90 / 180 (turn_view) | 0.19-0.39 / 0.28-0.42 m/s | 0.05-0.07 / 0.06-0.09 m/s |
| crag bench, 90 / 180 / 40 (turn_bench) | 0.17-0.48 / 0.31-0.38 / 0.14-0.21 | 0.04-0.06 / 0.05-0.08 / 0.04-0.08 |
| crag, real loop, every turn over 50-60 s (turn_play) | not split out | 0.09-0.17 mean |
| largest IK correction in a turn | 1.0-1.5 m | 0.06-0.16 m |

The run round's reference is 0.23-0.36 m/s.
- **Studio and bench:** the planted foot is the one within 0.1 m of its
  lowest.
- **Real loop:** the foot is planted per the steps code, low, on frames he
  was posed. Far off he is posed every 2nd or 3rd frame, and a per-frame
  measure then reads a jitter that is in the old turns too.

In the real loop at west_terrace_1 he used all three clips, both ways. In one
50 s run, 13 turns: 8 shuffles, 3 quarters and 2 halves, in chase and stare.

## Capture sheets (git-ignored, captures/olmec_turn/)

- **`studio_*`:** a plain floor with the head on, through the game's own
  steps and look. Includes `studio_old_90_front.png` and
  `studio_old_180_front.png` for comparison.
- **`crag_bench_*_you.png`:** on the crown, from the wanderer's side. The
  head is missing in the bench (the body is out of the field's update, so the
  head isn't carried).
- **`crag_play_180_side.png`:** the real loop at a rim. He stares, turns 180
  in three steps, then winds up and leaps.

## headless_body.gd edits (for the merge)

- `_animate`, right after `look.steps.pace = ...` (one line plus a comment):
  `look.steps.whole = float(knobs.get("turn_clips",0.0)) >= 0.5`.

Nothing else in headless_body.gd changed. The other edits are in
headless_body_look.gd (new clips, `WHOLE_TURNS`, `turn_yaw`, `foot_yaw`, the
root reset, `whole_turn_weight`), headless_body_steps.gd (`whole`,
`TURN_CLIPS`, `_whole_step`, swing windows, and the scaled foot base in
`plant`), the build script, the glb and .blend, and OLMEC_KNOBS.

## Still off

- **The suck's turning:** in plant, suck, gulp, swat and windup, his facing
  still swings him round rigid with the clip's feet (steps mode OFF). Those
  states turn by small amounts while tracking you. A legs-only shuffle under
  the brace would need a second, legs-filtered copy of the turn clips in the
  blend tree.
- **Back-to-back reversals:** he can pick a turn while the planner is about
  to flip (for example, a 180 left then a 180 right 2 s later at a rim). The
  clips play whole; that is a decision issue, not this round's.
- **The head's stump twist:** `nt` leads the turn in the clip, but whole and
  hunting, the gaze (olmec_gaze.gd) overrides the head's yaw anyway.
- **Turn lengths:** at hunt pace, a 180 takes 2.1 s against the old 1.9 s.
  This lengthens the stare beat a little.
- **Uneven ground:** the clips are authored on flat ground. On a slope, the
  floor lift and IK adapt the feet, but the trunk doesn't lean to it.
- **Reading by eye:** captures were judged as stills. The rendered real-loop
  film is backlit at that rim, so a studio movie or a play session is the
  real check.

## Proof

- Headless import. **Smoke PASS:**
  - crag_reach plain and `--olmec`
  - olmec_field, whole_body_chase
  - heist_level (`--ledger=/tmp/olmec_turn_ledger.json`)
- **Throwaway drivers** (scratch/, uncommitted):
  - `turn_bench.gd`: him on the crown with his brain off; each turn alone
    through `_animate`; ROW per turn; `--trace`, `--film=side|you`.
  - `turn_view.gd`: studio stills (SceneTree, rendered).
  - `turn_play.gd`: the real loop; logs every whole turn and the slip;
    `--film`.
  - `stare_move.gd`: copied, with clip logging. Its islet_14 stare no longer
    happens on main: he chases instead.
- **Tests:** no committed tests, full suite not run. No test references the
  body, its look or its steps, so none should break.

## Harness gaps

- A drive.gd foot-slip helper (the planted foot's flat speed per posed
  frame) is still missing; two scratch drivers carry their own.
- A studio pose viewer that plays a body through its look and steps
  (`scratch/turn_view.gd`) would be worth promoting to tools/.

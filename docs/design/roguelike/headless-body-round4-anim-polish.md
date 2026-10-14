# Headless body, round 4: turns, listening, the wall-feel and the mantle

Round 3 (`headless-body-round3-anim.md`) gave the body its model and clips.
The user played it and four things read cheap:

- He turned in place like he was on a turntable.
- The headless listen gesture looked wacky. The user then dropped it
  altogether.
- Nothing came before a climb.
- The mantle was a shimmy, his legs worked up over the lip.

This round changes those four beats. Every other clip and behaviour is as
before.

## What changed

### Turning: stepping turns (`scripts/enemies/headless_body_steps.gd`)

- **Facing still turns as it did.** The body's `facing` and every rule that
  turns it are untouched. Only the figure (the model under the body node)
  is turned separately, by a visual yaw.
- **Standing** (listening, the route's turn on the spot, reaching for the
  head, triumph, feeling the wall):
  - The figure holds still while the facing turns away from it.
  - Once the figure is `TRIGGER` (0.14 rad) behind, it takes a step. Each
    step is an authored clip of `STEP` = 0.66 s, followed by a 0.1 s held
    beat.
  - Over a step the figure turns on a curve:
    - it holds back 4% (anticipation)
    - it turns round to 105% by 0.6 of the step
    - it settles to 100% by 0.8
  - A step turns at most `MOST` (0.8 rad, about 46°). Its angle is the lag
    plus a lead for a turn that is still going.
- **The feet** (two-bone leg IK on top of the clips):
  - The standing foot stays where it is planted. It pivots on its ball no
    more than `PIVOT` (0.35 rad) off the hips.
  - The swing foot is carried from where it stood to under the turned
    hips. The clip gives its lift and pitch.
  - A big turn alternates feet: first the open step (the foot on the
    turn's side steps out), then the close step (the other foot comes
    round).
  - A small turn is one step, with the other foot pivoting.
  - A foot left more than `SLIP` (0.45 m) from under its hip (when a turn
    stops, or after a slide) gets a settling step.
- **The clips:**
  - `turn_open_l` and `turn_close_l`, plus their mirrors `turn_open_r` and
    `turn_close_r`.
  - The beats: weight onto the standing foot and a dip; the hips lead the
    turn, the shoulders and stump lag; the foot plants fast and flat into
    a held squash (0.945); the shoulders follow through; then the settle.
  - They blend over the trunk and legs only (Blend2 filters), so the arms
    keep whatever the body is doing.
- **Walking:**
  - The figure follows the facing a beat ahead (the hips lead,
    `LEAD` 0.12 s of the turn rate).
  - The chest counter-twists (the shoulders follow) and the spine leans
    into the turn.
  - Each foot is held where it came down while the walk has it planted,
    then carried on to where the walk puts it as it swings. The feet no
    longer skate round in turns.
- **Climbing, leaping, landing:** the figure catches up with the facing
  quickly (in about 0.1 s), and the feet are the clips' own.

### Listening (headless): no gesture

On the user's call the raised-arm, torso-twist listen is gone. A slowed
version was tried first and dropped. The `listen` clip (2.6 s, the
`listen` knob) now:

- breathes out, sinks a little and goes still, with the arms slack
- holds
- on "heard" (as the game starts turning him), lifts the stump slightly
  and closes the fists
- returns to standing

There is no arm raised and no twist. Past the clip's end (he is still
planning his way), he breathes in the idle clip instead of freezing.

The logic used to sweep `facing` ±0.55 rad during the listen, which was a
turntable spin. That sweep is removed; it ended where it started, so the
way he picks is the same.

### The wall-feel before a climb (new state `feel`)

When a wall he will climb stops him, he no longer starts climbing at once:

1. **He squares up to the wall.** He steps round to face it.
   - Met slantwise, his turned shoulder would be in the face (his walk
     already brings him there). In that case he pivots square at once and
     his feet step after.
   - He is eased off the face to the climb's standoff plus `FEEL_BACK`
     (0.5 m). The distance is measured off the face's nearest point over
     his height, from rays at the knee, hips, chest, shoulders and stump,
     so undercuts, bulges and steps count.
   - His planted feet shuffle back with him and are kept `FEEL_TOE` off
     the face.
   - He never backs off a rim.
2. **The beat (`feel` s, default 1.0):**
   - The right hand comes up close by his side with the fingers already
     turned up, then goes out.
   - The palm lands flat on the real face. The game puts the wrist
     `FEEL_PALM` (0.9 m) off the nearer of two rays (at the wrist and at
     the fingertips), along that point's normal, with the palm turned into
     the face.
   - He presses, slides the hand up and in a little, holds as if sensing,
     gives a small nod, and the left arm flexes ready.
   - Then the climb starts exactly as before.

The square-up waits until he is within `FEEL_SQUARE` (0.3 rad) and in
place, and takes at most `FEEL_WAIT` (0.8 s), then the 1 s beat runs.
Cliff spawns skip the feel.

### The mantle (rewritten, two styles)

The old shimmy is gone. Both styles take the same `mantle` time (1.4 s),
start and end where the old mantle did (`_mantle_from` to `_mantle_to`),
and end in the same states (listen, or roam on a perch). They are the same
with or without the head.

- **Press-up (`mantle`, the default)**, from where the climb hands over:
  hands on the lip, the lip about 3.6 m over his feet.
  1. Gather, 0 to 0.28 s: he sinks, the elbows bend and the stump bows.
  2. Press, 0.28 to 0.5 s: a hard press down through the arms pops him
     up, the legs driving down. The hands leave the lip at the top of the
     press, at 0.48 to 0.59 s.
  3. Air, 0.5 to 0.92 s: knees tucked under him, arms flung out, a held
     beat at the top (0.7 to 0.78 s), then the legs reach down.
  4. Land at 0.92 s: a squash of 0.77, held. The shockwave, a dust plume,
     a quake and a step sound fire now, not at the state's end.
  5. A rebound, the settle and the recovery until 1.4 s.
- **Pull-up (`mantle_pull`, knob `mantle_pull` = 1):**
  1. He pulls as soon as his hands have hung on a lip over his head for
     `PULL_AFTER` (0.45 s).
  2. A tuck, a hard pull that brings his chest to the lip, let go, popped
     on past it with the feet swung under him.
  3. The same landing, at 0.95 s.
  - He mantles from lower, so the climb is shorter: about 4 m less climbed
    at haul speed. That changes his timing, which is why it is off by
    default.
- **The hands** are pinned to the real lip by IK through the gather and
  the press, then let go.
  - The wrists sit 0.65 m out from the face and 0.5 m over the top (the
    build's `LIP_OUT`), the palm down and fingers flat.
  - So the forearm runs up the face outside it, and the hand lies over
    the edge instead of through the corner.
- **Why press is the default:**
  - It keeps the climb exactly as it was, so routes and timing hold.
  - Its clipping measured lowest (see "What was verified").
  - The pull-up reads well too, maybe more dramatically (a clear hang,
    pull and pop), but it shortens the climb and its hands clip more at
    the hang and the release.
  - Both are captured. The user may prefer the pull-up.

## Knobs

| Knob / constant | Default | What |
|---|---|---|
| `feel` (knob) | 1.0 s | The wall-feel beat. 0 skips it. Squaring up first adds up to `FEEL_WAIT` = 0.8 s |
| `mantle_pull` (knob) | 0 | 1 uses the pull-up mantle |
| `listen` (knob) | 2.6 s | Unchanged. The still listen clip scales to it |
| `Steps.STEP`, `HOLD` | 0.66 s, 0.1 s | A turn step and its held beat (the clip is made for 0.66) |
| `Steps.TRIGGER`, `MOST` | 0.14 rad, 0.8 rad | Lag before a step; the most one step turns |
| `Steps.SLIP`, `PIVOT` | 0.45 m, 0.35 rad | Settle-step distance; how far a planted foot pivots |
| `Steps.LEAD`, `LAG`, `LEAN` | 0.12 s, 0.16, 0.1 | Walking turns: the hips' lead, the shoulders' lag, the lean |
| `FEEL_BACK`, `FEEL_PALM`, `FEEL_TOE` | 0.5, 0.9, 1.6 m | Feel clearances (model metres) |
| `FEEL_SQUARE`, `FEEL_WAIT`, `FEEL_EASE` | 0.3 rad, 0.8 s, 2 m/s | Square-up before the feel |
| `PULL_AFTER` | 0.45 s | Pull-up: how long he hangs on the lip before pulling |

## The pipeline without Blender

This Windows PC has no Blender. Installing it needs a download, which
needs the user's permission. So:

- **Every clip is still authored in the build script**
  (`art/blender/headless_body/headless_body_build.py`), as round 3's are.
  A Blender rebuild makes the same clips.
- **`art/blender/headless_body/bake_clips.py`** runs the build script's
  rig, key poses, tracks and IK solve without Blender:
  - It uses plain-Python stand-ins for mathutils
    (`art/blender/headless_body/mathutils_lite.py`).
  - It converts each frame to the glTF node transforms the Blender
    exporter writes.
  - It puts the named clips into `assets/models/headless_body.glb`. The
    mesh, skin and every other clip are left as they are.
- **The bake matches Blender's export exactly.**
  `bake_clips.py --check=idle,walk,climb,listen,mantle` re-baked round 3's
  clips and compared them with the glb's:
  - translation and scale: equal to 5 decimals
  - rotation: 1 - |dot| about 6e-8 (float32)

Usage:

    python art/blender/headless_body/bake_clips.py --clips=feel,mantle [--drop=old_clip] [--check=idle]

`listen_r` (the slowed gesture's mirror) was baked and later dropped with
`--drop`.

## What was verified

- **Smoke check: passes.** A headless import, then
  `studies/headless_body_isle.tscn` and
  `studies/run_layer.tscn -- --shape=sprawl --seed=2` each loaded headless
  for 600 frames with no script errors.
- **Route and turn check: passes.** This was a throwaway headless run of
  the isle study at a fixed 60 fps (`.claude/tmp/`, deleted).
  - The state sequence is the same as before: spawn haul, mantle, listen,
    roam, then feel and climb at B, two leaps, a second climb, then home,
    reach and triumph.
  - Time to whole: the baseline (round 3 code) reached it at 187.9 s.
    This round reached it at 190.5 s and 172.7 s in two runs.
  - The route search is budgeted by wall-clock time (`ROUTE_US`), so runs
    vary by several seconds. The two feel beats add about 2 to 3 s.
  - Every stood turn of 90° or more now steps (2 to 7 steps). The figure's
    yaw is held 30 to 65% of the turn's frames, the feet stand still most
    of the frames, and the root doesn't move.
  - The baseline turned with 0 steps. In its route turns the figure's yaw
    was held on 0 frames, and its feet moved on every frame.
- **Penetration checks.** Throwaway headless runs skinned every 7th vertex
  (about 6k) and ray-tested each one against the real collision, at the
  beat's samples.
  - **Wall-feel**, during the beat itself:
    - the hold is clean
    - the hand (its thumb) is at most 0.07 to 0.13 m behind the face at the
      moment of contact and of release
  - **Wall-feel**, the first 0.1 to 0.2 s after a slantwise meet:
    - the trunk and arms are up to 1.5 m inside the face
    - this is where his walk had already put him (round 3 walks into walls
      slantwise the same way); he is eased out at once
    - not fixed here: it is the walk's wall detection, which is behaviour
  - **Press mantle:**
    - hands 0.07 to 0.12 m
    - forearm at most 0.13 m during the press
    - trunk at most 0.05 m during the gather
    - the haul's hand clip (round 3) adds 0.4 to 0.5 m for the first 0.05 s
      as it fades out
    - on B's second climb the hanging feet and legs are 0.75 m into a
      lower block; this was already the case before this round
  - **Pull mantle:**
    - hands 0.45 to 0.6 m at the hang, and 0.7 to 0.8 m at the release
    - forearm and trunk small
    - a reason it stays off by default
- **Rendered captures, judged by eye.** These were small windows, one at a
  time, quit by a watchdog, under
  `docs/design/roguelike/headless-body-anim/round4/` (gitignored). They
  cover:
  - the listen (front)
  - stood turns (front and from above)
  - both wall-feels from along the wall, from each side
  - the press and pull mantles, from the side and three-quarter
  - **Turns:** the feet step and plant, one foot lifting at a time.
  - **Listen:** still, no arm.
  - **Feel:** the hand is flat on the face with the forearm level into it,
    and the body is clear of the rock.
  - **Mantle:** both read as gather, pop, air and a heavy land.

## Not verified

- I didn't play it interactively.
- I didn't judge snappiness from motion. The captures are stills and
  contact sheets.
- I didn't capture a walking turn on its own.
- The whole-body chase mode another agent is adding to `headless_body.gd`
  isn't in this branch. It calls the mantle after climbs; the mantle's
  start, end and states are unchanged, but this is untested with it.
- I didn't look at frame times. Leg IK runs on two more limbs a frame
  while standing or walking, inside the existing ANIM_FAR throttle.

## Models (`docs/art/model-budget.md`)

- The geometry is unchanged: the same mesh (about 89k triangles), skin and
  bones. Only clips were added or replaced in the glb (it went from 3.29
  to about 3.6 MB).
- None of the geometry tricks apply this round, and there are no savings
  to estimate. Round 3's open note stands: at 89k triangles, baking low
  and import LODs are the big wins if many bodies are on screen.

## Tests

`python tools/run_tests.py` was run headless on this Windows PC, with
other agents' Godot runs going at the same time. It took 2608 s.

| Result | Count |
|---|---|
| Passed | 242 |
| New failures | 69 (54 failed, 15 timed out) |
| Known failures | 2 |
| Skipped (GPU) | 31 |

- **The failures span unrelated areas:** sky, landscapes, worlds, the
  pilot, hands, cozy worlds, viaducts and gamepad.
- **None comes from the body's code.** Every script error in their logs is
  in the tests' own code, for example:
  - `test_layer_sprawl.gd:133`, an empty sprawl plan
  - `test_motif_sky.gd:58`
  - `test_no_bigfoot.gd:63`
  - `test_world_session_scene.gd:67`
- **Other errors look environmental:** Mac-only paths
  (`Could not create directory: '/private'`), and timeouts under load.
- **No test references the headless body.** I grepped `tests/` for
  `headless_body` and `stone_body`.
- **I didn't run a baseline suite on this PC to compare against,** so
  which of the 69 also fail without this round is unverified.
- **`tests/known_failures.txt` is untouched.**

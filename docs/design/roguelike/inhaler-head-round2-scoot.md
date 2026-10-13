# Inhaler head, round 2: the scoot (prototype)

Round 1 is `inhaler-head.md`. On `feature/head-scoot`, off `feature/layer-bodies`.

The ask: the head stops floating. Alone it is a pathetic, ground-bound head
that heaves itself along, still inhales and is still a hazard, but a joke
next to the head on its body. Its calls when you are near still help the
body find it.

## Play it

    ./run-inhaler-head.command
    godot --path . res://studies/inhaler_isle.tscn -- --no-title [--head-knob=heave_step=1.2 ...]
    godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
    godot --path . res://studies/headless_body_isle.tscn -- --no-title

In the study the head heaves round the turf east of the aqueduct, up onto
a new floor slab (a 0.2 m step), and toward a point past the east rim. It
stops at the rim and turns away. **F1** now also shows the action (heave,
sag, pivot, rest), heaves, notches, balks, calls, falls and its height over
the turf. Sprawl 2 has two heads on the generator's isles, each with a
body.

## What changed

All of this is in `scripts/enemies/inhaler_head.gd` unless noted.

- **On the ground.** It sits on its jaw course with no hover and no bob.
  - Five rays under its middle, chin, heel and sides set its height and
    tilt it to the slope (up to `slope` rad).
  - A step down drops it at once. A step up it heaves onto.
  - With nothing under its middle (shoved or slid off a rim) it falls
    under gravity, tumbling. It lands with a big thud and is dazed, rocking
    itself upright. Below the study's `lost` it is gone.
- **The heave.** It moves only by authored key poses (`HEAVE`), played
  procedurally on the rigid skin:
  1. a small forward dip;
  2. it rocks back onto its heel edge (the anticipation) and holds there,
     straining with a tremble and a strain sound;
  3. it throws itself forward past flat onto its chin edge, lurching
     `heave_step` m with a little lift;
  4. a thud: a squash to 0.88, a skirt of dust along the chin, a thud
     sound;
  5. a bounce, then it rocks back down flat with a small overshoot;
  6. a rest of 0.3-0.95 s.
  - The pitch pivots on its real jaw edges (chin or heel), so it reads as
    a block being rocked, not a glide.
  - Each heave's timing and step vary by about 10-15 %.
  - Every 4 or so heaves it pants a longer rest.
  - 18 % of heaves are a **sag**: it rocks back, strains, and sags down
    having got nowhere.
  - Average pace is about 0.45 m/s, a fifth of your walk.
- **Ground rules for a heave.** It heaves only where it can rest after:
  turf under its middle, its chin edge and both sides, no more than
  `climb` (0.45 m) up or `drop` (0.84 m) down, and no stone in the way.
  Where it can't (a rim, a face, a chest), it sags in place, counts a
  balk and turns to its round's next point.
- **The pivot.** It turns in grinding notches, not a smooth yaw. One side
  lifts (the tell), it swivels up to `notch` (0.32 rad) on the other
  side's edge, and drops with a small thud, dust off both sides and a
  scrape.
- **The inhale on the ground.**
  - The jaw stays on the turf, so opening the mouth tips the head back on
    the jaw's hinge. The gape rears up, which is the tell.
  - Tell: 1.8 s (was 1.4). It rears back, the eyes light and the dust
    starts streaming in.
  - Inhale: it slams forward onto its chin with a thud, and the draw
    kicks in. The airflow comes from the mouth about a metre off the
    ground and hugs the turf.
  - While telling or inhaling it can only track you in notches, with a
    `track_rest` (0.55 s) rest between them. A strafe across its face gets
    out of the cone sooner than before.
  - Seen but out of reach, it heaves after you (desperately, with shorter
    rests).
  - Gulp: it chews on you, rocking on its chin.
  - Blast: it rears back with the kick and slides back `recoil` (0.67 m).
    If it sits at a rim, that can tip it off.
  - After: it slumps, spent, for 3.5 s.
- **Weaker and slower.**
  - Pull: run × 1.05, was × 1.3. d0: unit × 3.5, was × 4.
  - Reach: unit × 9.5, was × 12. Sight: unit × 11, was × 13.
  - Trip: run × 0.75 for 0.55 s.
  - Blast: unit × 15 out, was × 24.
  - Inhale: 3.5 s, was 4.5.
  - Its cost is 3, was 4.
- **New contact attack.** Its lurch onto its chin shoves you about 2.5 m
  if you stand at its face. You can't push it.
- **Calls.** With you within `call_r` (16.8 m), seen or not, it calls every
  3 s or so: a jaw flap, a puff and a moan (`head_call`).
  - New API: `calls`, signal `called`, and `calling()` (it called within
    `call_hold` s).
  - The body doesn't use them yet (see the body-side asks below).
- **Its voices** are one table, `InhalerHead.VOICES`, used by both studies
  and the generator. New voices: `head_thud`, `head_scrape`,
  `head_strain`, `head_call`.
- **The body's interface is kept.**
  - `perch`, `head_seat` / `head_facing` / `head_tilt` on the body's side,
    `ground_y()`, `home()`, `go_home()` (now sets it back on the turf),
    `swallowed`, `height` and `length` all work as before.
  - New on the head's side: `rest_point()` (its jaw's foot on the turf),
    `on_ground()` and `shove(v)`.
- **Look** (`inhaler_head_look.gd`): `hinge()`. **Air**
  (`inhaler_head_air.gd`): `thud()` and `call_out()` puffs.
- **The generator** (`scripts/roguelike/layer_enemies.gd`).
  - It lays rounds on ground the head can actually heave over: turf under
    its middle and all round its foot, cell-to-cell rises within `climb`
    or `slope`, and no void cells (`VOID_CELLS` 0).
  - It uses the head's knobs (`climb`, `slope`), not `hover`.
- **The study.** The route is on the turf with one point past the rim, and
  a floor slab was added as a step.

No model change: the glb, rig and triangles are untouched, so there's no
model-budget assessment. All the motion is whole-body, on the skin.

## Knobs (`--head-knob=`)

New:

| Knob | Default | What it sets |
|---|---|---|
| `heave` | 1.0 | Heave length multiplier (1.25 s at 1) |
| `heave_step` | unit × 0.72 | Metres per heave (±15 %) |
| `rest_min` / `rest_max` | 0.3 / 0.95 s | Rest after a heave |
| `false_start` | 0.18 | Share of heaves that sag and get nowhere |
| `pant_every` / `pant` | 4 / 1.6 s | A longer rest every few heaves |
| `notch` / `pivot` | 0.32 rad / 1.0 | One notch of a turn, and its length multiplier (0.6 s) |
| `climb` / `drop` / `slope` | unit × 0.4 / unit × 0.75 / 0.42 rad | What it can heave up, down, and the steepest it rests on |
| `notice_rest` / `track_rest` | 0.2 / 0.55 s | Rest between notches when noticing and when drawing |
| `shove_out` / `shove_up` | unit × 2.2 / × 0.5 | The lurch's shove |
| `call_r` / `call_every` / `call_hold` | unit × 15 / 3 s / 4 s | Its calls |
| `dazed` / `stone_skid` | 2.4 s / unit × 7 | After a fall; how fast a skid stops (m/s²) |

Gone: `hover`, `hover_low`, `bob`, `bob_rate`, `tilt`, `settle`,
`drift_speed`, `drift_accel`, `turn`, `lock_turn`, `track_turn`. The pull
knobs are round 1's, with the new defaults above. The key poses are the
`HEAVE`, `SAG` and `PIVOT` tables at the top of the script.

## Captures

The captures are gitignored (`captures/head-scoot/`, in the worktree).
They were rendered in game through the study's own loop at 60 fps with a
fixed camera:

| Sheet | What it shows |
|---|---|
| `sheet_heave_r3_close.png` | One heave, 3/4 front |
| `sheet_pivot_r3.png` | A turn in notches |
| `sheet_inhale_r2.png` | Tell, inhale, gulp, blast and after |
| `sheet_fall_r3.png` | Shoved off the east rim |

The frames are in `r1/`, `r2/` and `r3/`. `r1` was before the heave's
pitch went from 0.15 to 0.2 rad.

What I judged by eye:

- **The heave reads.** It rocks back to show its chin, holds, then tips
  hard onto its chin with a dust skirt and settles. It looks like a stone
  block being rocked, which is the pathetic bit. At gameplay distance the
  rock-back is the clearest beat.
- **The tell reads well.** With the jaw planted, opening the mouth rears
  the whole head back, so it gapes up at you with lit eyes. The inhale's
  streaks come from about a metre off the turf.
- **The pivot reads** as lifts and drops, not a spin.
- **The fall works** but was framed badly. It tips over the lip and
  tumbles out of view.
- **Rough edges:**
  - The sag (the false start) is subtle from a distance.
  - The squash on a 3.4 m stone is small by design (0.88). A heavier
    camera shake on the thud would sell the weight more.

## Verified (headless, Godot 4.7.2)

- **Smoke check: passes.** A headless import was clean. Then each of these
  loaded with no script errors:
  - `inhaler_isle` for 900 frames
  - `headless_body_isle` for 400 frames
  - `run_layer` (sprawl 2) for 600 frames
- **Throwaway checks** (uncommitted, `scratch_scoot/`). Each ran through
  the study's own `tick`, with real physics and rays.

  - **Round on the turf, with a ramp, a platform and a step**
    (`check_scoot.gd` A, 240 s). It heaved 62 times, notched 49 times and
    balked 12 times, with no falls.
    - It went up a 10° ramp, tilting 0.17 rad to the slope, and onto a
      1.74 m platform.
    - It went down a 0.34 m step. It refused the 1.4 m drop off the step,
      turned, and went back down the ramp.
    - Its middle was never more than 0.17 m over the floor under it. That
      worst case was while straddling the step's edge, resting on the lip.
      On flat turf and the ramp the gap was 0.00-0.04 m.
  - **Inhale** (`check_scoot.gd` B and C):

    | Case | Result |
    |---|---|
    | Stand 5 m at its face | Tell 1.8 s, then inhale. Dragged in 1.5 s, gulped, blasted out about 15 m |
    | Run away from 4 m once it inhales | Escapes |
    | Walk away from 3 m | Gulped |
    | Stand still at 7 m | Gulped (slowly) |

  - **Shoved off the rim** (`check_scoot.gd` D). A shove of 8 m/s at 2 m
    from the rim slid it over. It fell and was gone below. A weaker shove
    (4 m/s) skidded it 1 m and it stayed.
  - **The body picks it up** (`check_body.gd`, the body study with
    `--body-start=stand`, the head set down on isle A).
    - The body homed in at 2.2 s and reached at 6.1 s (the head perched).
    - It was whole at 8.4 s and triumphed.
    - The head rode the neck seat (y 6.6 m).
  - **The generator.**
    - `count_heads.gd`: sprawl and ring, seeds 1-10, laid 24 heads, at
      least one per seed, each with 2-10 body cliffs.
    - `check_layer.gd` on sprawl 2, 90 s: head 1 heaved 34 times, notched
      20 times and balked 3 times, with no falls.
    - Head 0 never found turf under it in 90 s, so it waited where it was
      set down. Its isle's stone wasn't stood in near the start, I think
      round 10's far isles. A head now waits for turf before it can fall
      (`_settled`). Before that fix, both heads fell through at the start.

## Not verified

- I didn't play it interactively, and I didn't hear the sounds. They are
  synth placeholders.
- The sail and the plane in its (now lower) air.
- Riding its crown through a heave.
- The `calling()` hook isn't used by the body yet.
- How it reads at the generator's distances, and with two heads on screen.
- Whether a generated head on a far isle settles once you get near. The
  head waits until turf turns up under it. I didn't walk there.
- Head placement against round 9's numbers. Rounds now need turf all
  round the head's foot, so some spots that used to fit (partly over the
  void) no longer do. I didn't compare old and new counts seed by seed.

## Body-side asks (not made: `headless_body.gd` is another agent's)

1. **Hear its calls.** In `_pick_way`, while `head.calling()` is true,
   widen `hear` and shrink `noise` (for example, half the noise). Then
   staying near the head hastens the reunion. Nothing on the body breaks
   without this.
2. **Pick-up height.** `_seat_from = head.position` is now on the turf (it
   was 1.2 m up), so the arc onto the neck starts at the ground. It looks
   right in the check. No change is needed unless the reach clip's hands
   should meet it lower.

## Existing tests

No test in `tests/` references the head, `layer_enemies` heads or the
studies' voice tables (I grepped for `inhaler_head`, `InhalerHead` and
`heads`). `tests/test_run_layer.gd` and `tests/test_layer_sprawl.gd` plan
layers, so a head's placement can differ now, but I don't know of any
assertion on it. I didn't run them or the full suite, as prototyping
rules say.

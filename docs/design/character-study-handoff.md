# Character study handoff

Branch `study/character`. A greybox room for playing the pilot on foot,
reading his numbers and tuning his feel. Moves are unchanged this round.

## Launch

    ./run-character-study.command
    godot --path . res://studies/character_study.tscn -- --no-title

The room is walkable about 1.0 to 1.4 s after launch. Keys: WASD/stick run,
Space/A jump, mouse/right stick look, 1-8 teleport to a station, R back to
start, F1 toggles the numbers, F2 opens the feel panel (Print copies the
set as `const` lines; Defaults restores), Esc releases the mouse and a click
captures it again.

Test: `python3 tools/run_tests.py --tests test_character_study.gd`.

## Stations (studies/character_study.gd `STATIONS`)

Grey is structure, orange caps mark lips you can hang from, green is a
landing pad, blue is water. Every face has a 1 m grid with a stronger line
every 5 m. To add a station, add an entry to `STATIONS` built from parts
(`box`, `cyl`, `ramp`, `hole`, `water`, `ticks`, `label`).

1. **Run lane**: 30 m with a tick every metre and a label every 5 m.
2. **Step ladder**: 0.25, 0.45 (STEP_UP), 0.6, 0.8, 1.1, 1.55, 2.0 and 2.4 m.
3. **Gap jumps**: a 1.2 m deck with pads across gaps of 1 to 4 m in 0.5 m
   steps. An upper 2.4 m deck has gaps of 2.5, 3.5 and 4.5 m down onto
   1.2 m pads.
4. **Ledge wall**: a 2.0 m L-shaped block (straight lips, outside corners,
   an inside corner) with a stair up, and a curved 2.0 m lip (a cylinder).
   There is a 3 m pit with 0.3 and 0.6 m beams across it, flush with the
   floor, and a stair out. Catch walls stand at 1.7, 2.1, 2.5 and 3.0 m.
5. **Slopes**: 15, 30, 45 and 60 degree ramps up to a 2 m platform.
6. **Pool**: a 10 degree beach from wading down to 1.3 m deep. Its exits
   are banks 0.15, 0.5 and 0.9 m over the water, and a 0.3 m rim.
7. **Collision bits**: weaving pillars; doorways with 1.6, 1.2 and 1.0 m
   clearance (the 1.0 m one is too low to pass); a low bridge with 1.4 m of
   clearance under it, a deck at 1.7 m and a ramp at each end.
8. **Tower**: 6 m tall, reached by blocks that rise 0.9, +1.5, +0.9, +1.3
   and +1.4 m, so the climb mixes jumps and ledge grabs.

## Reuse vs standalone

I built a **lean standalone controller** instead of driving
`wanderer_eye.gd`. The walker is tied to the cozy_worlds scene: its orbit
fields, `editor`, the terrain and data, the flow water, sky islands and
planes. Even the perch path writes into `scene`.

The study still uses the game's own parts: the `PilotMotor` itself (not a
copy), `PilotFigure`, `WandererSteps`, `PilotPuffs` and `PilotRipples`. Its
event wiring for jumps, landings, footfalls, skids and water mirrors the
walker's. The camera copies the walker's constants and `_frame_walker`
logic: 7 m distance, about 40 degrees down, a 1.4 Hz critically damped
follow, swinging behind the run when left alone. The only change is that
it pulls in on a physics ray instead of a terrain height. The study does
**not** use PilotWake (there is no foliage).

**Caveat:** the camera constants are copies. If you change them in
wanderer_eye, change them here too, or move them to a shared place.

## Physics bridge (scripts/pilot_physics_ground.gd)

The bridge answers the motor's callables from colliders, so the motor
itself is not rewritten:

- **ground(p)**: a ray straight down from `feet.y + STEP_UP + 0.05`. If the
  ray starts inside a solid (`hit_from_inside`), it returns that solid's
  top, found by a second ray from 3 m above the feet. If the top is higher
  than that, it returns the ray's start, which the motor already treats as
  a wall. Nothing within 80 m below gives -INF. This lets him walk under a
  bridge and stand on it.
- **slide(feet, step)**: casts a cylinder 0.28 m in radius from 0.5 m to
  1.12 m above the feet, and slides along what it hits, up to 3 passes with
  a 1 cm skin. Anything lower than 0.5 m is the ground's job (step up, or
  the motor's wall check). If the body starts inside something, it can move
  out but not further in.
- **ledge**: `PilotLedge.find`, using the same rays cast from just above
  the height hint.
- **water**: a list of flat pools `{rect, top}`. Depth is `top - ground(p)`.
- **head(delta)**: called before each step. If he is rising, it casts a
  thin disc up from his head and zeroes `velocity.y` when it hits. Jumping
  under the low bridge stops him about 0.2 m up.

Limits:

- **Ground and slide disagree.** Ground is a single ray at the centre of
  the feet, while the body is a cylinder. He can stand with his centre just
  on a ledge while half his body hangs over it, and edges are sharp
  single-point tests.
- **No slope limit.** Any slope the body band doesn't hit can be walked up
  at full speed (see below).
- **Gaps under the body are ignored.** The body band starts 0.5 m up, so
  anything thinner or lower than that is ignored by the slide.
- **Simple water.** Pools are flat rectangles: no flowing or sloped water.
- **Head check is minimal.** It runs only when rising and not on a ledge
  or swimming. It does not stop a ledge climb into a low ceiling.
- **Moving geometry is not supported.** There are no moving platforms and
  the frame is not carried.
- **Not used in the game.** Castles and churches can use the bridge by
  passing their space to `PhysicsGround.new(space, motor)`, but the plate
  terrain still uses the heightfield. Mixing the two (terrain heightfield
  plus building colliders) is the next step.

## Live tuning

`pilot_motor.gd` now has per-instance vars (`walk`, `run`, `accel`, `brake`,
`air_accel`, `turn`, `turn_run`, `air_turn`, `gravity`, `fall`, `cut`,
`terminal`, `jumps`, `skid_speed`, `skid_brake`, `coyote`, `buffer`,
`chain_window`), each starting at its constant. Only the step logic reads
them. The constants are unchanged, so the game's behaviour is identical,
and `PilotMotor.RUN` and the others still work for other scripts. The
motor, water and ledge tests pass. The game's walker still passes `RUN` as
`top`, so tuning `run` only affects the study (which passes `motor.run`).

## What I noticed about the feel

I measured these headless at 60 fps, driving the motor through the room.

- **Jumps come out about 6% low.** A held jump 1 peaks at 0.75 m instead of
  0.8, jump 2 at 1.04 (not 1.1) and jump 3 at 1.48 (not 1.55). This is the
  explicit Euler step: the motor's jumps run a frame's worth short and
  depend on frame rate.
- **Reach at a full run** (held, landing level): jump 1 goes 1.80 m in
  0.43 s, jump 2 2.07 m, jump 3 2.47 m. With a 6-frame tap, jump 1 peaks at
  0.56 m and reaches 1.27 m; a 1-frame tap peaks at 0.30 m and reaches
  0.87 m. The chain adds height but little distance.
- **Gaps**: jump 1 clears 1.0 and 1.5 m. At 2.0 and 2.5 m he falls short
  and catches the far pad's lip, which feels good. 3 m and more are
  impossible from the 1.2 m deck, so **4 m is out of reach of any jump**.
  The chain doesn't help in practice: `CHAIN_WINDOW` is 0.22 s, so the
  third jump has to start within 0.22 s of the second landing, right at
  the edge. Going down 1.2 m, a 2.5 m gap is only caught by the lip, and
  3.5 m is missed. **A long jump is clearly the missing tool.**
- **Running off an edge** carries him 1.24 m before he lands 1.2 m below.
  Coyote time works: a jump 6 frames (0.1 s) after leaving the edge still
  fires; 8 frames does not.
- **Run, stop and skid**: full run (4 m/s) in 0.30 s over 0.66 m; a stop
  takes 0.23 s and 0.41 m. Reversing at a run skids for 0.27 s and reaches
  full speed the other way after 0.55 s. Everything is very snappy; the
  stop barely reads.
- **Slopes have no effect.** He runs up and down 15, 30 and 45 degrees at
  a constant 4.0 m/s with no slowdown and no lean. At 60 degrees he
  stalls about 1.4 m up, where the body cylinder meets the slope, rather
  than by a rule. Running down, he stays glued to the ground and never
  goes airborne. A slope limit (slow down, then slide back) would read
  better.
- **Climbing out of the pool depends on holding jump.** A tapped hop
  (4 frames held) gets him out of no bank at all, because releasing jump
  applies CUT to the hop as well and it peaks about 0.45 m up. Held, the
  hop clears 0.15, 0.3 and 0.5 m banks; 0.9 m traps him (no grab over deep
  water, by design: `_deep_under`). Making the hop ignore CUT is probably
  the single cheapest feel fix.
- **Ledges**: walking slowly off the pit edge lowers him into a hang
  cleanly. From a stand, jump 1 catches the 1.7 m wall, but 2.1 m and up
  are out of reach from a stand because the chain needs running pace.
- **Walls**: he stops dead square-on, slides along them at an angle, and
  doesn't stick. 0.45 m steps up cleanly; 0.6 m blocks him.

I could only take a few windowed stills to check the room reads (it does).
I didn't play it by hand, so judge these by playing. The numbers above
come from scripted input.

## Suggested next steps

1. **Long jump**: for example, crouch or skid while running then jump, or
   jump at full run with a second button. Aim for 3.5 to 4 m. The gap
   station is ready to tune it against.
2. **Frame-rate-independent jump arc**: use semi-implicit or analytic
   integration so JUMPS are the real peaks at any fps.
3. **Hop out of water** that ignores CUT, or an assisted climb onto banks
   up to about 0.9 m.
4. **Slope response**: slow down going up past about 30 degrees, slide
   back past about 50 degrees, and lean the body.
5. **Bridge improvements**: a ground probe over the whole footprint, edge
   wobble or a lean when the centre is over the lip, a head check during
   climbs, and moving platforms. Then hook the bridge into
   wanderer_eye for building colliders on top of the terrain heightfield.
6. **Shared camera constants** between wanderer_eye and the study.
7. A longer chain window, or chaining that doesn't need running pace, is
   worth trying with the F2 panel.

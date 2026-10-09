# Character study handoff

Branches: `study/character` (round 1: the greybox room, the physics bridge,
live feel tuning) and `study/character-moves` (round 2: faster, the pump,
the long jump, wall slide and wall jump, exact jump arcs, every grabbable lip
climbable). Round 2 is described first; round 1's notes follow, with the
numbers that changed marked.

## Launch

    ./run-character-study.command
    godot --path . res://studies/character_study.tscn -- --no-title

The room is walkable about 1.0 to 1.4 s after launch. Keys: WASD/stick run,
Space/A jump, Shift, C or LT crouch, mouse/right stick look, 1-9 teleport
to a station, R back to start, F1 toggles the numbers, F2 opens the feel
panel (Print copies the set as `const` lines; Defaults restores), Esc
releases the mouse and a click captures it again.

Tests: `python3 tools/run_tests.py --tests test_character_study.gd --tests
test_character_climb.gd --tests 'test_pilot_*.gd'`.

## Round 2: the moves

Try first: station 9 (the wall-jump shaft), then station 3 (long-jump the
3.0 and 3.5 m gaps), then the catch walls at station 4 with the pump.

### The moves, their inputs and numbers

All live in `scripts/pilot_motor.gd` (its header describes them) and reach
the game's walker, which drives the same motor.

- **Faster.** RUN 4.0 to 4.8 m/s, WALK 2.0 to 2.4 (ACCEL 17, SKID_SPEED
  3.4, SKID_BRAKE 15 and CATCH_PACE 2.6 scaled with it; WADE_SLOW 0.67 keeps
  the chest-deep wading pace at 1.6 m/s, as before). Full speed in about
  0.28 s. The run clip was rebaked for 4.8 m/s (0.3 s cycle, stance 0.28),
  so the boots stay planted; the walk/run blend moved to 1.9 to 4.0 m/s.
  The camera is unchanged (its spring lags about 1.1 m at a run, inside its
  1.6 m cap).
- **Jump and pump** (Space/A). The jump is 0.8 m held. Jumped again within
  CHAIN_WINDOW 0.3 s of a landing, or pressed up to BUFFER 0.15 s before
  it, it is the pump: 1.5 m. Every timed jump after that is another pump.
  There is no third tier, no flip and no pace needed. The pump gets a
  bigger puff, a deeper squash and a stretch, and its own "yahoo" clip.
- **Exact arcs.** The air step integrates each part of the step under its
  own gravity in closed form (rising, then past the top falling), so 0.8
  and 1.5 m are the real peaks: measured 0.797/1.499 m at 30 fps,
  0.800/1.499 at 60 and 0.800/1.500 at 144 (round 1 measured 0.75 and 1.04).
- **Crouch** (new action `walk_crouch`: Shift or C, LT on the pad; B is
  taken on foot by "step out", so I used LT). Held on the ground he stops
  where he stands, sliding to a stop from a run at 7 m/s² (about 0.7 s
  from full speed); the stick doesn't turn him while he slides. A crouch
  at a stand then Jump is the plain jump.
- **Long jump**: crouch at a run (at least 3 m/s), then Jump. 0.6 m up,
  6.4 m/s along, its own gravity of 18 m/s² both ways, and letting go of
  the button doesn't cut it. It goes 3.31 m level. Onto a top level with
  the takeoff it goes about 3.9 m, because a landing steps up onto any top
  up to STEP_UP over the feet. So it crosses the 3.0 m gap from up to 0.6 m
  short of the edge, the 3.5 m gap from up to about 0.3 m short, and never
  the 4.0 m gap (he catches its far lip instead). F1 shows its level reach.
- **Wall slide**: in the air, against a wall at least WALL_TALL 1.2 m over
  the feet, the stick into it, not rising faster than 1.5 m/s and at least
  0.5 m off the ground. Taking hold catches the fall to 0.5 m/s, then he
  gathers at 8 m/s² up to WALL_SLIDE 1.8 m/s. He faces the wall, a hand on
  it. Letting go of the stick or pulling away for 0.12 s, the wall ending,
  or the ground arriving ends it.
- **Wall jump**: Jump on the wall, or within 0.1 s of touching one in the
  air (a Mario 64 kick without the slide). It goes 1.4 m up and 5.2 m/s
  out, he turns round, and the stick doesn't steer for WALL_LOCK 0.28 s.
  Arriving at the facing wall during the lock he takes hold even with the
  stick still pointing back, with an extra 0.12 s to turn it. In the 2.8 m
  shaft each kick gains about 1.27 m: kicks at 0.98, 2.21, 3.49 and 4.76 m,
  then he grabs the 6 m lip and climbs out. With no wall near, a press in
  the air still asks to fly (the game's plane takeoff).

### Walls in both worlds

The motor has an optional `wall` callable, `(feet, way, reach) -> the way
off a wall (x, z) or Vector2.ZERO`. The physics bridge supplies one
(`wall_callable`: two rays at 0.75 m and WALL_TALL along the way; the normal
comes from the chest hit). Where none is set, the motor uses
`PilotMotor.heightfield_wall`: ground more than WALL_TALL over the feet
WALL_PROBE 0.45 m ahead, with the way off it down the height gradient. The
game's walker sets no `wall`, so on the plate and on islets the walls are
the terrain's own cliffs. All existing call sites are unchanged; `crouch`
is a property set before `step`, as `water` is.

### What changed for the game's walker (scripts/wanderer_eye.gd)

- It reads `walk_crouch` (plate and islets) into `motor.crouch`, so it has
  the crouch and the long jump.
- It gets the new speeds, the pump, exact arcs, wall slides on cliffs taller
  than 1.2 m, wall kicks, and the climb fixes.
- `_motor_events`: the pump bursts a bigger ring of puffs, the long jump
  puffs back off the heels, a wall kick puffs off the wall, taking hold of a
  wall slaps and scrapes, and sliding sprays along it.
- The walk hints don't mention crouch yet (their pad versions live in
  PAD_HINTS). docs/gamepad.md has the new row, and its stale "L3 / Shift:
  run" row is gone (there is no `walk_run` action).
- `scripts/ruin_kit.gd` CHAIN_TOP is now the pump's reach: 1.5 + 0.825 +
  0.25 = 2.575 (was 2.625). WALL_HEIGHT 2.4 still sits under it, and
  test_ruin_kit passes. `scripts/cluster_solver.gd` checks rises against
  JUMPS[1], which is now 1.5 instead of 1.1 (more permissive; generated
  stones rise at most 0.85).

### Why some lips refused the climb (fixed)

I swept a grab along every orange lip in the study, 31 offsets each, both
still and drifting sideways. 143 grabs hung but couldn't climb. There were
three causes:

1. **Phantom lips on tall walls.** The bridge's ground answers a wall
   taller than its 3 m reach with the ray's start ("a wall", for the motor's
   step check). The lip finder read that as ground stepping up, so it found
   lips partway up the 6 m tower, next to the blocks at 1.87 and 3.48 m.
   He could hang there, and there was no top to climb onto. Now the bridge's
   ledge heights use `top_from`, which looks for a tall wall's real top
   from 40 m up.
2. **The stand point read from the hang.** `_climb` asked the ground at
   the stand point from the hanging feet. Under the low bridge's deck that
   ray started below the deck and saw the floor, so no climb ever started
   from the bridge's sides. `_stand_on` now holds the feet at the lip's
   height while it asks.
3. **Narrow tops.** CLIMB_IN 0.3 put the stand point on the far edge of the
   0.3 m beam. The lip finder also couldn't resolve a top narrower than its
   0.45 m sample ring, and the grab looked past the beam. Now the stand is
   CLIMB_IN in, or the middle of a narrower top (none under 0.15 m). The
   finder walks in nearer for the top, and the grab also looks at the
   hands' own reach.

And the rule now holds: `_grab` and `_catch` only take a lip that
`_stand_on` can stand him on (a top within 0.5 m, room for the body over
it). The sweep now shows 0 grabbed-but-unclimbable spots. Both beams can be
caught and climbed. `tests/test_character_climb.gd` grabs and climbs 33
lips: the step ladder, both decks, the L's straight lips, outside and inside
corners, three points on the curved lip, both beams, the pit's rim, the four
catch walls and a corner of one, both sides of the bridge, the tower's
blocks, two faces of its top, and the shaft's lip.

### Animation

Blender was available (`/opt/homebrew/bin/blender -b --python
art/blender/pilot/pilot_build.py`), so the poses are real clips on the
existing rig, with the proportions unchanged:

- `crouch` (1 s loop): low on wide knees, leaning in, head up, breathing.
- `long_jump` (0.5 s loop): a flat superman dive, arms out ahead, legs
  trailing, toes pointed, scarf streaming.
- `wall_slide` (0.5 s loop): side-on to the wall, the right mitt flat on
  it, boots braced on it, the left arm out, looking down over the shoulder,
  juddering, scarf blown up.
- `wall_kick` (0.4 s, once): gathered against the wall, then legs driving
  off it and arms flung up, then spread.
- `pump` (0.5 s, once): a gather, then the right fist punched up and out,
  the right knee up, then both arms up and wide.

`pilot_figure.gd` blends each over everything by `motor.move`, fading in
over 0.07 s and out over 0.15 s. Each move kicks the springs as it starts,
so it overshoots and settles: the pump's dip and stretch, the crouch's
squash (and a pop on rising), the long jump's tip forward (plus a held
lean), the slap of taking hold of a wall, and the stretch of a kick while
the yaw spring whips him round. `pilot_preview.py` renders the new clips
(the wall slide against a wall). `tools/capture_character_moves.gd` takes
stills of each in the study (windowed, `--no-title`).

### Tests (all headless, all passing)

- `tests/test_pilot_moves.gd` (new): the jump and pump heights at 30, 60
  and 144 fps; the pump window (on the landing, 0.25 s after it and in the
  buffer before it give the pump; 0.45 s after gives a plain jump); 1, 2, 2,
  2, 2 with no third tier; the crouch slide; the long jump's height and
  reach, and gaps of 3.0 and 3.5 m crossed but not 4.0; the wall slide's
  speed cap, letting go, landing, and no slide on a short wall; the wall
  jump's height, way and lock; climbing a shaft by kicks. This is all on a
  heightfield, the game's way.
- `tests/test_character_climb.gd` (new): every orange lip caught and
  climbed, as listed above.
- `tests/test_character_study.gd`: the jump's peak is exact (to 0.01 m);
  the long jump crosses 3.5 m and falls short at 4.0; kicks up the shaft
  reach the lip.
- `tests/test_pilot_motor.gd`: the chain expects 1, 2, 2 and a higher
  pump in place of 1, 2, 3 with a flip.

### Remaining limits

- A plain jump still has no clip: the stride freezes in the air (only the
  pump, the long jump and the kick have poses).
- Wall slides on heightfield terrain take any rise over 1.2 m within 0.45 m
  as a wall, so steep carved cliffs in the game can be slid down and kicked
  from. That's probably fun, but I didn't try it in the game.
- Wall contact in the bridge is two thin rays. A narrow pillar between them
  or an overhang can be missed.
- The long jump's horizontal speed is fixed (6.4 m/s) rather than scaled
  from the run, so it's predictable but can't be stretched.
- The pump needs no pace. Jumping in place twice gives 1.5 m, so the
  2.1 m and 2.5 m catch walls are reachable from a stand.
- The crouch has no crawl, and there is no backflip from a crouch at a
  stand.
- The game's walk hints don't mention crouch or the long jump.
- I took only a few stills; nothing was played by hand. Judge the timing
  (CHAIN_WINDOW, WALL_LET, WALL_LOCK) by playing. All of them, and the long
  and wall numbers, are on the F2 panel.

## Round 1 notes

## Stations (studies/character_study.gd `STATIONS`)

Grey is structure, orange caps mark lips you can hang from, green is a
landing pad, blue is water. Every face has a 1 m grid with a stronger line
every 5 m. To add a station, add an entry to `STATIONS` built from parts
(`box`, `cyl`, `ramp`, `hole`, `water`, `ticks`, `label`).

1. **Run lane**: 30 m with a tick every metre and a label every 5 m.
2. **Step ladder**: 0.25, 0.45 (STEP_UP), 0.6, 0.8, 1.1, 1.5 (the pump),
   2.0 and 2.4 m.
3. **Gap jumps**: a 1.2 m deck with pads across gaps of 1 to 4 m in 0.5 m
   steps. An upper 2.4 m deck has gaps of 2.5, 3.5 and 4.5 m down onto
   1.2 m pads.
4. **Ledge wall**: a 2.0 m L-shaped block (straight lips, outside corners,
   an inside corner) with a stair up, and a curved 2.0 m lip (a cylinder).
   There is a 3 m pit with 0.3 and 0.6 m beams across it, flush with the
   floor, and a stair out. Catch walls stand at 1.7 (the jump), 2.1 and 2.5
   (the pump) and 3.0 m.
5. **Slopes**: 15, 30, 45 and 60 degree ramps up to a 2 m platform.
6. **Pool**: a 10 degree beach from wading down to 1.3 m deep. Its exits
   are banks 0.15, 0.5 and 0.9 m over the water, and a 0.3 m rim.
7. **Collision bits**: weaving pillars; doorways with 1.6, 1.2 and 1.0 m
   clearance (the 1.0 m one is too low to pass); a low bridge with 1.4 m of
   clearance under it, a deck at 1.7 m and a ramp at each end.
8. **Tower**: 6 m tall, reached by blocks that rise 0.9, +1.5, +0.9, +1.3
   and +1.4 m, so the climb mixes jumps and ledge grabs.
9. **Wall-jump shaft** (round 2): two walls 2.8 m apart, 6 m (west, an
   orange lip with a 3 m deck behind it) and 6.5 m (east) tall, open at
   both ends.

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

## What I noticed about the feel (round 1, before the moves)

These numbers are from round 1. Round 2 changed the run (4.8 m/s), the
jumps (exact 0.8/1.5 m, no third jump), the chain window (0.3 s) and the
climbs. The rest still holds.

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

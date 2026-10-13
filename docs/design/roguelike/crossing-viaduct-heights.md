# Broken Viaduct: heights, the sail out of a knock, updrafts

Branch `feature/viaduct-heights`, cut from `feature/viaduct-arrows` (71e9598e). Not merged.
The skill line is unchanged: the same beats, gaps and rises. Only the world under it and
around it changed.

## Run it

    ./run-crossing-yard.command                 # windowed
    ./run-crossing-yard.command --beat=2        # start at the piers
    godot --path . res://studies/crossing_yard.tscn -- --no-title [--beat=n] [--arrows=0]

Keys are as before: **R** start rim · **1-5** beats · **K** arrows on/off · **N** next
crossing. New ones:

- **Space while knocked**, once 0.35 s have passed: opens the sail.
- **WASD under the sail**: steer into an updraft's swirl.
- **Shift/C**: float.

The foot card now shows `falls N`. While you are knocked or under the sail, it also shows
a line with these keys.

## Height

- `crossing_viaduct.gd DROP` = **100 m** from the walk top (the start rim) down to the
  void's floor. The yard puts the void's floor at the isle datum (`TOP`, y 30), so the
  start rim stands at y 130 over the aqueduct isle's cloud sea.
- The stone (piers, spans, stair, perches) reaches `ROOTS` = **26 m** under the walk top.
  There it ends, broken off over the sky.
- The soft floor, the aqueduct head beside the start rim and the fallen stones on the floor
  are gone.
- **Death:** falling past the void's floor (`study.kill_y`) counts a fall and fades from
  near-black over `FALL_FADE` 0.8 s. A toast reads "Fallen into the void: back to the
  start rim · falls N". You are placed on the crossing's start rim, even if you started from
  a practice beat.
- The camera and sky read fine at this height. The captures show the cloud sea far below and
  the piers hanging over it.

## The sail out of a knock (the motor knob)

`scripts/pilot_motor.gd` has one new knob, `var knock_sail := -1.0`. It is the number of
seconds after a knock into the air from which Jump opens the sail out of the tumble.

- **Below 0 (the default):** never. The poise rule works as before, so every other scene is
  unchanged.
- **The only code change:** a guard at the top of the `move == "tumble"` branch in `step()`.
  It fires when all of these hold:
  - the knob is ≥ 0;
  - Jump is freshly pressed;
  - he is in the air;
  - `_stun_t >= knock_sail`;
  - `sail.can_open(...)` is true.
- **What it does:** it clears the tumble (`move`/`stunned`/`_hit_down`, the same as the
  poise branch, and emits `poised`). The existing sail-open branch then opens the sail in
  the same step, as from any fall: kicked once, gliding on the throw's way. A gust arrow's
  hard hit (`_poise = INF`) can be sailed out of too.
- **The yard sets it:** `crossing_yard.gd KNOCK_SAIL` = **0.35 s**. A press inside that
  opens nothing. If you never press, you fall to your death.

## Updrafts

They reuse the sky's thermals: `scripts/sky_currents.gd` `add_thermal`, its `air_at` lift and
its spiralling ribbons. No new lift physics. The pocket sail already climbs in a thermal
(`PocketSail.THERMAL*`). The yard combines the game's air with the updrafts' air in
`motor.air`.

The crossing lists them in `updrafts()` (a new optional hook on `crossing.gd`). Each rises from
the void's floor to `UPDRAFT_OVER` (10 m) over the landing it serves, `UPDRAFT_RADIUS` 6 m
round. A ridden sail settles about 6 m under the top, so it hovers a few metres over the
landing and glides onto it.

| Name | Where (constant) | Takes you to |
|---|---|---|
| start rim | `UPDRAFT_START` (-12, 1): left of the run-up by the rim (the deck perch throws you left) | the start rim |
| turn platform, left | `UPDRAFT_TURN_LEFT`: 6 m along the piers, 11 m left | the turn platform / the piers' start |
| turn platform, right | `UPDRAFT_TURN_RIGHT`: 2 m along, 14 m right (past the safe stair) | the turn platform |

There is nothing near the chimney or the launch. Recovering costs you progress, not the run.

**Look:** the ribbons are made bolder than the sky's: `UPDRAFT_DRAWS` 4× the strokes (a second,
look-only SkyCurrents), opacity 0.75, width 2.2, glow 2.4. From the air they read as pale
swirling strokes. From the rim, looking out flat, they are faint.

## Knockback (gust_arrows.gd)

| | before | after |
|---|---|---|
| `AIR_OUT` (walker heights out) | 9.0 | **7.0** |
| `AIR_UP` (walker heights up) | 1.2 | **1.0** |
| `STUN_DOWN` (s) | 0.8 | **0.6** |

The standing shove (`PUSH`/`PUSH_UP`) is unchanged.

## Verified

**Headless**, `tests/test_crossing_viaduct_heights.gd`: 10/10. It runs the yard's own
`_process` frames, with the stick and Space as Input actions.

- The knob's default is off, and the yard turns it on.
- **Thrown by an arrow:** pumping up the piers, the left perch throws him mid-pump, and he
  tumbles. Space pressed at once opens nothing. After the beat, with him 15 m down, Space
  opens the sail (`move` sail, no stun).
- **Riding an updraft:** steered into the nearest updraft (the right one), he climbs from
  about -15.6 to +3.1 (about 19 m) while riding. Steered on, he lands back at the turn
  platform's edge. He never tumbles again.
- **No sail:** thrown again with Space never pressed, he falls past -100. The fall is counted
  and he stands on the start rim.

Also run:

- `test_crossing_viaduct.gd`: 0 failures.
- `test_crossing_viaduct_arrows.gd`: 9/9 OK. A throw now ends in the void, not on the floor.
- `test_pilot_stun.gd`: PASS.
- `test_stun_yard.gd`: 0 failures.
- Load check: clean, except one "1 resources still in use at exit" line at `--quit-after`.
  It is new with the updraft ribbons and looks harmless.
- The full suite was not run.

**In the window** (forward_plus, `-- --no-title`): I drove the same script through Input
actions (`captures/viaduct_heights/drive.gd`, throwaway, gitignored). The knock, the sail out
at 15 m down, the ride up (26.5 m) and the landing on the turn platform all played out. The
run was cut off before its last two captures (the fall reset). That reset was verified
headless only.

Captures are in `captures/viaduct_heights/` in the worktree (gitignored):

- `0_start_rim.png`: the height, with the cloud sea far below;
- `1_knock_hit.png`, `2_knock_tumbling.png`: the throw off the piers;
- `3_sail_open.png`, `3_sail_gliding.png`: the sail out, with the updraft's swirl below;
- `4_riding_000..450.png`: climbing in the updraft beside the stair's hanging stone;
- `5_landed_turn_platform.png`;
- `6_falling_over_updrafts.png`: the no-sail fall.

## Not verified / open

- **Feel at human timing:**
  - Is 0.35 s right?
  - Is 100 m too long a fall to sit through? (It is about 6-7 s at terminal speed.)
  - Are the updrafts easy enough to find?
- **The start-rim updraft** is not ridden in any test. Only the right turn updraft is.
- **The updraft swirl is faint from the rim** (seen side-on against the clouds). It reads well
  from above.
- **The camera passes under the hanging stone** when he is thrown close to it. The
  stair/plinth undersides are big dark greybox faces.
- **A ridden sail can drift over the low piers.** A player hovering by the turn platform
  could glide onto pier 2-3. The skill line itself is unchanged.

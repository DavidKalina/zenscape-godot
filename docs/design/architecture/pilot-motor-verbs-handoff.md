# PilotMotor verbs, air stack, pose: handoff

A refactor round that doesn't change behaviour. `scripts/pilot_motor.gd`
now has verbs that hold the rules its callers used to restate. The
roguelike layers push air onto a stack instead of saving and restoring
it. The figure (`scripts/pilot_figure.gd`) draws from a typed pose instead
of duck-typing a motor. No public var was removed or made private, and no
physics number or `step()` logic changed.

## Verbs (scripts/pilot_motor.gd)

- `mount(by, at, on_ground, towards := NAN, grip := false)`: sets `rider`
  to `by`, zeroes `velocity`, sets `grounded = on_ground` and `feet = at`,
  and sets `facing` unless `towards` is NAN. With `grip`, it also sets
  `chain = 0` and `skidding = false` and packs the sail. The rider sets the
  rest of its pose (hold, move) after the call.
- `dismount(at, v, stun_by = null)`: clears `rider`, sets
  `grounded = false` and `feet = at`, then calls `toss(v)`. When `stun_by`
  is given and he is tumbling, it calls `knock(v, stun_by)` instead (the
  cannon's spit).
- `release(by) -> bool`: clears `rider` only if it is `by`. Nothing else
  changes.
- `pose() -> PilotPose`: returns a fresh snapshot for the figure.

`step_away` already called `reset()`, which clears the rider, so its extra
`rider = null` line was dropped.

## Air stack

- `push_air(by, layer)`: `layer` is `func(p, here) -> Dictionary` and adds
  its own air to the air below it. Each owner has one layer. Pushing again
  replaces it and moves it to the top.
- `pop_air(by)`: removes that owner's layer wherever it sits in the stack,
  so layers can come off in any order.
- `air_at(p)`: returns `air` (the base, which studies still set outright),
  then applies each layer in push order. Layers whose owner has been freed
  are skipped. The sail now reads `air_at` instead of `air`.

Converted: `layer_greybox.gd`, `layer_hazards.gd` and `layer_enemies.gd`.
Their `_air_was` vars are gone. `layer_enemies`' `plane_air` wrap is
untouched (it belongs to the plane, and another agent is working there).

## Pose (scripts/pilot_pose.gd, RefCounted, preloaded as `PilotPose`)

Fields: feet, velocity, facing, grounded, skidding, move, hold, hold_t,
shimmy, lip, lip_out, swimming, wade, wall_out, carve, carving, knocks,
seized. Method: `speed()`. The defaults are the fallbacks the old duck
typing used.

`PilotFigure.drive(pose: PilotPose, delta)` and `soak(pose, delta)` are now
typed, and every `"x" in motor`, `.get()` and `has_method("seized")` check
is gone. The old `drive(motor)` was dropped. Callers pass `motor.pose()`:
character_study, kit_isle (only the walker line), wanderer_eye (only its
two drive calls and one soak call), tools/view_pilot and
tools/capture_wanderer_sheet. Stand-ins now keep a pose:

- `second_walker.puppet` is a PilotPose. Gravity comes from PilotMotor's
  constants, and its PhysicsGround is handed a throwaway motor.
- `FootTrail.pose(puppet: PilotPose, s)` is now typed.
- `lodestone_study`'s FakeMotor class was replaced by a PilotPose.
- ClayFigure's `drive` override follows the new signature.

## Sites converted vs left

Converted:

- cannon_field: operate, launch_self, catch_body and spit, plus step_away
  (now a plain reset)
- lidstack: the catch cannon's catch, fire and reset
- trap_ray `_grab`: mount with grip
- swing_rope `_take`: mount with grip, then sets hold "swing"
- items_move `_drop_rope`: release

Outside `motor.x =` assignments went from 133 to 98.

Left as they were, and why:

- **Riders' own per-step `ride()` bodies** (cannon, lidstack, rope
  `_place`) are the rider contract, setting feet and pace each step.
- **cannon `climb_in`/`climb_out`** only set feet.
- **cannon field `reset`** clears `rider` unconditionally. `release(self)`
  would behave differently when a rope holds him.
- **trap_ray `_apply_grip`** writes the hang and crouch pose each step. A
  candidate for a `hang_at(feet, facing, lip, lip_out, shimmy)` verb.
- **serpent_ride `_set_on_place`** is a study `place()` followed by
  velocity, facing and move. That pattern is "reset with a given pace", not
  a mount.
- **earth_mouths `_hold`** holds him without being a rider.
- **items_move picks** poke private `_hang_on`, `_climb` and `_snap`.
- **items_move cloak** sets `air_accel` and `_fall_top`.
- **kit_isle and lodestone** zero `velocity` and nudge feet on the rope
  bridge.
- **The studies' outright `motor.air = ...`** is the base air, which the
  stack keeps.

## Proof

- **Import and smoke.** The headless import is clean. These scenes all
  pass the smoke check: aqueduct_isle, zenscape, cannon_yard,
  greybox/lidstack, serpent_ride, trap_yard, stun_yard,
  strange_second_walker_yard, lodestone_study, interactables_yard,
  character_study, flight_study, motif_yard `--motif=lidstack`, run_layer
  `--seed=3 --shape=sprawl --knob=heads=2 --knob=viaduct=1` and run_layer
  `--seed=2 --knob=greybox=lidstack`. cozy_worlds fails with 3 errors on
  base too (a GUI `set_size` NaN, headless).
- **Play-loop traces.** `scratch/motor_trace.gd` (uncommitted) drives the
  real input path and logs each frame's feet, velocity, grounded, move,
  hold, rider and facing, plus the figure's tilt, pivot and skeleton-pose
  sums. Its scenarios:
  - cannon: walk, jump, operate, aim, step away, climb in, launch, then a
    ledge catch
  - rope: run, jump, catch, 240 frames of pumping, let go, fly
  - lidstack: knocked into the catch cannon, held, fired
  - ray: a run with jumps

  Branch against base (a worktree at c4472906): cannon, rope and lidstack
  are identical in every field, figure included. The ray run is identical
  in motor, tilt and pivot. Its skeleton sums differ in the first 12
  frames, but base against itself differs there too (the figure's
  startup idle seek). That run never got onto the ray, so trap_ray's
  `_grab` is unexercised in play.
- **Air stack.** `scratch/air_stack_check.gd` checks two layers against
  the old wrap chain over 200 points: they are equal. It also checks
  out-of-order pop, a freed owner and a base swapped under the layers. The
  run_layer air grid can't be compared exactly against base, because the
  heads' wind changes from one base run to the next.
- **Second Walker.** `scratch/walker_check.gd` drives past the Second
  Walker. It rises, walks the trail and sits after catching him, with the
  same states and 6 toks on base and branch.
- **Nearest tests, headless.** Covered: test_pilot_*, test_character_*,
  test_cannon, test_trap_*, test_serpent_*, test_foot_interactables,
  test_stun_yard, test_pocket_sail*, test_run_layer, test_layer_sprawl,
  test_lodestone_study, test_isle_lodestone, test_aqueduct_isle_sail,
  test_dragon_grip_stun, test_rope_bridge and test_rune_serpent. 8 of them
  fail on both base and branch with identical FAIL lines: character_recordings,
  layer_sprawl, pilot_tricks, run_layer, rune_serpent, serpent_hops,
  serpent_route and trap_seesaw. The trap tests' exit leak ("2 resources
  in use") shows up on base too.

## Tests this round touched

- `figure.drive(m, DT)` and `figure.soak(m, DT)` calls in 9 test files
  became `m.pose()`. This was mechanical.
- test_pilot_figure's fake `Motor` now extends pilot_pose.gd, keeping its
  `pace`-driven `speed()`, and is passed as is.

No assertions were changed. No existing test breaks.

## Harness gaps

- No ready way to get him onto a Sky Ray in a driver. A `--trap=ray`
  station that starts him on its back would cover `_grab`.
- The figure seeds its RNG at build (`_rng.randomize()`), and the idle
  clip seeks at random. A driver that compares figure poses must reseed
  `body._rng` each frame, and the first frames still differ run to run. A
  `--figure-seed=` flag would fix that.
- run_layer's head wind is not repeatable run to run, so air can't be
  diffed against base in that scene.

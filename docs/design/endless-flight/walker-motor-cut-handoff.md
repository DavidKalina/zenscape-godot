# The walker's motor cut: handoff

On 2026-10-25 the last of the walking character left the flight game. The
scope cut (`scope-cut-handoff.md`) had kept `scripts/pilot_motor.gd` only
because the ruin kit was sized by its numbers and a few gadgets pushed it.
Those numbers are now frozen in the kit, the gadgets no longer push a
walker, and the motor is gone. Everything removed is whole at the tag
`archive/before-the-cut`; `docs/archive.md` (The walking character) lists it.

## What changed

- **Frozen numbers.** The walker's constants the kit is sized by are
  copied, under the same names, into the files that use them, each with a
  comment pointing at the tag: `ruin_kit.gd` (`CLIMB_IN`, `HANG_DROP`,
  `GRAB_LOW`, giving `STAND`, `GRAB_TOP`, `CHAIN_TOP`), `ruin_kit_tower.gd`
  (`GRAVITY`, `WALL_JUMP`, `WALL_KICK`, `WALL_LOCK`, `WALL_PROBE`,
  `RADIUS`, `SKIN`: the kick statics), `ruin_kit_keel.gd` (`SLIDE_AUTO`),
  `ruin_kit_cloister.gd` (`WALKER_HEAD`), `ruin_kit_horn.gd` (`BALL`,
  `WALKER_HEAD`: the mouth's radius, from the dragon's air ball),
  `ruin_kit_torana.gd` (`ROPE_LENGTH`, `ROPE_KNOT`), `rope_bridge.gd`
  (`WALKER_RADIUS`, `WALKER_HEAD`), `cluster_stack.gd` (`STEP_UP`),
  `cluster_solver.gd` (`JUMPS_PUMP`). `ruin_kit_relic.gd` only preloaded
  the motor. Same names and the same expressions, so the values are the
  same to the bit.
- **Gadgets.** Nothing kept ever handed a gadget the walker, so their
  walker code was dead:
  - `wind_horn.gd` is dressing: the head turns, tells, kicks, slumps; the
    ward that watched him, the gust and the air ball went.
  - `keel_hung_stair.gd` still turns on a slam; it no longer carries or
    throws him. `scripts/shared/trap.gd` lost `motor`, `pilot()` and
    `run_up()`.
  - `slam.gd` is only the push its listeners hear (`GROUP`, `blast`,
    `share`, `way`, `decent`, the power, radius and strength by drop): the
    leaves, the floating slabs, the hung stair and the breakables hubs
    still answer it. The walker's dive and `updraft.gd` went.
  - The live swing rope (`scripts/shared/swing_rope.gd`) went; the torana
    keeps its rope sizes.
  - `bob_slab.gd`, `foot_slab.gd`: comments only (they never touched it).
- **Deleted.** `pilot_motor`, `pilot_figure`, `pilot_pose`,
  `pilot_physics_ground`, `pilot_ledge`, `pocket_sail`, `updraft`,
  `scripts/shared/gust.gd`, `gust_arrows.gd`, `swing_rope.gd`, and what
  only those reached: the dragon's `dragon_air_blast`, `dragon_cyclone`,
  `dragon_gale`, `dragon_breath`, `dragon_downwash` and
  `wind_kicked_blades`. Tests: `test_pilot_*` (7), `test_dragon_air_blast`,
  `test_dragon_cyclone`, `test_wind_horn` (the ward),
  `test_wind_kicked_blades`. Tools: `tools/view_pilot.gd`,
  `tools/harness/stations.gd`.
- **The gallery's scale figures** are `StandingPilot` (in
  `studies/ruin_kit_gallery.gd`): the pilot's model in his paint, idling.
  `assets/models/pilot.glb` and `pilot_paint.gd` stay for the cockpit pilot.
- **Tests kept, edited.** `test_ruin_kit.gd` checks the kit against the
  same frozen numbers. `test_landform_lake.gd` lost the walker's wade and
  swim; it keeps "the deep water isn't blocked".
- **The harness.** `drive.gd` lost `motor`, `walk_to`, `jump`,
  `stick_toward`, `yaw_follows_facing`, the scripted ticks, the routes and
  the enemy watch; "him" in a shot is now the study's `figure`, if it has
  one. Its index is regenerated (`drive.py --api --update`). `drive.py
  --api` was already broken by the cut (it listed the cut `chain.gd`); it
  works again. `tools/README.md` follows.
- **Docs.** AGENTS.md (the opening note, Sizes), `docs/archive.md`.
  `tests/test_world_scale_guard.gd` never named PilotMotor.

## Proof

Throwaway scripts in `scratch/walker_out/` (git-ignored, uncommitted).

- Every kit piece's geometry, hashed (mesh arrays, hull points, shapes,
  transforms, metas) for all 30 ids × seeds 1, 77, 4242 × weathered 0, 0.5,
  1, against a checkout of the cut (`cbba04dd`): all 270 identical, once
  two things that aren't shape are left out: the horn rig's two blow sounds
  (AudioStreamPlayer3D, gone with the ward) and the hung stair body's
  `moving_ground` meta (the walker's ride mark). The kit's constants are
  identical but for the frozen copies added; `STAND`, `GRAB_TOP`,
  `CHAIN_TOP`, the tower's `KICK_*`, the keel's `HUNG_STEEP` and the rope
  bridge's width and hand rope match to the bit (`kit_dump.gd`).
- The ruin kit gallery's own view and a close one of the gothic wall
  (its scale figure on top), before and after: the same stones; the figure
  stands where it did (`pier_sheet.png`).
- Smoke: endless flight (default, `--world=regions`, `--world=overgrown`),
  `flight_study`, `ruin_kit_gallery`: 0 errors.
- Every script, scene and shader loads: 560, 0 failures (`load_all.gd`).
- `python tools/land_hash.py --seed 1`: unchanged (exact
  `c515311f…ee32`, every spot of the dump the same).
- Tests run: `test_ruin_kit`, `test_ruin_growth`, `test_world_scale_guard`,
  `test_landform_lake`, `test_rope_bridge`: all pass. The full suite was
  not run. Tests broken by this round: none known (the removed ones went
  with their subjects).

## Left for later

- `scripts/pad.gd` still maps the walker's input actions (`walk_jump`,
  `walk_crouch`, `walk_twirl`, `walk_wind`, `walk_sneak`); some may drive
  the plane, so they were left.
- Comments in kept code still name the deleted files here and there
  (`islander_figure.gd`, `pilot_paint.gd` and its shader, `breeze_ribbons.gd`,
  `disturbance.gd`, `sky_plane.gd`, `layout_overrides.gd`,
  `aqueduct_isle_art.gd`, the bob and foot slabs' "his pump"). Harmless;
  tidy when next in those files.
- `tools/shot.py --frame walker` and `--place` now act only on a study
  with a `figure` or `place`; none of the kept scenes has one.
- `tools/reach_deps.gd` has no committed `.uid` (Godot makes one on import).

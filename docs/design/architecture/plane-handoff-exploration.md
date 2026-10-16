# Plane handoff: exploration (candidate 8, not built)

Read-only design exploration, 2026-10-15. Builds on the PilotMotor verbs
(`pilot-motor-verbs-handoff.md`) and SkyPlane verbs (`sky-plane-verbs-handoff.md`)
landing first.

## Verdict

Not a six-state `PilotModes` machine. Swim, hang and glide are already owned by
`PilotMotor`; taxi, roll, air and exit by `PlaneLanding` / `ManualLanding`. A
machine holding those names would mirror state that has an owner: a shallow
module with two sources of truth.

Instead: a **`PlaneHandoff`** transition module (foot ↔ plane, ride later),
plus a derived read-only `mode()` for readers (HUD, audio, birds).

The flags the review listed (`perch`, `glide_enabled`, `manual`) belong to
`scripts/wanderer_eye.gd`, not the game. On the game path they are `flying`,
`takeoff`, `parked`/`parked_at`/`parked_heading`, `off_edge`/`_stranded_left`,
`lode_state`, `scripted`/`_replay`, `hand_landing.phase`.

## Transitions on the game path (studies/kit_isle.gd unless noted)

| # | Transition | Trigger | Where | Touches |
|---|---|---|---|---|
| 1 | foot → plane-taxi | Space / pad A while `by_plane()` | 930 → `board_parked` 972 | arc gate, `_end_replay`, `_unpark`, new SkyPlane; launch then overwrite pose (985-991); `takeoff`, engine, `hand_landing.begin(plane,true)`, `_into_plane`, hop, figure, hint |
| 2 | foot → plane-air | `--fly`, `--fly-at`, aqueduct `--near-ring`, tests | `board` 948, `_start_in_plane` 510, aqueduct 415 | `_end_fall`, `_end_replay`, `_unpark`, SkyPlane ahead/above, 12-step stone escape, `takeoff=null`, `hand_landing.begin`, `_into_plane` |
| 2a | shared entry | | `_into_plane` 1008-1044, aqueduct 506 | plane figure, `ground_scale`, lodestone carried → seated + compass, chase camera, GlideAir, walker hidden, `flying=true`, 9 per-flight resets, hint; aqueduct quiets the nose |
| 3 | BOARD → taxi | hop finishes | `_takeoff_step` 1538 | `takeoff=null`, figure, `hand_landing.begin` |
| 4 | taxi/roll ↔ air | inside ManualLanding | `fly_step` 1438, `_wheel_events` 1553 | isle only reacts (words, shake, spray, lock) |
| 5 | stopped → exit | F / pad Y, `land_key` 1630 | 1592-1598 → `leave_plane` | hop, then 6 |
| 6 | plane → foot | 5, or R in plane (1937) | `leave_plane` 1057-1093 | wheels check, `flying=false`, `release_lock`, lodestone, nose, air stop, spray, `_park`/`park_home`, fov, hint, `place()`, `_last_stood` |
| 7 | plane → plane (moved) | captures, aqueduct tests | `fly_from` 1645, aqueduct 511/762 | relaunch, `hand_landing.begin`, chase; aqueduct `isle_chain.forget()` |
| 8 | foot → off edge → stranded → by plane | falling with nothing under | 2327/2346/2353/2359 | `off_edge`, `_stranded_left`, `place`, `_last_stood` |
| 9 | parked plane | `_ready` 500, `run_layer._world_plane`, `zenscape.gd` 69 | `_park`, `_unpark`, `park_home` | `parked*`, `_park_body`, figure pose |
| 10 | foot ↔ ride | `airship_ferry.gd` 556, `serpent_rider` | those scripts | isle's private `_cam_at`, `_last_stood`, `lost` |

Sharers: `run_layer.gd` 248-264 (gates on `plane_offered()`), `zenscape.gd`
69-91. `hall_rise`, `landing_study`, `hall_chain` are standalone copies with
their own `mode` string; leave them. `scene.get("flying")` readers: kit_audio,
kit_birds, kit_clouds, kit_life, watcher, airship_ferry, serpent_rider,
motif_isle, pause_host, dev_keys. `kit_audio._flying_was` is a hand-made
enter/exit hook.

Tests: `test_kit_isle_landing` (whole loop), `test_aqueduct_isle_plane`,
`test_isle_lodestone`, `test_isle_lock`, `test_plane_arc`, `test_kit_audio`,
`test_manual_landing_game`, `test_dev_keys`, `test_game_pause`,
`test_front_door`; slow: `test_isle_hall_chain`, `test_isle_loop_played`.
Tests read `study.parked_at`, `.takeoff`, `.flying`; keep them as forwarding
properties. (`test_hand_landing_exit` drives wanderer_eye, not the game.)

## Shapes considered

- **A. `PilotModes` state machine** (`mode`, `enter`, `entered` signal). Foot
  and taxi/air changes happen inside `motor.step` / `hand_landing.step`, so it
  would poll and mirror them. Shallow; reorders in-frame work. Feel risk
  medium-high.
- **B. `PlaneHandoff` (RefCounted), recommended.** Interface: `board_air(at,
  yaw)`, `board_parked()`, `leave(at)`, `relaunch(at, heading)`, `park(at,
  heading)`; read-only `vehicle/plane/takeoff/parked_at`; signals
  `boarded(kind)`, `left(on_wheels, spot)`, `relaunched`. Behind the seam:
  plane construction (one launch via SkyPlane `rest_on`/`set_pace`), takeoff,
  hand-landing begin, park/unpark, on-wheels decision, hop spot. Narrow isle
  adapter: `floor_at`, `takeoff_run`, `in_stone`, `hop_spot`, `safe_ground`,
  `place`. Lodestone, nose, GlideAir, hints, chase camera, fov stay in kit_isle
  as signal subscribers; aqueduct connects instead of overriding `_into_plane`
  / `fly_from`. Tested headless with a fake adapter (flat floor, edge at
  x=40). Feel risk low: same calls, same order.
- **C. Vehicle data table** (`VEHICLES[FOOT|PLANE|RIDE]` of step/input/camera/
  figure/sound). Touches all 46 `flying` branches at once; input-routing risk.
  Borrow only its derived `mode()`.

## Steps, smallest first

1. Characterize: throwaway `scratch/` driver dumping ~25 fields after each
   transition (1, 2, 3, 5, 6 wheels and air, 7, 8); diff after every step.
2. Fold the three plane launches (`board`, `board_parked`, `fly_from`) into
   one `_launch_plane(at, heading, pace, on_wheels)` in kit_isle using the
   SkyPlane verbs. No new file. Small, one round.
3. Extract `PlaneHandoff` owning plane/takeoff/parked; kit_isle forwards
   `flying`, `parked`, `parked_at`, `takeoff`, `plane` via getters/setters.
4. Split `_into_plane` / `leave_plane` into handoff core + `boarded`/`left`
   subscribers; aqueduct overrides become connections. Steps 3-4: medium, two
   rounds.
5. Optional: `kit_audio._flying_was` onto the signal; `leave_plane`'s
   `place()` onto PilotMotor `dismount`/`teleport`.
6. Later: ferry and serpent as a RIDE vehicle using PilotMotor `mount`.

Needs play to judge: boarding the parked plane, taxiing off the edge into the
dip; land, brake, F, hop out; R in the air; `--near-ring` and the hall chain;
the camera handoff (chase from current eye, fov snap on leaving); board and
cool-down sounds.

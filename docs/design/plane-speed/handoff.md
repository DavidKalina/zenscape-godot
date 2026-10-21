# Plane speed: handoff

Branch `iter/plane-speed` (from `iter/takeoff-roll`). Prototype round, no
committed tests.

## Play it

`./run-heist.command` now flies as `--plane-speed=2 --plane-turn=1.15` did.
`--plane-speed=` and `--plane-turn=` still override; `--plane-speed=1` is the
bare toy (its turn follows the speed when only `--plane-speed=` is given).

## Values (`scripts/sky_plane.gd`)

| | old | new |
|---|---|---|
| GAME_SPEED | 1.15 | 2.0 (cruise 28 m/s; Boost asks 44 but FAST caps it at 30; Brake 16) |
| game turn rate | follows the speed (1.15) | GAME_TURN 1.15, its own const (`game_turn()`) |

A bare SkyPlane (flight study, benches) still flies and turns at 1.

## Measured (heist level, `--hunt-seed=3`, real input; scratch/speed/)

- **Round trip** (`trip.gd --flaps`): 12/12, banked. Out 63.4 s, back
  63.7 s (about 110 s each before). The autopilot's change: it puts the
  flaps down (F) 200 m out. Brake alone holds 16-17 m/s and floats about
  1 m over the turf. It floated off the end of the heist turf without
  touching, and that failed 6 of 12 checks.
- **Hand takeoff** (`roll.gd --case=a --to-cruise`): lifts on the pull at
  12.51 m/s, 6.47 s, 46.5 m (unchanged). With Boost held it reaches 28 m/s
  2.5 s after lift-off (16 to 24 m/s in 0.7 s, a hard surge as the unstick
  ends) and tops out at 30. With Boost let go at 2 s it reaches 27.5 m/s
  7.8 s after lift-off.
- **Plummet** (`--case=b`): off the end at 14.15 m/s. The late pull catches
  it 1.15 s after the edge at 20.5 m/s, and it is climbing at 2.0 s. It
  loses 28.5 m (27.5 before).
- **Home landing by hand** (`land.gd`, 150 m strip): flaps 200 m out gives a
  greaser at 5.8 m/s. Brake only gives a hot touch at 16.4 m/s, 43 m down the
  strip, which sticks and stops on the strip; holding a 1.2 m/s sink, hot at
  16.9 m/s, 20 m down. At 1.15 brake only gave a greaser at 9.7 m/s.
  TOUCH_FAST is 10.5, so at the new speed only flaps get a tidy touch.

Smoke, 0 errors: heist_level, aqueduct_isle, landing_study, hall_chain.

## Tests broken (all pass on iter/takeoff-roll)

- `test_sky_plane.gd` "Its turn radius stays the toy's" (15.1 m against
  8.7 m). That premise is what this round changed on purpose.
- `test_glide_camera.gd` "At boost the view widens" and "eases back". Boost
  is capped at FAST 30, only 1.07x the 28 cruise, below the camera's shares.
- `test_isle_hall_chain.gd`, 12 checks from "Then it stands in place" on.
  Braked from inside ring_near, the 16 m/s brake reaches the ring before
  it stands, and the later checks fail in a cascade. Its hitch check
  (36 ms frame) failed too. It may be knock-on, not checked.

## Possible next steps

- Camera: the chase camera reads speed against the plane's own cruise
  (`glide_camera.gd` FOV_SHARE/PULL_SHARE), so it gives no speed cue at the
  new cruise.
- FAST (30) is now barely over cruise, so Boost and dives add little. It may
  want scaling with the speed (not done: the user flew it capped).

## What the harness lacked

There is still no flying helper in drive.gd. The stick, throttle, flaps,
approach autopilot and touch logging are hand-rolled in scratch/speed/
(trip.gd, land.gd, roll.gd).

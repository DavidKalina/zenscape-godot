# Plane speed round

The user said the plane was too slow. Endless flight now flies about 1.8 times faster than before. The isles are unchanged: they still call `use_game_speed`.

## New numbers (scripts/sky_plane.gd `use_flight_speed`)

| | before (x1.15) | now (FLIGHT_SPEED 2.1) |
|---|---|---|
| cruise | 16.1 m/s | 29.4 m/s |
| boost | 25.3 | 46.2 |
| brake | 9.2 | 13.2 (FLIGHT_BRAKE 0.45 of cruise, never above the toy's scaled brake) |
| dive cap | 30 | 54.8 (FAST x FLIGHT_SPEED / GAME_SPEED) |
| turn rate | x1.15 | x1.3 (FLIGHT_TURN; full x2.1 would snap round), so turns are wider |

Landing, flap and stall speeds are the same as before (FLAP_SPEED 5.5, FLAP_SLOW 5, TOUCH_FAST 10.5).

## Speed feel (studies/endless_flight.gd)

- The chase camera already widened its view with speed against cruise. Endless flight now widens it RUSH_FOV (1.8) times as much: about 75 degrees at cruise, 82 at boost and 70 braking. `--cam-speed-fov=X` overrides it.
- Past 0.9 x cruise the eye gets a small wind buffet: three sines out of step, at most 0.26 degrees at boost speed, and none on the wheels. `--rush=X` scales it (0 turns it off).
- There are no speed lines, and no audio pitch: endless flight has no engine or wind sound yet.

## Knobs

`--plane-speed=X` (2.1; 1.15 gives the old feel), `--plane-turn=X`, `--cam-speed-fov=X`, `--rush=X`, `--land-lead=S` (0.9; 0 turns it off).

## Streaming

The land now plans its quadtree round a point led ahead of the eye: 0.9 s of level velocity, at most 48 m (`LandStream.lead_with`, LEAD_TIME and LEAD_MOST). The colliders still stay round the eye.

How it was measured: real-time headless drive at 60 fps, seed 1, 40 s at each speed. The figure is the share of frames where some ground in the view ahead (40 to 320 m) was drawn coarser than the detail the camera's distance calls for. Holes were never possible: a chunk still building is covered by its parent.

| | old speed | new, no lead | new, with lead |
|---|---|---|---|
| cruise | 5.5% | 5% | 0% |
| boost | 3% | 7% | 1% |

On seed 3 (60 s per leg, 4.7 km) it was 0% at boost.

The grass rings, spruce blocks within 250 m and arches kept up: the only grass gaps were in the first second after spawning, the same as before. Endless flight has no birds or traffic yet.

## Frame time

Rendered, 1440x900 window, RTX 4070 Super:

| | GPU per frame | worst frame |
|---|---|---|
| cruise | 9.2 ms | 30 ms (spawn settling) |
| boost | 7.8 ms | 13.4 ms |
| boost, low | 9.3 ms | 12.7 ms |

The land step's cost did not measurably change.

## Proof

- **Throwaway drivers (uncommitted):** `scratch/fly_fast.gd` flies cruise, boost and brake through the input actions, then does a hand landing (F flaps, brake held, stick glide path, flare). `scratch/fly_shots.gd` takes the rendered stills.
- **Flaps landing:** greaser at 5.4 m/s, stopped about 3 m later. The approach was set up 600 m out at cruise.
- **Brake-only landing:** touches "hot" at 13.2 m/s, slides and stops in 17 m.
- **Captures:** `captures/plane-speed/{cruise,boost,boost_low,brake}.png`.
- **Smoke:** endless flight, 0 errors.

## Tests

- **Pass:** test_sky_plane, test_glide_camera, test_manual_landing, test_knife_drift, test_flight_crash, test_kit_isle_landing, test_game_settings.
- **Fails:** test_aqueduct_isle_plane, at "R3 puts the camera back behind the pilot". It fails the same way on the code before this round, so this round did not cause it.
- The full suite was not run.

# Flight weight: presets off, light, medium, heavy

What changed
- `scripts/flight_weight.gd` (new) holds the four presets as knob tables (`PRESETS`), their order (`NAMES`), `DEFAULT` (medium) and the `--weight=` parser (`flag`).
- `scripts/sky_plane.gd` gets `use_weight(preset)`. A preset other than off (`weighted`) changes `step` in these ways:
  - Roll: the lean rides a critically damped spring (`_roll_spring`, `roll_hz`). The roll rate builds and settles with no overshoot. The turn rate follows the lean over `turn_lag` s. The drawn bank follows the lean over WEIGHT_BANK_EASE (0.03 s), so the model leans in before the path comes round. In off, the drawn bank still trails the turn by EASE_TURN.
  - Path: the travel direction is its own heading and pitch (`_weight_path`). The heading bends after the nose (with the drift's slip) over `yaw_lag` s, and the pitch over `pitch_lag` s. Both lags are times cruise/speed, clamped to LAG_SCALE 0.7 to 1.6. The result is a sink through the bottom of a pull-out, a wide swing on a late turn, and a small slip in hard turns (about 9° at a full medium turn). The stick builds the pitch rate over `pitch_build` s.
  - Speed: the load is `g_load` = 1 + speed × the path's turn rate / 9.8, and it bleeds `bleed` m/s² per g over one. Slow with the flaps up (from SLOW up to SLOW + SOFT_SPAN, 7 to 13 m/s), `soft` goes 0 to 1. The stick then keeps only `soft_keep` of its roll and pitch, and the plane mushes down `mush` m/s × soft. A bank sags it `sag` m/s × (1 − cos bank). There is no stall and no spin. Brake's 13.2 m/s sits just over the soft band, so a braked cruise stays crisp.
  - Read-outs: `g_load`, `aoa` (nose pitch minus path pitch) and `soft`.
  - Off runs the old code path (the `--heavy` prototype included). A bare SkyPlane defaults to off, so the flight study and the traffic don't change.
- `scripts/glide_camera.gd` gets `use_weight(knobs)`. The flight-way ease and the roll ease are × `cam_lag`. The way is `cam_path` the path's (the rest the nose's; the old even blend at 0.5). The FOV eases over `fov_ease` s.
- `scripts/endless/flight_rumble.gd` gets two new inputs:
  - A `strain` hum key on both motors (STRAIN 0.26 weak, STRAIN_STRONG 0.16 × strain² strong).
  - A `sink` knock (SINK + SINK_MORE × k), mostly on the strong motor and 0.35 to 0.5 s long.
- `studies/endless_flight.gd`:
  - Holds `weight` (`--weight=`, else medium) and applies it to the plane and the chase on every launch and respawn.
  - Cycles it with **V** or the pad's **d-pad up** (new action `fly_weight` in `scripts/pad.gd`). Each change shows "Weight: <name>" for 1.4 s, then fades it over 0.6 s.
  - Adds "V weight" to the hint line, and a weight line to the F1 numbers (preset, g, nose over path, soft).
  - Feeds the rumble a strain of smoothstep(1.3, 6.5, g_load).
  - `_feel_sink` knocks once when the nose is over 0.14 rad above the path while sinking faster than 3 m/s. It re-arms when the nose comes back within 0.05 rad.
- The landing's unstick (`scripts/manual_landing.gd` `_heavy`) sets the plane's velocity from outside every frame, which restarts the weighted path along the nose. So the takeoff reads as before under every preset, and the lag only starts once the unstick ends. Nothing in the landing was changed.

The knobs (`scripts/flight_weight.gd` PRESETS)

| knob | off | light | medium | heavy |
|---|---|---|---|---|
| roll_hz (rad/s) | – | 13 | 11 | 7 |
| turn_lag (s) | – | 0.04 | 0.06 | 0.12 |
| yaw_lag (s) | – | 0.05 | 0.08 | 0.13 |
| pitch_lag (s) | – | 0.18 | 0.30 | 0.48 |
| pitch_build (s) | – | 0.06 | 0.09 | 0.15 |
| bleed (m/s² per g) | – | 0.3 | 0.6 | 1.0 |
| soft_keep | 1 | 0.75 | 0.6 | 0.45 |
| mush (m/s) | – | 0.8 | 1.4 | 2.2 |
| sag (m/s) | – | 0.6 | 1.0 | 1.8 |
| cam_lag | 1 | 1.25 | 1.5 | 2.0 |
| cam_path | 0.5 | 0.56 | 0.62 | 0.7 |
| fov_ease (s) | 0.3 | 0.4 | 0.55 | 0.8 |

Measured (throwaway drive `scratch/weight.gd` through the real loop and stick, uncommitted; `python tools/drive.py scratch/weight.gd -- --label=X --scene-args --weight=X`)

| | off | light | medium | heavy |
|---|---|---|---|---|
| sink-through, full back from a 30° dive at cruise (m) | 2.72 | 5.38 | 6.75 | 8.66 |
| time to the bottom (s) | 0.38 | 0.60 | 0.72 | 0.88 |
| full stick to 90% of the held turn rate, path (s) | 0.38 | 0.42 | 0.55 | 0.93 |
| the same, nose (s) | 0.38 | 0.35 | 0.43 | 0.72 |
| speed lost over a 180° full-stick turn (m/s, from 29.4) | 0.0 | 1.5 | 2.9 | 4.2 |
| 180° turn time (s) | 1.67 | 1.73 | 1.82 | 2.05 |
| hands-off from a 30° bank: altitude drift (m) | 0.00 | 0.01 | 0.02 | 0.04 |
| hands-off settle (bank < 2°, \|vy\| < 0.25 for 0.5 s) (s) | 0.57 | 0.37 | 0.42 | 0.65 |
| braked climb: lowest speed (m/s) / most soft | 12.3 / 0 | 11.7 / 0.12 | 11.3 / 0.20 | 10.8 / 0.30 |
| hand landing on a flat (grade, speed, sink) | greaser 5.75, 0.67 | greaser 5.76, 0.67 | greaser 5.63, 0.66 | greaser 5.78, 0.67 |

- `off` gives exactly the same numbers as an unmodified build (run before the change).
- The held turn rate is 2.08 rad/s in every preset. Weight changes only the onset and the end of a turn.
- The landing is a scripted approach on the stick: flaps down, braked, 14 m up and 140 m out, tracking a sink target, onto the first flat run found near the spawn.
- Hands-off from a bank settles a little faster in light and medium than in off. Off's drawn bank trails its lean, and the weighted bank doesn't.

Proof
- Smoke: endless_flight (default medium, and `--weight=heavy`) and flight_study PASS.
- Cycling (`scratch/weight_cycle.gd`): starts on medium; V goes heavy, off, light, medium; d-pad up through `Input.parse_input_event` cycles; the chase picks up the knobs; the note shows.
- Rumble (`scratch/weight_rumble.gd`, the pad forced on): no pulses flying straight, about 20 pulses over a 1.5 s full turn (g up to 7), and the sink knock fires on the 30° pull-out at light and medium.
- Rendered (`scratch/weight_cap.gd --rendered`, stills in `scratch/weight_cap/`): a turn and a pull-out at medium next to off.
  - The plane stays in frame. The camera's roll and way trail a little more than in off.
  - At medium, on the pull-out, the nose comes up before the plane stops dropping in the view.

Not verified
- A real pad's rumble felt in the hand: the strain hum's level and the sink thrum.
- The feel in the hand: whether medium is ever late, and whether heavy's 0.9 s onset is too much. The user judges this by playing.
- The mouse turns the heading directly, as before, so with weight only the path lags it.
- Low-altitude flying, the skim and the near-miss window are untouched (the next round).

Tests this breaks (for the lock-in round)
- None found. `test_knife_drift`, `test_flight_study`, `test_flight_metrics` and `test_world_scale_guard` pass.
- `test_sky_plane` and `test_glide_camera` still stop at the removed scarf (`_scarf_points`), so their later checks didn't run.
  - A bare SkyPlane and GlideCamera default to the old behaviour (off, cam_lag 1, path share 0.5), so nothing they test should move.

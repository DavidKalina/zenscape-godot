# Pace: presets today, brisk, fast, and the look and sound of speed

Builds on `flight-weight-handoff.md`, `near-miss-handoff.md` and `flight-sound-handoff.md`.

What changed
- `scripts/flight_pace.gd` (new) holds the presets (`PRESETS`, `NAMES`), `DEFAULT` (brisk) and the `--pace=` parser (`flag`; a number such as `--pace=1.75` also works).
- `scripts/sky_plane.gd`:
  - `pace_scale` (1 by default) and `use_pace(scale)`. `cruise()`, `boost_speed()` and the new `top_speed()` (the dive's cap) are times it. The surge (SURGE_OVER × Boost) follows.
  - Brake is set from the unpaced cruise in `use_flight_speed`, so it stays 13.2 m/s. The floor, flaps, landing and touchdown speeds, the takeoff and the landing's 16 m/s grade are untouched.
  - The low zone's hands-off settling nose (`settle_pitch`) is divided by the pace, so it sinks as many m/s at any pace.
- `scripts/endless/near_miss.gd`: PULL_MIN and CLOSING_REF are times the pace (`_pace`), so a dive at the same angle grades the same at any pace.
- `scripts/endless/flight_sound.gd`: the air reads the speed against today's cruise (the plane's cruise over its pace), so a faster pace is louder and higher. Past the old full end (1.85 cruises, 54 m/s), a new `over` term (0 to 1 over AIR_OVER more shares) raises the rush and whistle pitch, adds whistle and opens the air's low-pass. The engine's pitch reads the same speed.
- `scripts/glide_camera.gd`: `close_in` and `close_down` (0 by default). From CLOSE_SHARE 1.5 to 3.0 cruises, the framed eye comes that share closer and lower.
- `scripts/endless/speed_streaks.gd` (new): a full-screen rect with one canvas shader. It draws faint, soft wind lines near the screen edges, flowing outward from the travel's point on screen, and stronger on the lower half near the land.
- `scripts/pad.gd`: a new action `fly_pace`, on **P** and the pad's **d-pad right** (only the cut walker's shove used it).
- `studies/endless_flight.gd`:
  - Holds `pace` and applies it on every launch, respawn and crash.
  - P or d-pad right cycles the pace mid-flight. The weight's note shows "Pace: fast · cruise 44, Boost 69 m/s". The speed eases to the new throttle's speed.
  - The hint line gets "P pace". The F1 weight line gets the pace, cruise, Boost, streak strength and FOV.
  - The chase's `cruise` is today's, so the view widens and eases back with the real speed.
  - Extra FOV: WIDE_FOV 3° from 46 to 92 m/s, plus LOW_WIDE 1.5° low and fast over the land, eased over 0.5 s.
  - Streaks by speed (40 to 95 m/s, to 0.75), low and fast (within 1 to 4 spans, from 25 to 45 m/s; 0.55), Boost (0.25) and the surge (0.45). `--streaks=<x>` scales them, 0 turns them off.
  - **Camera shake off** (change of brief from the user):
    - SHAKE 0 scales the near-miss round's NEAR_SHAKE, SCRAPE_SHAKE and LOW_SHAKE, so the eye no longer shakes on a close call, a scrape, or the low-zone buffet. `--shake=1` brings back that round's amounts.
    - The buffet is still felt in the plane's motion, the rumble and the sound.
    - The old wind buffet past cruise (`--rush=`) stays off by default, as before.
    - No speed shake was added.
  - Near-miss FOV punch: PUNCH halved to 3°, eased in over PUNCH_IN 0.12 s (no snap) and dying over PUNCH_FADE 0.4 s.
  - Crashes have no camera reaction beyond the existing dark fade.

Keys and buttons
- Pace: **P**, or the pad's **d-pad right**. Order: today, brisk, fast, round. Starts on brisk.
- `--pace=today|brisk|fast|<number>`, `--shake=<x>` (default 0), `--streaks=<x>` (default 1).

Knobs and where they live
- `flight_pace.gd` PRESETS speed: today 1.0, brisk 1.25, fast 1.5. DEFAULT brisk.
- `endless_flight.gd`: WIDE_FOV, WIDE_SPEED, LOW_WIDE, WIDE_EASE, CLOSE_IN 0.12, CLOSE_DOWN 0.18, STREAK_SPEED, STREAK_TOP, LOW_SPANS, LOW_SPEED, LOW_STREAK, BOOST_STREAK, SURGE_STREAK, STREAK_FLOW, PUNCH, PUNCH_IN, PUNCH_FADE, SHAKE.
- `speed_streaks.gd`: ALPHA 0.22 (the most a line is opaque), EDGE (mask from the centre), CELLS (density), EASE_IN/OUT.
- `flight_sound.gd`: AIR_OVER, OVER_PITCH, WHISTLE_OVER, OVER_CUT.
- `glide_camera.gd`: CLOSE_SHARE.

Turning: the held rate stays at 2.08 rad/s at every pace, so the radius grows with the speed.
- The roll, the turn's onset (0.55 s to 90%) and a 180°'s 1.82 s stay the same in the hand. Turns reaching the same rate in the same time is what the weight round tuned.
- Tightening the rate to keep today's radius would mean 3.1 rad/s at fast: a 180° in 1.2 s, and twitchy.
- Even at fast the radius is 19 m and a full-stick 180° is 45 m wide. That is well inside a meadow, a valley, an arch run or a tunnel's bend, so the land stays threadable.

Measured (throwaway `scratch/pace.gd`, `pace_sound.gd`, `pace_cycle.gd`, `pace_cap.gd`, through the real loop and stick, uncommitted; `python tools/drive.py scratch/pace.gd -- --part=<speeds|turn|pull|handsoff|land|stream> --scene-args --pace=X`; medium weight, seed 1)

| | today | brisk | fast |
|---|---|---|---|
| cruise / Boost / surge (m/s) | 29.4 / 46.2 / 60.0 | 36.8 / 57.7 / 75.0 | 44.1 / 69.3 / 90.0 |
| dive cap / Brake (m/s) | 54.8 / 13.2 | 68.5 / 13.2 | 82.2 / 13.2 |
| held turn (rad/s) / radius at full stick (m) | 2.08 / 12.5 | 2.08 / 15.7 | 2.08 / 18.8 |
| 180° time (s) / width (m) / speed lost (m/s) | 1.82 / 30 / 3.0 | 1.82 / 37 / 3.8 | 1.82 / 45 / 4.6 |
| sink-through, full back from a 30° dive (m) / time to the bottom (s) | 6.75 / 0.72 | 8.41 / 0.72 | 10.08 / 0.72 |
| latest clean pull from a 30° dive (belly clearance, m) | 7.5 | 9.0 | 10.5 |
| first scrape at (m) | 7.0 | 8.5 | 10.0 |
| a ~1 m pull-out's score | 1987 (least 0.89 m, close) | 1871 (0.84 m) | 1778 (0.78 m) |
| hands-off to a scrape from 2 / 3 / 4 m (s) | 1.15 / 1.68 / 2.63 | 1.13 / 1.95 / 2.75 | 1.20 / 2.07 / 2.80 |
| hand landing, 12 m/s approach (grade, speed, sink) | greaser 5.78, 0.67 | greaser 5.78, 0.67 | greaser 5.78, 0.67 |
| hand landing braked from cruise, 20 m up | greaser 5.74, 0.67 | greaser 5.75, 0.67 | greaser 5.76, 0.67 |
| air: rush gain / pitch at cruise | 0.102 / 0.99 | 0.150 / 1.03 | 0.207 / 1.08 |
| air: rush pitch / whistle at the surge | 1.17 / 0.075 | 1.23 / 0.093 | 1.29 / 0.108 |
| engine pitch at cruise / Boost | 1.04 / 1.35 | 1.11 / 1.45 | 1.17 / 1.55 |
| FOV at cruise low / Boost low / surge low (rendered) | – | 80.2 / 84.2 / 90.0 | 83.2 / 87.0 / 91.8 |

- `today` is exactly the near-miss round:
  - The stick-scripted path digest is identical, at `--weight=off` (2843421620) and at medium (2068252567). So `--weight=off --pace=today` is the original flight.
  - `scratch/nm.gd --part=pull` gives the near-miss table's medium column: 157 / 1217 / 1861 at 12 / 9 / 8 m, scrapes from 7 m, crash from 4.5 m, and the 8° glide's 387 / 607 / 762.
  - `scratch/weight.gd` gives the weight table's medium column: 6.75 m, 0.72 s, 0.55 / 0.43 s, 2.89 m/s, 1.82 s.
  - The pull rows in the table above come from this round's driver, which starts the dive from 60 m, so the dive is a little faster at the pull than nm.gd's 45 m start.
- The lags are time-based and stay so: the sink-through takes 0.72 s to its bottom at every pace, and the turn reaches 90% in 0.55 s. The distance grows with speed: the latest clean pull goes from 7.5 to 10.5 m.
- Near misses still grade sensibly:
  - Bands are by clearance, unchanged.
  - With the closing reference times the pace, the closing factor sits at its cap for a 30° dive at every pace.
  - A ~1 m pull-out scores within 11%, slightly less at fast (the pull bleeds more speed). The meter (4000) fills at about the same rate.
- The low zone is not a death trap at speed: hands-off from 3 m the plane takes slightly longer to scrape at fast than today.

Streaming verdict: it keeps up at fast with Boost and the surge (89 to 90 m/s). The streamer is unchanged.
- How it was measured:
  - `scratch/pace.gd --part=stream`: 60 s straight, then 60 s in a long turn (stick 0.18), the surge held with the meter kept full, at `--view=2` (this PC's default on its discrete GPU).
  - Headless runs were padded to real time (`--realtime`), so the workers get the wall time a 60 fps frame gives. Unpadded headless runs at about 270 fps and starves them; that is not a fair test.
  - A 25 s rendered run gave the real frame time.

| fast, surge | straight 12 m over the land | turn 12 m over | straight 50 m over | turn 50 m over | rendered straight / turn, 12 m |
|---|---|---|---|---|---|
| distance (km) | 5.34 | 5.35 | 5.32 | 5.34 | 2.2 / 2.23 (25 s) |
| queue mean / max | 0.0 / 4 | 0.0 / 2 | 0.0 / 2 | 0.0 / 6 | 0.3 / 10, 1.2 / 22 |
| nearest full-detail (level-0) leaf missing ahead (m) | 124 | 113 | 0 (once at the start) | 74 | 142 / 132 |
| frames with a level-0 leaf missing within 150 m ahead | 7 of 3600 | 6 | 18 | 17 | 22 / 24 of 1500 |
| frames with no ground collider under the plane | 0 | 0 | 210 (high over hills: level 0 not wanted there) | 0 | 0 / 0 |
| frame (ms, mean / max) | 4.3 / 25 CPU | 3.7 / 12 CPU | 3.6 / 25 CPU | 2.9 / 9 CPU | 11.9 / 53, 10.1 / 22 |

- In comparison, today's surge (60 m/s), rendered: nearest missing level-0 leaf 147 / 178 m, frame 10.7 / 11.4 ms mean.
- The 50 to 53 ms max in both rendered runs is a hitch at the run's start, not at speed. The slowest commit (15 ms rendered) is the same at both paces.
- The streamer's lead caps at LEAD_MOST 48 m (0.53 s at 90 m/s), and the ring still keeps full detail 110 m or more ahead. No knob was changed.
- Not checked: grass's own streaming (`endless_grass.gd` lead and prefetch). The rendered stills at 89 m/s showed full grass to the horizon round the plane.

Proof
- Smoke: endless_flight PASS by default (brisk, medium), `--pace=today`, `--pace=fast --weight=heavy` and `--weight=off`. flight_study PASS.
- Cycling (`scratch/pace_cycle.gd`): starts on brisk (cruise 36.75). P goes fast, today, brisk, with the note. D-pad right through `Input.parse_input_event` goes to fast. The speed eases to 44.1 within 10 s.
- Rendered (`scratch/pace_cap.gd --rendered`, stills in `scratch/pace_cap/`): fast and brisk at cruise 30 m up, and low over a meadow at cruise, Boost and the surge, then up at the surge.
  - The first look had the lines too crisp and too many. They were made softer, rarer, shorter and fainter (ALPHA 0.3 to 0.22), and the extra FOV went down from 4° to 3°.
  - Now they show as a few soft pale strokes in the sky's corners. Over the bright grass they hardly show.
  - The surge's FOV is about 91 to 92°.

Not verified
- The streaks in motion (stills only): whether the dashes' outward flow reads as wind or flickers, and whether they should show over the land more.
- The feel in the hand at brisk and fast: whether the 19 m radius at fast feels wide, and whether the later pull-outs at fast are fair. The user judges by playing.
- The sound by ear (the dummy driver only). Today's surge sounds very slightly higher than before (`over` 0.15 past 54 m/s).
- The near-miss punch's eased version on screen, and the camera with the shake off, in play.
- Grass streaming at fast (see above). A tunnel or arch flown at fast was not driven.

Tests this breaks
- None found. A targeted headless run: `test_knife_drift`, `test_flight_study`, `test_flight_metrics` and `test_world_scale_guard` pass.
- `test_sky_plane` and `test_glide_camera` still stop at the removed scarf (`_scarf_points`), as before. A bare SkyPlane has pace 1, and a bare GlideCamera has close_in and close_down 0, so nothing they test moves.

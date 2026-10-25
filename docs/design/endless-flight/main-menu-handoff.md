# Main menu: handoff

Endless flight now opens on a main menu: the plane parked on its wheels in
a meadow near the start, its engine idling, a slow camera circling it, and
the old ZENSCAPE inscription with Start and Quit over it. Start swings the
camera round behind the plane, runs the engine up on the brakes, and the
plane rolls off and lifts off on its own. Branch `main-menu`.

## Play

- `./run-endless-flight.command` / `.\run-endless-flight.cmd` /
  `python tools/play.py` now open on the menu (they no longer pass
  `--no-title`).
- `--no-title` skips the menu and starts in the air as before. The harness
  (`tools/harness/drive.gd` `open`, smoke, shot) still adds it, so drivers,
  tests and captures behave as they did. To get the menu in a driver or a
  still, put `--title` among the scene args: `open` then leaves `--no-title` out.
- `--menu-dof=X` turns on a depth-of-field blur behind the plane (X times
  `MenuStage.DOF.z`; off by default, see below).

Keys: Space, Enter or pad A picks. Up/down or the d-pad move between Start
and Quit. Escape or pad B quits. The mouse picks by hovering and clicking.
Flight keys (V, P, R, F, the sticks, the mouse look) do nothing while the
menu is up or the camera is swinging.

## What was built

- `scripts/endless/menu_spot.gd`: finds the parking spot. It walks rings
  out from the start (every 14 m, out to 900 m) and reads only the land
  field: dry turf, no river or pond, meadow 0.45 or more, level within
  0.45 m over 7 m. Along one of 16 headings (nearest the spawn heading
  first) it needs 110 m of turf, no steeper than 9 % a step and climbing no
  more than 3 m. Then `clear` rules out trees, arches, halls and tunnels
  once they are primed there: room to circle the plane, and the run plus
  the climb-out. The study takes the first candidate that passes. The
  result depends only on the seed and start (about 2 ms). The land itself
  is unchanged, so co-op stays repeatable.
- `scripts/endless/menu_stage.gd`: the menu's phases (MENU, LEAVING,
  TAKEOFF, DONE). It supplies the flight input, poses the camera after the
  chase has placed it, and ramps the engine (it starts 0.6 s in, so
  `engine-start` plays and the propeller spins up). The orbit is 2.35
  wingspans out and at least 0.95 wingspans over the land, turning at
  0.075 rad/s. It starts three-quarters on from the nose with a 44° FOV
  and a slow vertical drift.
- `scripts/endless/main_menu.gd`: the overlay. ZENSCAPE in Newsreader 500
  at 58 px with 15 px tracking, under `shaders/title_gilt.gdshader`
  (brought back from `archive/before-the-cut`), between two gold
  hairlines, pinned to the top. Start is in Spectral at the foot, on a
  pressed patch with a dashed stitch that breathes on a 5.2 s sine. QUIT is
  in small caps below it. It fades in like the old title (a 1.4 s veil, the
  inscription over 2.2 s, the picks after 0.95 s) and fades out over 0.7 s.
  The scrim is new and lighter (`shaders/menu_scrim.gdshader`): the old one
  darkened the middle of the screen, where the plane now sits. The tagline
  was dropped.
- `scripts/plane_figure.gd`: an idle hum, set by `hum` (0–1), with `rev`
  for the run-up and `sway` for the springs:
  - The propeller runs at 16 turns/s (the blur disc), or 2.6× that at full
    rev.
  - The engine buzz: small position and angle jitters as sines at 17–29
    Hz. Measured at 1440×900, the nose and wingtips move about 1.2 px a
    frame.
  - A slow roll and nod on the wheel springs, 0.018 and 0.009 rad at
    0.55 and 0.83 Hz, with a bob and a small torque lean. It pivots about
    the wheels, so the ground scale keeps it.
  - The elevator and ailerons flutter at 6–10 Hz in the propeller wash.
- `scripts/endless/grass_react.gd` `part(at, reach, strength, slot)`: the
  grass parted round a parked thing. The menu parts it round the plane
  (0.8 wingspans) and round the camera (1.3 wingspans). Without that, the
  meadow grass (about 2 m tall) buried the wheels and filled the view.
  While parked, the idling wash stirs the grass but kicks up no motes.
- `studies/endless_flight.gd`: parks the plane (`_launch(..., parked)`:
  `SkyPlane.park`, `ManualLanding.begin(plane, true)` = STOPPED, ground
  scale on) and wires up the stage and overlay. The mouse is captured only
  after the handoff. During the stage the ground chase drops its sideways
  cine offset.

## How Start hands off

I chose the automatic roll-off: it reads as one move, and a new player has
nothing to fumble. The sequence:

1. The overlay fades. Over 2.6 s the camera swings round the plane from
   the orbit into the chase's eye, held 1.5 wingspans over the land so it
   stays out of the grass.
2. From 0.9 s, Brake and Boost are held: the landing's run-up on the
   brakes. Strain builds, and the engine sound and the figure's `rev`
   climb.
3. At 2.6 s the brakes let go: the landing's let-go lunge. Boost stays
   held and the stick is pulled back. The player's stick steers the roll,
   and Brake on the wheels hands control over at once.
4. The wheels leave about 1.4 s after the let-go, after roughly 9 m of
   roll. The pull is held 1 s more, while the camera's lift fades into the
   plain chase, unless the player pitches. Then it is all the player's.

Proven over seeds 1–8 (scratch/menu_start.gd through `tools/sweep.py`).
Every seed lifted off about 238 frames after Start, and 4 s later was
18–36 m over the ground at cruise, with no crashes.

## Checks (all uncommitted, in scratch/)

- Smoke, 400 frames with 0 errors, both with `--no-title` (the default
  harness path) and with `-- --title` (the menu).
- `scratch/menu_start.gd`: through the real loop with real Enter key
  events, 9 checks. The plane is parked and STOPPED, and held Boost and a
  pulled stick do nothing in the menu. The engine idles and the figure
  hums. Enter starts the leave, the plane leaves the ground, the stage
  hands over, and the plane climbs away.
- `scratch/menu_keys.gd`: V and R do nothing in the menu. Down/up and the
  d-pad move the pick, and pad A starts. No pick is taken once the menu is
  leaving.
- `scratch/menu_click.gd`: a mouse click on Start starts.
- `scratch/hum_measure.gd`: the figure's on-screen motion.
- `scratch/menu_shots.gd`: rendered stills (`--rendered`).

## Stills (scratch/, git-ignored)

- `scratch/menu/final_menu1.png`, `scratch/menu/final_menu2.png`: the
  menu, seed 1, at two points on the orbit (final layout).
- `scratch/menu/final_sheet.png`: the menu, the swing round, the roll and
  the lift-off (its menu frames show the overlay before the last layout
  change).
- `scratch/menu/t_sheet.png`: seeds 1, 2 and 3 (earlier overlay layout).

## Not verified headless, or judged only from stills

- The hum's motion. The stills and the numbers say it is calm and visible
  (about 1.2 px a frame of buzz, 8 cm of sway at the wingtip), but I never
  watched it move. The knobs are the `HUM_*` constants in
  `scripts/plane_figure.gd`.
- The sound. The idle, `engine-start`, the rev on the brakes and the
  takeoff come from `scripts/endless/flight_sound.gd` unchanged; nobody
  listened to them.
- The real pad (only synthetic joypad events were tested) and Quit
  actually closing the window (not driven, since it ends the run).
- Hover selects the pick under the cursor, so a cursor resting over Quit
  when the window opens shows Quit lit (seen once).

## Open points

- The depth of field is off by default. The look's painted land read
  smeared and banded through Godot's blur. `--menu-dof=1` turns it back
  on to compare.
- Flowers (lupins, daisies) don't part with the grass, so on some seeds a
  stalk pokes through the fuselage (seed 2).
- When the menu is up the land streams round the parked plane. Its first
  spot candidate can be blocked by a grove, which moves it to the next
  one, up to a few hundred metres away (seed 1 parks about 110 m from 0,0).
- AGENTS.md's Windows "By hand" play line still passes `-- --no-title`,
  which now skips the menu. I didn't touch AGENTS.md.

## Tests

No new tests. In the four tests that touch the changed files,
`test_world_scale_guard` and `test_ruin_kit` pass. `test_glide_camera` and
`test_sky_plane` fail on `_scarf_points`, a PlaneFigure property that
isn't in HEAD either. That failure comes before this round. The full suite
was not run.

## Models

The plane's geometry is unchanged: the hum moves the existing nodes. So
none of `docs/art/model-budget.md`'s tricks apply, and there is no triangle
or frame-time change.

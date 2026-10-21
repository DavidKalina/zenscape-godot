# Handoff: the storm in the heist (prototype)

Branch `iter/heist-storm`. It merges `sky-game-loop-and-world` (the storm
and dragon study) into main and puts one storm into the heist.

## Play it

```
./run-heist.command                          # a storm on about 1 run in 3
godot --path . res://studies/heist_level.tscn -- --no-title --storm=always --storm-at=10
```

- `--storm=always|never`, `--storm-chance=<0..1>` (1/3 by default),
  `--storm-at=<s>`: the storm comes after that many seconds of flight.
- The draw comes from the hunt seed, so `--hunt-seed=N` replays it. Under
  `--no-home` it reads `--hunt-seed=` or draws a seed. The log line is
  `heist: storm yes at 47 s of flight (seed N, roll 0.21 < 0.33)` or
  `heist: storm no (...)`.
- Debug keys, **in flight only**: on foot C is crouch and M is the rope
  study's moveset, and the world view (F4) handles its own keys first.
  - C: a storm cell toward the plane
  - M: a whiteout
  - K: the dragon, far
  - Shift+K: the dragon, close

  They work on `--storm=never` runs too; the weather is built on the first
  press, with a short hitch. Ctrl, Cmd and Alt combinations are passed
  through to the game.

## What's built

- `studies/heist_storm.gd` (`HeistStorm`, the scene's `storm`):
  - Makes the draw.
  - Counts time spent flying. At the drawn time it sends one cell
    (`scripts/storm_cells.gd`) 800 m ahead of the plane, up to 60 m to
    either side, coming back along the plane's line. The cell turns toward
    the plane at up to 0.15 rad/s until it is overhead, then goes on past.
  - The first time the plane is in the core (cell `storm_at` > 0.85), it
    drops a whiteout.
  - Once the murk passes 0.6, it calls the dragon (60% close) if it hasn't
    shown yet in this storm. The sightings also come on their own, but only
    while a cell is out (`sightings.every` is 0 the rest of the time), so
    the dragon never appears in a clear sky.
  - The weather (`scripts/plane_weather.gd`) is built only on storm runs.
    It is built without the field's jets, and its own cells don't come on
    their own.
- **Air**: `plane_air` carries the storm's air (rough air, gusts, and the
  downwash on wing passes). It is scaled by how close the cell is (from
  about 210 m in) or by the murk, so outside the storm the air stays still.
  Nothing is listening to the `sighted` signal: there are no strikes, no
  loot loss and no damage.
- **Grade**: the storm's frame grade is multiplied with the greed meter's.
  Before, each one switched the other's `adjustment_enabled` off.
- **Haze**: home's depth fog colour moves toward the storm's slate horizon
  by the storm's strength, the same way the sky dome does
  (`fold_haze`). Its range is left alone (see Open). In a whiteout the
  murk sheet covers land, cloud and sky equally and seals them all once the
  murk passes `sealed` (0.35).
- The sky's own rain is hidden only while the storm's rain is falling.
  `plane_weather` used to hide it permanently.
- Changes to `plane_weather.gd`:
  - `--storm=` sets a fixed storm strength only when its value is a number.
  - New switches `jets` and `grade_frame`.
  - `frame_grade()` is split out of the frame grade.
  - The study behaves as before.

## Proved (headless unless noted)

- The merge was clean. Import passes. Smoke checks pass with 0 errors:
  `heist_level`, `--storm=never`, `--storm=always --storm-at=0`,
  `--no-home --storm=always`, `aqueduct_isle`, and `sky_weather_field`
  (also with `--storm=1`).
- `scratch/storm/through.gd` (git-ignored) uses the real input path:
  board, take off from home, fly to the heist approach with
  `--storm=always`. On seeds 3 and 7 (storm at 12 s and 40 s):
  - the cell rolled in and reached the plane about 23 s later
  - the murk reached 1.0
  - the storm wind reached 7 to 14 m/s and pushed the plane 60 to 73 m in
    total
  - one sighting fired
  - the plane still reached the approach
- `scratch/storm/draw.gd` at the default chance, seeds 1 to 12: 6 got a
  storm and 6 didn't. Flight times drawn ranged from 31 to 132 s.
- `scratch/storm/shots.gd --rendered --keys` (real key taps in flight with
  `--storm=never`): M drops a whiteout, Shift+K calls the dragon, C sends a
  cell.
- Rendered stills (`scratch/storm/shots/a_*`, `d_*`, with contact sheets):
  - the tower and rain shaft from 600 m and 260 m, and the shaft's shadow
    on the cloud sea
  - slate storm air with the heist isle in view: the haze matches the
    horizon and there is no bright ghost
  - the murk rising, full, lit by a flash and opening
  - a close dragon lit black against the bloom
  - clear sky again afterwards

## Unverified

- Not played by hand. How strong the gusts feel and how the timing works
  are unjudged.
- No sound check. Thunder and the dragon's calls only appear in logs.
- Not checked at night or dusk. The haze slate is scaled by daylight, as
  the dome is.
- No check of a storm that comes on the way home with loot aboard, or one
  that is still out when the plane lands. A cell that is out keeps moving
  on past the plane; on foot only the sky looks change.

## Open

- During the roughly 0.5 s while the murk rises or opens (murk below
  0.35), land, cloud sea and smoke cue all show faintly through the thin
  sheet, evenly. That is the study's own look. Pulling the haze in ahead of
  the murk made it worse: the land became a flat blue cut-out against the
  cloud sea, which no fog touches. That approach was dropped.
- At low murk the whiteout's wisps make a blotchy camouflage pattern over
  the sky (the study's shader).
- The storm air ends about 210 m from the shaft. From 260 m the cell
  reads as a tower over blue sky. A wider dark skirt might sell the
  approach better.
- The draw is made once per scene load. If a restart reloads the scene, the
  same `--hunt-seed` gives the same storm.
- Sighting logs are on (`sighting: ...` lines) for this prototype.
- No committed tests. The full suite was not run, and no existing test
  references the changed files.

## Next (the user's direction; not built)

Later the storm turns threatening, mostly through flying blind: isles in
the murk you might hit, the dragon as a threat, and gusts pushing you into
things.

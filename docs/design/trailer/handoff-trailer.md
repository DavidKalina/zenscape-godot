# Handoff: taped flights and films (2026-11-12)

Footage for a trailer: a flight is taped while it is flown, then drawn again
under Godot's Movie Maker from any camera, with no HUD and no dropped frames.
How to use it is in `tools/README.md` (movie.py).

## What was built

- `scripts/endless/flight_tape.gd` (`FlightTape`): `--record[=FILE]`. A row a
  frame of the flight proper: the frame's delta, the camera, the hour, the
  input, and every number, switch and vector the plane (SkyPlane) and the
  landing (ManualLanding) hold, found from their property lists, so a new
  field is taped without touching the tape. A frame's events follow its row.
- `scripts/endless/flight_replay.gd` (`FlightReplay`): `--replay=FILE`. In the
  tick it stands in for the input, for `hand_landing.step` (the state set
  from the tape, mixed between rows), for the camera after `_frame`, and
  for the hour before `look.step`. It hides the HUD's layers (not the
  look's grade), keeps no book, and quits at the end.
- `studies/endless_flight.gd`: those four hooks, the flags, Esc ends a replay.
- `tools/movie.py`: the launch under Movie Maker, the cut, the frames.
- `.gitignore`: `/override.cfg` (movie.py's, for one launch).

## Proved

- A driven flight (turns, a roll, boost) taped headless through the real
  play loop: 900 rows of 175 columns.
- Replayed headless at 0.7 speed: the plane on the tape's line every frame
  (worst 0.0000 m), the roll back, the stick doing nothing, no HUD layer shown.
- Filmed in a window and looked at: flown, flyby, orbit and side; the first
  frame kept is the first moving one (frame-to-frame difference 0.02 while
  held, 13 from the cut on); 1920x1080, 2560x1440 and 3840x2160 come out at
  their own size on a 2560x1440 screen; half speed gives twice the frames;
  the PNG path; the preview window.
- Smoke: `studies/endless_flight.tscn` passes.

## Not proved

- A hand flight: the title's takeoff, a frame rate that wanders, a pad.
- A landing, a water skim, trees knocked, a find taken, a door (a second
  take): the events are taped and handed back, but none was looked at.
- The .mp4: no ffmpeg on this PC (`winget install Gyan.FFmpeg`).
- The sound, by ear. The WAV is the right length.
- Whether the land keeps up at `--pace 1` on a fast, low line. `--pace 0.5`
  gives its workers twice the time.
- The Mac.

## Known limits

- The clouds, birds, fish, balloons and the whale are not on the tape.
- A plane bought or a skin worn is not on the tape (no book in a replay).
- The tape's file is whole only after a clean quit; a killed run loses at
  most the last 240 frames.

No existing test was changed or run beyond the smoke check.

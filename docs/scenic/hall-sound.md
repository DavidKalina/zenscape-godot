# Hall sound: the Sundered line's room

The plane's sound now changes with the hall it flies through on the
Sundered line (`scripts/hall_line.gd`). The work is in one new file,
`scripts/hall_sound.gd`, with two small hooks:

- `scripts/kit_isle/kit_audio.gd`: `room_engine` (Vector2: gain, pitch
  multipliers, `ONE` by default), multiplied into the engine bed's goal and
  pitch in `_plane`.
- `studies/aqueduct_isle.gd` `_build_chain`: `HallSound.attach(self, isle_chain.chain)`.

The hall line files (`hall_line*.gd`, `sundered_*.gd`, `ruin_kit_hall.gd`)
are unchanged. HallSound only reads them.

## What it does

- **The room, from the hall's own data.** Each piece's bay plans (Sundered's
  planner: the real build's `made.hall.plans`, or the greybox's
  `LinePlan.bays`) give each bay a closure: the roof (whole 1, broken 0.55,
  open 0.08, minus each gap) for 60%, the two walls (by breach: none, door,
  low, arch, collapse) for 40%, plus a bit for a slit's screen. A torn bay
  counts as open. The plane's place in the piece's frame picks the bay,
  blended into its neighbour across the bay's middle and faded to open air
  within 6 m of the piece's box (past the torn ends, over the roof, outside
  the walls). That gives `enclosure_raw`. `pierce_raw` (how holed a closed
  shell is) adds up screens, arches, doors and a broken roof. Both are
  eased in time: enclosure 0.35 s in and 0.55 s out, piercing 0.45 s.
  No rays are cast.
- **In a roofed nave.** Five effects are appended to KitAudio's SFX bus (the
  engine, the air, the whooshes, the drone): a two-tap delay (17 and 29 ms,
  panned, as early reflections), a reverb (wet up to 0.32), a low-pass
  closing to 4.8 kHz, and +2 dB gain. The engine runs x1.38 louder and
  x0.95 pitch. Each is off whenever it has nothing to do.
- **Columns.** When the plane crosses a bay line, each column on that line
  (the outer rows at every line, and the inner ones where the plan has them;
  not on torn lines) within 5 m of a wingtip plays KitAudio's `whoosh`
  one-shot at the column. Louder the closer it is.
- **The wind drone.** Two loops are baked once on a worker at startup (about
  1.3 s of worker time): a breathy low pipe on 65.5 Hz and a twelfth over it
  (196.5 Hz). They are made of partials with slow swells and beating twins,
  breath from noise rung through resonators, and a crossfaded seam. They
  play as KitAudio `Bed`s on SFX, so the room's reverb carries them, by
  `pierce` and airspeed. The twelfth comes in as the piercing swells.
- **Breaking out.** After a closed stretch (held peak at least 0.5),
  enclosure falling under 0.25 starts the release envelope: up over 0.3 s,
  held 0.7 s, down over 2.6 s. While it runs, a high-pass on SFX rises to
  380 Hz (the sound thins), the engine drops up to 50%, and SFX dips up to
  8 dB (near quiet). Flying back into a room cancels it.

## Knobs

The constants at the top of `scripts/hall_sound.gd` are the knobs:

| Constants | Controls |
|---|---|
| `ROOF`, `WALL`, `SCREEN`, `ROOF_SHARE` | How closed each bay is |
| `PIERCE_*` | How holed a bay is |
| `EASE_*` | The glide |
| `WET`, `ROOM_SIZE`, `TAPS`, `TAP_DB`, `CLOSE_CUT`, `ROOM_DB`, `ENGINE_ROOM` | The room |
| `RELEASE_*`, `THIN_CUT`, `QUIET_DB`, `ENGINE_THIN` | The release |
| `DRONE`, `DRONE_HIGH`, `DRONE_AIR`, `DRONE_PITCH`, `PIPE`, `TWELFTH` | The drone |
| `COLUMN_REACH`, `COLUMN_GAIN` | The whooshes |

`--hall-sound=0` turns all of it off.

## Hear it

```
& $env:GODOT --path . studies/aqueduct_isle.tscn --rendering-method forward_plus --windowed --resolution 1440x900 -- --no-title --near-ring --autopilot
```

(On the Mac: `run-aqueduct-isle.command` with `--near-ring --autopilot`.)
Add `--hall-sound=0` to compare.

Recordings of the master bus, uncommitted, from 140 m before the first
piece through pieces 0 to 5 (about 74 s each):

- `captures/hall-sound/flight.wav`: hall sound on
- `captures/hall-sound/flight-off.wav`: `--hall-sound=0`, the same window
- `captures/hall-sound/drone-low.wav` and `drone-high.wav`: the two baked
  drone loops

## Proof (headless, the real loop, autopilot)

`scratch/hall_sound_fly.gd` (uncommitted) runs with
`python tools/drive.py scratch/hall_sound_fly.gd --no-fixed-fps --timeout 500 -- --secs=75 --wav=captures/hall-sound/flight.wav --scene-args --near-ring --autopilot`.
It logs a row every 0.25 s. The table below is sampled from it:

| t (s) | piece / bay | roof | enclosure | pierce | release | reverb wet | low-pass (Hz) | high-pass (Hz) | SFX gain (dB) | engine gain |
|---|---|---|---|---|---|---|---|---|---|---|
| 28.0 | gap before piece 0 | | 0.00 | 0.00 | 0.00 | 0.000 | 20000 | 20 | 0.00 | 0.098 |
| 30.0 | piece 0 (nave), bay 1.9 | whole | 0.82 | 0.04 | 0.00 | 0.264 | 6168 | 20 | +1.65 | 0.120 |
| 32.5 | piece 0, bay 5.4 | whole | 0.94 | 0.25 | 0.00 | 0.300 | 5259 | 20 | +1.87 | 0.133 |
| 35.0 | piece 0, torn end | open | 0.29 | 0.12 | 0.00 | 0.093 | 13202 | 20 | +0.58 | 0.122 |
| 36.0 | gap, then piece 1 | open | 0.05 | 0.01 | 0.54 | 0.017 | 18516 | 97 | -4.17 | 0.092 |
| 39.0 | piece 1 (shafts), bay 3.8 | whole | 0.93 | 0.90 | 0.00 | 0.297 | 5309 | 20 | +1.86 | 0.131 |
| 45.0 | the sidestep (140 m of sky) | | 0.07 | 0.03 | 0.67 | 0.022 | 18133 | 145 | -5.24 | 0.094 |
| 48.0 | the sidestep | | 0.00 | 0.00 | 0.00 | 0.000 | 19992 | 20 | 0.00 | 0.097 |
| 64.0 | piece 3 (cloister), bay 3.3 | open | 0.21 | 0.42 | 0.00 | 0.068 | 14763 | 20 | +0.43 | 0.104 |
| 72.5 | piece 4 (nave), bay 5.3 | whole | 0.94 | 0.32 | 0.00 | 0.300 | 5250 | 20 | +1.87 | 0.132 |
| 81.5 | piece 5 (slit), bay 5.4 | broken | 0.58 | 0.91 | 0.00 | 0.185 | 8749 | 20 | +1.16 | 0.121 |

- Enclosure peaks at 0.97 in whole-roofed naves, sits around 0.6 to 0.73
  in broken stretches, and stays near 0.2 to 0.3 in the open cloister.
- Piercing swells to 0.9 in the shafts and slit pieces. The drone peaks at
  a gain of 0.13 (low) and 0.08 (high).
- A release fires at each piece's exit: 6 in 70 s, envelope peaks 0.4 to
  0.67. Through the sidestep's long gap it fades over about 3 s.
- Nothing jumps. Each 0.25 s step is within what the eases allow (the
  biggest is enclosure 0.36 to 0.82 over 0.5 s, entering a whole nave). The
  WAV's largest sample-to-sample step is 930 against a 7548 peak, so no
  clicks.
- Loudness of the recordings (RMS per 0.5 s): open air about -35 dB in both.
  In the naves about -30 dB with it off (KitAudio's own near-rock rush and
  howl) and -26 dB with it on. At each exit it dips to -38 to -40 dB, then
  comes back to -35 dB.
- Column whooshes: 75 over 6 pieces, about 1.4 a second in the nave at
  cruise.
- Smoke: `python tools/smoke.py studies/aqueduct_isle.tscn studies/zenscape.tscn -- --near-ring --autopilot`
  PASS, 0 errors.

## Cost

- Main thread: about 65 us a frame (mean over the flight), mostly
  transforming the plane into each standing piece's frame. Bus parameters
  are set every frame.
- Startup: about 1.3 s of one worker thread, once, for the drone bake. That
  is 2 x 345 KB of 16-bit stereo at 22 kHz.
- Audio thread: the reverb, delay and two filters run on SFX only while in
  or just out of a hall. Out of the halls they are disabled.

## Tests

None added. `tests/test_kit_audio.gd` and `tests/test_aqueduct_isle_plane.gd`
read the engine's goal, which is unchanged outside the halls (`room_engine`
is `ONE`). `test_aqueduct_isle_plane.gd` passes. `test_kit_audio.gd` fails
on "The serpent is found (0)", and it fails the same way without this
change, so that failure was already there.

## Not done or not checked

- No one has listened to it yet. The level, envelope and click numbers above
  are measured, but the drone's timbre and the room's balance are untested
  by ear. Headless records through the Dummy driver in wall-clock time, so a
  windowed run is the real check.
- There is no apse on the line (its pieces are the middle acts, both ends
  torn). "Breaking out" here means each torn end, the gaps and open
  cloister bays.
- Entering a hall fast may stack the column whooshes on KitAudio's own
  probe whoosh (`near` rising). They sound alike, so I left both in.

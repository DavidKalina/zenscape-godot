# Bore sound: handoff

Sound in the burrower's cave chase: the spurs erupt with a heavy rock burst, the
tell before each one grinds, plugs grind and land, and inside any bore or hall the
plane's own sound goes through a short stone room. Branch `iter/bore-sound`, not
merged, not pushed.

## Fly it and listen

```
cd /Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/agent-a6372390844ec3a5b && python3 tools/play.py -- --no-title --pilot-file=/tmp/bore-sound.json --at=3400,4384 --heading=90 --alt=60 --burrower-every=5
```

That puts the plane on the axis of mouth `1_1/a`, where he shows within about 25 s;
follow him in on Boost. `--burrower-every=5` brings him back 5 s after a run instead
of 45-75. There is no debug key to jump into a chase; the `--at` start is the
quickest. Any tunnel mouth, or a long hall, gives the reverb without him.

## What plays when

- **A spur's tell** (he passes it, the crack opens): `bore-grind`, a rising rumble
  and gritty grind that peaks at 0.78 s and cuts off just before the snap (HOLD_S
  0.8 s). 3D at the spur's root, heard to 180 m.
- **A spur erupting** (the snap): three layers at once, each its own take (4 of
  each) and its own pitch spread: `bore-thump` (a falling 120-150 Hz body blow and
  a dirt thud), `bore-crack` (a hard snap, sub-cracks, a short tuned stone ring),
  `bore-debris` (grit thinning out over about 2 s, pebble knocks, a low settle). The
  spur's girth sets the pitch: thin 1.15, thickest 0.85. 3D at the root: full
  within 22 m, falling off to nothing at 260 m (the old crack fell off by 70 m,
  while he runs some 40-150 m ahead of the plane).
- **A plug** as he passes: the grind pitched down (0.7). When it lands: the spur's
  burst, quieter (0.7) and lower (0.8). It replaces the old debris, crash and thump.
- **In a bore or hall:** the engine, wires, air (rush, whistle, howl), the whooshes
  and all the bore's sounds above go through bus `SFX Bore`: an EQ (+2.5 dB at
  100 Hz, +4 dB at 320 Hz, -3 dB at 3.2 kHz, -6 dB at 10 kHz) and a short reverb
  (room 0.32, damping 0.55, 14 ms pre-delay). The air's low-pass closes to 0.6 of
  itself, so the high wind hiss is damped. In full the reverb's wet is 0.34 and
  its dry 0.85. It eases in over 0.45 s and out over 0.55 s, at a steady rate on an
  S-curve, and both effects are switched off while out in the open.
- **"Inside"** means the study's `plane_figure.bore` (the tube's open middle)
  or NearMiss `overhead` (non-land rock over the plane, a ray it already casts)
  while FlightSound's ray ring has `enclosed` past 0.3. The second test catches
  the mouths, halls and shafts the tube test leaves out, and a quick pass under a
  lone arch reads as open. No new rays.

Buses: Master > SFX > SFX Bore > SFX Air. Ambience doesn't go through the room.
The plume's blast and the bore's rumble bed (`burrower_bore.gd`) stay on SFX,
outside the room: that file was left alone for the pacing round.

## How the sounds were made

`tools/generate_bore_audio.py` synthesizes them: stdlib only, deterministic,
the building blocks of `tools/generate_kit_audio.py`. It writes the 15 takes into
`assets/audio/bore/`. `python3 tools/generate_bore_audio.py crack` re-bakes one
family. After a re-bake, import:
`python3 tools/godot.py --editor --import`.

## Knobs to tune by ear

`scripts/endless/flight_sound.gd`:

| Knob | Now | What |
|---|---|---|
| `BORE_IN`, `BORE_OUT` | 0.45, 0.55 s | fade in and out |
| `BORE_WET`, `BORE_DRY` | 0.34, 0.85 | reverb wet and dry in full |
| `BORE_ROOM`, `BORE_DAMP`, `BORE_PREDELAY` | 0.32, 0.55, 14 ms | the room's size, how dark its tail is, its slap |
| `BORE_EQ` | 0, 2.5, 4, 0.5, -3, -6 dB | 32 / 100 / 320 / 1k / 3.2k / 10k Hz in full: the boom and the hiss |
| `BORE_AIR_CUT` | 0.6 | what's left of the air's low-pass cutoff in full |
| `BORE_SIDES` | 0.3 | how closed in rock overhead must be to count |
| `BURST_THUMP`, `BURST_CRACK`, `BURST_DEBRIS` | 1.0, 0.75, 0.55 | a burst's layers |
| `BORE_UNIT`, `BORE_REACH` | 22, 260 m | full within, silent past |
| `TELL`, `TELL_REACH` | 0.45, 180 m | the tell's grind |

`scripts/endless/bore_spurs.gd`: `SNAP_GAIN` 1.0, `SNAP_PITCH` (1.15, 0.85) thin to
thick, `TELL_GAIN` 1.0. `scripts/endless/bore_plug.gd`: `RUMBLE_GAIN` 1.2 and
`RUMBLE_PITCH` 0.7 (its grind), `LAND_GAIN` 0.7 and `LAND_PITCH` 0.8 (its burst).

## The hooks in the chase

Kept small for the merge with the pacing round. `bore_spurs.gd` `step`: one line
plays the tell the first frame a fired spur moves (`sound.bore_tell`), and the snap's
line now calls `sound.bore_burst`. `bore_plug.gd`: its two sound lines call the same
two functions. `burrower_bore.gd` is untouched. FlightSound has two new calls,
`bore_burst(at, gain, pitch)` and `bore_tell(at, gain, pitch)`. It also gains
`bore_wet`, `in_bore` and `bore_heard`, a list for drivers, and `shot` takes an
optional `reach` and `unit`. The 3D voice pool went from 8 to 16.

## Proof (headless, `--sound=on`, a scratch driver through the real loop)

Driver `scratch/bore_sound.gd` (the chase-smash round's chase pilot plus a sound
log; git-ignored).

- **Mouth `1_1/a`, lane 12:** a whole run, 0 crashes, the chase ended `out`.
  - In-bore came on at the mouth (overhead + enclosed; the tube flag comes a little
    later). `bore_wet` rose 0.04, 0.26, 0.48, 0.70, 0.93, 1.00 at 0.05 s steps
    (0.45 s in all). Over the same steps the reverb's wet went 0.001, 0.057, 0.161,
    0.268, 0.335, 0.340 and the air cutoff 6470 to 4840 Hz.
  - It stayed on through the 39 s chase with no flicker, and went off as the
    plane left the far mouth.
  - Out: 0.97 to 0 over about 0.6 s (a two-frame stall near the start of the fade,
    0.04 s, inaudible).
  - 32 bursts heard at 37-123 m from the plane (median 78), 32 tells at 79-159 m
    (median 119), ahead and to both sides, none past the reach.
- **Mouth `1_1/a`, default lane:** the scripted pilot crashed 1458 m in. Before
  that, 27 bursts at 37-168 m (median 72) and 27 tells at 79-150 m.
- **Mouth `-1_1/a`:** the pilot crashed 348 m in. 8 bursts at 14-64 m, 8 tells
  at 85-100 m.
- **Smoke:** `studies/endless_flight.tscn`, PASS, 0 errors, both headless and with
  `--sound=on` (which builds the buses and effects).
- **Tests:** none in `tests/` names FlightSound, the bore's spurs or plugs, or the
  buses, so none should break. Full suite not run.

## Unverified

- **By ear:** nothing has been listened to. The clips were checked by numbers:
  the envelope per 0.1 s and zero-crossing rate (thumps 50-60 Hz, cracks about
  1 kHz and gone in 0.3 s, debris 320-560 Hz over 2 s, the grind peaking at
  0.7-0.78 s). The levels against the engine and air, the reverb's colour and
  whether the thump reads on laptop speakers are the user's call.
- **The audio capture:** see the round's report for whether `--write-movie` gave
  a .wav.
- **Halls and arches outside the chase:** the overhead + enclosed test wasn't
  flown through a slot hall or an arch run, only the chase bore's mouths.
- **CPU:** the reverb and EQ are on only while `bore_wet` > 0. Not measured.

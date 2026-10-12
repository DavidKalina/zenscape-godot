# Traps, round 2: Wind (2026-10-12)

> Greybox. Branch `feature/trap-wind`. `scripts/traps/trap_wind.gd` (two modes
> behind the `mode` knob); `trap_wind_blaster.gd` is a 6-line subclass that
> only presets `mode=blaster` so the yard gets a lane for each (the yard
> builds one default trap per `TRAPS` line, so there are two lines, `wind`
> and `wind_blaster`).

A narrow deck over a drop (cost 3, void) with stone mouths along its -x side
blowing +x, across it. A mouth's wind is a zone `reach` either side of it.
It is published through `air_at` (the motor's `air`: the pocket sail is
carried by it). A pilot not sailing is moved by the same wind in `before`
with `motor.carry` (a shove, not a velocity change): toward the edge on the
ground, as extra range in a jump. No contract change.

- **vent**: each mouth breathes `on` then rests `off`, staggered; glows
  orange and "inhales" (`tell`) just before.
- **blaster**: a visible plate (`plate_at`). Stepped on, the mouths nearest
  his aim glow and inhale; `delay` later they blast for `blast_time`. Keep
  moving and it lands behind; stop and he is shoved off. Re-arms after `rearm`.

| knob | default (wanderer 1.0) | meaning |
|---|---|---|
| mode | vent | "vent" or "blaster" |
| count | 3 (blaster lane 4) | mouths |
| reach | 1.2 m (run x 0.25) | half-length of a mouth's zone; spacing is 2x |
| width | 2.88 m (run x 0.6) | deck |
| force | 6.24 m/s (run x 1.3) | wind speed |
| throw | 7.2 m | how far past the deck the wind carries |
| on / off | 1.0 / 4.0 s | vent breath / rest |
| tell | 0.3 s | vent inhale before the breath |
| stagger | 1.0 s | each mouth's offset along the row |
| delay | 0.5 s | blaster plate to blast |
| blast_time | 0.5 s | blaster blow |
| rearm | 2.0 s | blaster plate ready again |
| plate_at / plate_len | 1.2 m / 1.2 m | plate position along the lane / length |
| lead | 0 | 0 aims where he stands, 1 where he will be (later tiers) |
| spread | 0.6 | mouths within this many spacings of the aim fire |

Run (windowed):

    godot --path . res://studies/trap_yard.tscn -- --no-title --trap=wind
    godot --path . res://studies/trap_yard.tscn -- --no-title --trap=wind_blaster

Test: `godot --headless --path . --script tests/test_trap_wind.gd`.

## Unverified / the user's call

- Feel: force (6.2 m/s), the 0.5 s delay, 1 s on / 4 s off, how readable the
  orange inhale and white blast colours and the streak particles are.
- Sounds are placeholders (`inhale`, `gust`, `click` via `tell_sound`).
- Sail and long-jump carry in the air go through the same `air_at`; the sail
  case and a long jump across the vent are not exercised by the test.
- The shove can in principle push through a wall (mouth blocks are at the
  deck edge, pushing away from them, so not hit in the yard).
- Windowed run and rendered look not exercised (headless only).
- Not built: `lead` > 0 is only a knob (untested), tripwire variant (plate only).

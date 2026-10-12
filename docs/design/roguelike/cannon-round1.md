# Cannon, round 1 (greybox, reworked 2026-10-12)

> Branch `feature/cannon`. Travel first: the pilot is the cannonball. Firing
> yourself is free and the cannon is always usable. Powder kegs are **ranging
> shots**: fire a keg to judge the distance, then fire yourself.
> (Round 1 first had kegs as ammunition to load; the user corrected that.)

## Controls

- Touch a keg: picked up, hovers behind you like a carried plane part. Up to 3.
  No penalty to the tech.
- `E` (pad X) by a cannon: climb in / out.
- Inside: stick turns the barrel left/right and pitches it. **Left / Right arrow
  (d-pad)** set the power, in 5 notches (chosen over hold-to-charge so the same
  power can be set again exactly, which is what makes a keg's landing a fair
  guide). `Space` (pad A) fires **you**. `F` (pad Y) fires a **keg** from the
  hover; with none, a click.
- A keg flies the arc you would fly at the same aim and power (same launch
  velocity, the motor's gravity, no sail or steering), lands, and leaves a
  marker (orange ring and column) that stays until `R`; a thud. Into the void it
  leaves a grey puff where it crossed the cannon's height and a "lost" sound.
- No arc preview. Reading the keg is the skill.
- Fired, you leave by `PilotMotor.toss` (no tumble, sail ready, some steering).
- `R` resets (kegs back, markers cleared, cannons at rest aim).

## Parts

- `scripts/carried_follow.gd`: the hover extracted from `plane_arc.gd` (the
  plane arc calls it with the same numbers; test_plane_arc passes).
- `scripts/cannon/keg.gd` (one kind: the two sizes no longer set any power),
  `cannon.gd` (barrel, aim, power, `flight`/`landing`/`landing_for` simulation),
  `cannon_field.gd` (the `foot_pieces` hook; the motor's `rider` while inside;
  flies the kegs and lays the markers).
- `studies/cannon_yard.gd/.tscn`: start isle (cannon, 3 kegs). Targets placed
  from the shot (`Cannon.landing_for`) at the aims in `AIMS`: a narrow isle to
  the left (target 1), a wide near isle straight ahead with a second cannon and
  no kegs, and a narrow target 2 to the right of that cannon's line. Distances
  are hard to judge by eye, kegs are few: spend them where it counts.
- Sounds are placeholders in `heard` (`boom`, `click`, `climb`, `pickup`,
  `thud`, `lost`), signal `sounded`.

Windowed: `godot --path . res://studies/cannon_yard.tscn -- --no-title`
(`--cannon=in` starts by the cannon with a keg in hand).
Test: `godot --headless --path . --script tests/test_cannon.gd`.

## Knobs (cannon.gd `defaults`; unit = walk x 0.5 = 1.2 m)

| knob | default |
|---|---|
| speed_max | run x 5.4 = 25.9 m/s at full power |
| power_notches / power_rest | 0.5, 0.62, 0.75, 0.87, 1.0 of it / index 2 (range goes with the square: about 6.5 to 26 m) |
| pitch rest / min / max | 40 / 15 / 75 deg |
| yaw_limit | 70 deg either side of the cannon's heading |
| yaw_rate / pitch_rate | 1.2 / 0.9 rad/s |
| base_height, barrel_length, barrel_radius | unit x 0.75, 2.2, 0.45 |
| enter_reach | unit x 2.4 |
| field: max_kegs, pick_reach, carry_share, marker_height | 3, 1.3 m, 0.55, 3 m |

## Unverified

Windowed feel: the hover look, the camera sitting along the barrel while a keg
flies (it does not follow the keg), whether the marker reads from the barrel at
range, aim and power rates, the arrow/F/pad bindings. Keg flight ignores walls
(it lands on tops only) and matches the pilot's to a few cm in the test at 60
fps. Headless only.

## Next steps

A camera follow for the keg; kegs exploding near fire; firing objects instead
of yourself; broken cannons; a hold-to-charge power as an alternative; real
sounds and a muzzle flash; generated isles with tiered keg placement.

# Cannon, round 1 (greybox, reworked 2026-10-12)

> Branch `feature/cannon`. Travel first: the pilot is the cannonball. Firing
> yourself is free and the cannon is always usable. Powder kegs are **ranging
> shots**: fire a keg to judge the distance, then fire yourself.
> (Round 1 first had kegs as ammunition to load; the user corrected that.)

## Controls (all through the game's pad layer, scripts/pad.gd actions)

| Pad | Keys | Does |
|---|---|---|
| walk onto a keg | same | picked up; hovers behind you like a carried plane part (max 3, no penalty to the tech) |
| A at a cannon | Space | man it (aim mode); a keg in hand slides into the barrel |
| left stick | WASD | turn the barrel left/right, pitch it |
| d-pad left/right (or down/up) | , . | power, 5 notches |
| A, barrel loaded | Space | fires the keg: it flies your exact arc and leaves a marker; the barrel is then empty |
| A, barrel empty | Space | launches **you** (free; with no kegs at all too) |
| X | X | load the next keg from the hover (take another test shot) |
| B | E | step away without firing (a keg loaded stays in) |

The prompt line at a cannon (PadPrompt, glyphs on a pad): "A man the cannon",
"A fire keg · X load keg (2) · B leave · d-pad power 3/5", "A launch yourself
· X load keg (1) · B leave · d-pad power 3/5".

- A keg lands: orange ring and column until `R`, a thud. Into the void: a grey
  puff where it crossed the cannon's height, a "lost" sound.
- No arc preview. Reading the keg's flight is the skill.
- Fired, you leave by `PilotMotor.toss` (no tumble, sail ready, some steering).
- `R` resets (kegs back, markers cleared, cannons at rest aim and empty).

### Why the kegs did nothing on a pad (round 2)

The keg and climb-in buttons polled raw `Input.is_joy_button_pressed(0, ...)`
and physical keys (F, the arrow keys, E) outside the game's pad layer. A did
nothing at the cannon (it only jumped; climbing in was X), the keg shot was on
Y/arrows nobody was told about, the arrows are also the move stick's keys, and
no prompt said any of it. Now every read is an InputMap action from
`Pad.ACTIONS` (`walk_jump`, plus new `cannon_load`, `cannon_leave`,
`cannon_power_up/down`), with edges taken in the field, and the keg pickup is
a ground-distance and height window around his real feet.

## Parts

- `scripts/carried_follow.gd`: the hover extracted from `plane_arc.gd` (the
  plane arc calls it with the same numbers; test_plane_arc passes).
- `scripts/cannon/keg.gd` (one kind: the two sizes no longer set any power),
  `cannon.gd` (barrel, aim, power, `flight`/`landing`/`landing_for` simulation),
  `cannon_field.gd` (the `foot_pieces` hook; the motor's `rider` while inside;
  loads, flies the kegs, lays the markers, the prompt).
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

Windowed and on a real pad (the test drives the same actions with
`Input.action_press`, not a device): the prompt's placement and glyphs, the
keg sliding into the barrel, the hover look, the camera sitting along the barrel while a keg
flies (it does not follow the keg), whether the marker reads from the barrel at
range, aim and power rates, the pad bindings (d-pad for power). Keg flight ignores walls
(it lands on tops only) and matches the pilot's to a few cm in the test at 60
fps. Headless only.

## Next steps

A camera follow for the keg; kegs exploding near fire; firing objects instead
of yourself; broken cannons; a hold-to-charge power as an alternative; real
sounds and a muzzle flash; generated isles with tiered keg placement.

# Cannon, round 1 (greybox, reworked 2026-10-12, round 3: operated from outside)

> Branch `feature/cannon` (round 3: `feature/cannon-outside`). A Mario-style
> cannon that launches the pilot. Firing yourself is free and the cannon is
> always usable. Powder kegs are scarce **ranging shots**: you work the
> cannon from outside like artillery, fire a keg to see where it lands,
> adjust, fire another; then climb in and launch yourself at the aim and
> power you tested. (Round 1 had kegs as ammunition; round 2 put the pilot
> inside the barrel to fire kegs from there. The user, on both: "I don't
> want to load myself and the keg. I just want to be able to stand outside
> the cannon, load the kegs, launch the kegs, and then be like, okay, now
> I'll launch myself.")

## Controls (all through the game's pad layer, scripts/pad.gd actions)

Picking up: walk onto a keg; it hovers behind you like a carried plane part
(max 3, no penalty to the tech).

**On foot at a cannon** (within `enter_reach`, on the ground)

| Pad | Keys | Action | Does |
|---|---|---|---|
| A | Space | `walk_jump` | start operating it from outside (he does not jump) |
| Y | F | `cannon_climb` | climb straight into the barrel |

**Operating, from outside** (he stands on the ground behind the base, at the breech, and keeps there as the barrel turns)

| Pad | Keys | Action | Does |
|---|---|---|---|
| left stick | WASD | `move_*` | turn the barrel left/right, pitch it (forward = up) |
| d-pad (right/up, left/down) | . , | `cannon_power_up/down` | power, 5 notches |
| A | Space | `walk_jump` | fire a keg: the next one slides from his hover into the barrel (0.35 s, seen) and is fired; with none, a dry click |
| Y | F | `cannon_climb` | climb in (to launch yourself) |
| B | E | `cannon_leave` | step away |

**Inside the barrel**

| Pad | Keys | Action | Does |
|---|---|---|---|
| A | Space | `walk_jump` | launch yourself, at the aim and power last set (what the keg showed) |
| B | E | `cannon_leave` | climb back out, operating again; nothing fired |
| stick, d-pad | | | nothing: what you tested is what you get; to change it, climb out |

The prompt line (PadPrompt; on a pad its glyphs, drawn from each action's
binding, so a remap follows) always names each button for the mode, the
kegs in hand and the power notch:

- by it: "{A} operate the cannon · {Y} climb in · 3 kegs · power 3/5"
- operating: "{LS} aim · {DPAD} power 3/5 · {A} fire a keg (3 left) · {Y} climb in · {B} step away";
  with none "{A} fire a keg (none left)"; while a keg slides in, "loading a keg..."
- inside: "{A} launch yourself · {B} climb out · aim and power 3/5 as tested · 1 keg"

### Why this map

- **A is the one "do it" button**, as the pad uses it everywhere: by the
  cannon it starts operating, operating it fires a keg, inside it fires
  you. Loading and firing a keg are one press (load seen, then fire): the
  user wants "load the keg in, launch the keg", and a separate load button
  (round 2's X) was a press with nothing to decide. Nothing else is on A, so
  A can never launch him from outside.
- **Y to climb in** is a separate, deliberate button, so a keg shot can never
  turn into a self-launch by a double tap. Y is free on foot (the plane's
  "land" is in the plane only).
  Y by a cannon climbs straight in for a player who already knows the shot.
- **B is back**, one level each press: inside -> operating -> on foot. Same
  as B everywhere else in the game (step out, put down).
- **Stick aims, d-pad power**: the stick is analog and already under the
  thumb; power is in notches so the d-pad's clicks fit (kept from round 2).
- **One thing per press**: the field reads every button's edge itself, from
  the InputMap, before the motor steps, in one `match` per mode with `elif`s;
  while he is at a cannon the field is the motor's `rider`, so the motor's own
  jump press is ignored (the A that starts operating does not jump). His own
  launch is fired *after* the motor's step, so that step has already taken
  A as held: the launching A does not also open the sail (the test checks).
  While a keg is loading, A, Y and B are ignored.

### The camera

While he is at the cannon (operating or inside) the field takes the camera
over (`frame(camera, delta)`, called by the character study after its own
camera; eased in and out over the chase camera in `view_ease`): it stands
behind and over the cannon (`view_back`, `view_up`) looking down the barrel
(`view_ahead` past the mouth). A fired keg is followed (the camera looks at
it), and when it comes down the view holds on the marker for `view_hold`
s, then eases back down the barrel. The eye rises with the range of what it
looks at (`view_rise` per metre), so the arc and a far marker both stay in
view. Fired, the camera eases back to the chase camera, turned the way he
was fired.

- A keg lands: orange ring and column until `R`, a thud. Into the void: a grey
  puff where it crossed the cannon's height, a "lost" sound.
- No arc preview. Reading the keg's flight is the skill.
- Fired, you leave by `PilotMotor.toss` (no tumble, sail ready, some steering).
- `R` resets (kegs back, markers cleared, cannons at rest aim and empty).

### Why the kegs did nothing on a pad (round 2)

The keg and climb-in buttons polled raw `Input.is_joy_button_pressed(0, ...)`
and physical keys outside the game's pad layer. Since round 2 every read is
an InputMap action from `Pad.ACTIONS` (`walk_jump`, `cannon_climb`,
`cannon_leave`, `cannon_power_up/down`), with edges taken in the field.
(Round 3 dropped round 2's `cannon_load`, X.)

## Parts

- `scripts/carried_follow.gd`: the hover extracted from `plane_arc.gd` (the
  plane arc calls it with the same numbers; test_plane_arc passes).
- `scripts/cannon/keg.gd` (one kind: the two sizes no longer set any power),
  `cannon.gd` (barrel, aim, power, `flight`/`landing`/`landing_for` simulation),
  `cannon_field.gd` (the `foot_pieces` hook; the motor's `rider` while at a
  cannon; the modes, loads, flies the kegs, lays the markers, the camera, the
  prompt). `studies/character_study.gd` calls a foot piece's `frame` after
  its own camera, if it has one.
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
| enter_reach | unit x 2.4 (operate or climb in from this far) |
| stand_back | unit x 1.35 (where he stands to operate, from the base's middle; the base is unit x 1.6 wide) |
| field: max_kegs, pick_reach, carry_share, marker_height, load_time | 3, 1.3 m, 0.55, 3 m, 0.35 s |
| field camera: view_back, view_up, view_ahead (units) | 4.5, 2.4, 6 |
| field camera: view_ease, view_hold (s), view_rise (per m of range) | 0.3, 1.6, 0.12 |

## Unverified

Headless only (`tests/test_cannon.gd` drives the InputMap actions with
`Input.action_press`, as the pad layer's bindings emit them, not a real
device). Not seen on a screen or a real pad:

- **The camera.** The test only checks that it stands behind and over the
  cannon and points at the keg in flight; whether the framing reads (the
  arc, the landing at range, the hold on the marker, the eye's rise, the
  ease in and out and the hand-back when fired) is unjudged. It may clip
  into scenery (it has no collision pull-in), and a very high pitch looks
  mostly at sky.
- The prompt's placement and glyphs on screen (the test reads its pad text).
- The keg sliding from the hover into the barrel; the pilot's look standing
  at the breech (idle pose, facing down the barrel, kegs hovering behind).
- Aim and power rates on a real stick; the d-pad bindings.
- Keg flight ignores walls (it lands on tops only) and matches the pilot's
  to a few cm in the test at 60 fps.

## Next steps

Small aim tweaks inside the barrel (off by design for now); kegs exploding near fire; firing objects instead
of yourself; broken cannons; a hold-to-charge power as an alternative; real
sounds and a muzzle flash; generated isles with tiered keg placement.

# Cannon, round 1 (greybox, 2026-10-12)

> Branch `feature/cannon` (off `roguelike`). Travel first: the pilot is the
> cannonball; ammo is physical powder kegs found on isles.

## Controls

- Touch a keg: it is picked up and hovers behind you like a carried plane part.
  Up to 3. **No penalty**: the tech is not muffled.
- Walk up to an empty cannon with kegs: one goes in from the hover. The **big**
  keg first; **crouch** while approaching to load a small one first. (No target
  exists to be "enough" for, so big-first with a crouch override.)
- `E` (pad X) by a cannon: climb in (loads one too if it is empty and you carry
  kegs). Inside: stick turns the barrel left/right and pitches it, `Space`
  (pad A) fires, `E` climbs out. A dotted arc shows the first 0.75 s of flight.
- Fired: `PilotMotor.toss` (no tumble, sail ready, a little air steering);
  Space in the air opens the sail to stretch it. Empty cannon: `click`.
  One keg is one shot.
- `R` resets (kegs back, cannons empty).

## Parts

- `scripts/carried_follow.gd`: the hover (position round him, bob, ease)
  extracted from `plane_arc.gd`'s `_follow`; the plane arc calls it with the
  same numbers (its `CARRY_*` consts alias the helper's), so parts behave as
  before (test_plane_arc passes).
- `scripts/cannon/keg.gd` (small/big barrel), `cannon.gd` (barrel, aim, load,
  fire, preview; static `flight` and `reach` simulate the shot),
  `cannon_field.gd` (the `foot_pieces` hook; the motor's `rider` while inside).
- `studies/cannon_yard.gd/.tscn`: start isle (cannon + 2 small kegs + 1 big),
  near isle at a small shot's range with a second cannon and no keg, far isle at
  a big shot's range. Isle positions come from `Cannon.reach`, so they follow
  the knobs. Sounds are placeholders (`fuse`, `click`, `boom`, `pickup`, `climb`
  recorded in `heard`, signal `sounded`).

Windowed: `godot --path . res://studies/cannon_yard.tscn -- --no-title`
(`--cannon=small|big|both` starts by the cannon with those kegs in hand).
Test: `godot --headless --path . --script tests/test_cannon.gd`.

## Knobs (cannon.gd `defaults`, unit = walk x 0.5 = 1.2 m; field knobs in cannon_field.gd)

| knob | default |
|---|---|
| speed_small | run x 3.8 = 18.2 m/s (about 13.6 m across at rest aim) |
| speed_big | run x 5.4 = 25.9 m/s (about 26 m: twice a small) |
| pitch rest / min / max | 40 / 15 / 75 deg |
| yaw_limit | 70 deg either side of the cannon's heading |
| yaw_rate / pitch_rate | 1.2 / 0.9 rad/s |
| base_height, barrel_length, barrel_radius | unit x 0.75, 2.2, 0.45 |
| enter_reach | unit x 2.4 from the base's middle |
| preview_dots / preview_time | 9 / 0.75 s |
| max_kegs, pick_reach, carry_share | 3, 1.3 m, 0.55 |

## Unverified

Everything windowed: how the hover reads, the camera along the barrel, the
dotted arc's visibility, the feel of aim rates, whether the pilot hidden inside
reads, the sail stretch after a shot, whether gamepad X/A are right. Hidden
figure while aboard has no cannon-side animation. Headless only.

## Next steps

Kegs exploding near fire; firing objects instead of yourself; broken cannons
(parts to find); a keg as a thing you can set down or hand over; real sounds
and a muzzle flash; cannons in generated isles with kegs placed by a tier.

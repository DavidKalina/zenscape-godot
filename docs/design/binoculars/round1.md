# The binoculars, round 1

The pilot carries a small brass pair. Hold a button on the ground and he
raises them to his eyes. You look and zoom, an isle's card comes up when
you rest on it, and far-off unfound finds glint. Let go and he lowers them.

Branch `feature/binoculars` (on `merge/scale-into-main` plus `feature/ledger`).

## Controls

| | Keyboard / mouse | Pad |
|---|---|---|
| Raise (hold), lower (let go) | Right mouse button | LB |
| Look | Mouse | Right stick |
| Zoom | Wheel, ×1.3 a notch | LT out, RT in, smooth |
| Shuffle | WASD | Left stick |

- They only come up on foot, on the ground, standing or walking: not in a
  jump, a slide, the water, on a ledge, under the sail, off the edge, while
  holding the lodestone up, or in the plane. If one of those starts while
  they're up, they come down. If the button is still held when he lands,
  they come up.
- While they're up, jump, crouch, twirl, the updraft, boarding, picking up
  and the R3 camera reset are all ignored. He moves at 0.18 of what the
  stick asks, about 0.7 m/s.
- Right mouse and LB were both free on foot. RB is the updraft and LT is
  crouch. While the binoculars are up, crouch is off, so the triggers are
  free to zoom (they're the `zoom_out` / `zoom_in` actions the builder
  already had).
- The new action is `binoculars` in `scripts/pad.gd`. `Pad._event` now
  takes a `["mouse", button]` spec. The binding is in docs/gamepad.md, the
  foot hint, and a hint line of its own while they're up.

## How the view works

Code: `scripts/binoculars.gd` (logic) and
`shaders/binoculars_view.gdshader` (the two circles). The hooks are in
`studies/character_study.gd`, so every study and isle built on it has
them:

- **`tick` start:** `restore(camera)` puts back the chase camera's own fov.
  It does this before the updraft takes its fov kick off, in the same
  pattern the updraft uses.
- **Before the motor:** `step(delta, held, binoculars_allowed(), _yaw,
  _polar - CAM_POLAR)`.
  - On the way up, it takes the chase camera's heading and tilt. The
    camera's default tilt counts as level.
  - Then it eases `up` from 0 to 1 over 0.25 s, and reads the stick and
    triggers.
  - Then the study scales the stick and drops the moves.
- **After `_frame` and the updraft's feel:** `_binocular_view`.
  - It points the chase camera's `_yaw` / `_polar` along the binoculars,
    so lowering lands looking the same way, and turns him to face that
    way.
  - Then `view()` blends `camera.global_transform` from the chase view
    toward his eyes and the fov toward the lens's, both by
    `smoothstep(up)`.
  - The lens is `2·atan(tan(30°)/zoom)`: 2x is about 32°, 8x about 8.6°.
  - Look turns by the input divided by the zoom.
  - Sway is two slow sines per axis, 0.0035 rad.
  - The chase camera code itself isn't changed. It runs as before every
    frame, and the binoculars blend from what it made.
- **The figure:**
  - His arms lift by the same `_turn_bone` route that kit_isle's
    `_raise_arms` uses for the lodestone. The angles were found by a
    headless search: they bring his mitts to about 0.91 m, in front of his
    face.
  - A tiny pair sits between his mitts: two hexagonal brass barrels with
    dark grips and a bridge.
  - Past about 85 % of the way up, his body and the pair hide, so they
    don't fill the lens. The camera then sits at `EYE` in his frame.
- **Sound:** when the kit audio is there, a cloth rustle on raise and
  lower, a high tick on each zoom notch, and a soft tick when a card
  comes up.

## The isle card from the ground

- **Isles:**
  - `sight_isles()` lists `{middle, radius, top, isle}`.
  - The study's list is empty.
  - `kit_isle.gd` lists the isle itself.
  - `aqueduct_isle.gd` adds every motif isle that `stands()`, the same set
    and circles `lock_target` uses for the plane.
- **Picking one:** `Binoculars.pick` (static).
  - Each isle is aimed at a centre a quarter of its radius under its top.
  - Its score is the angle off the view's middle divided by the isle's
    angular radius from the eye. The lowest score under 1 wins.
  - The isle he's standing in (inside its circle) is left out. Otherwise
    looking down at your own turf would always pick it.
- **The card:**
  - After 0.5 s on the same isle, the card shows. It's its own
    `IsleSplash` and comes from `isle.isle_card()`, so the counts are the
    ledger's.
  - Its hold is set very long, so it stays while you keep looking.
  - Looking off the isle, onto another one, or lowering fades it.
- **Layers:** the overlay is CanvasLayer 3 and the card is layer 4, so the
  card draws over the circles.

## Glints: the hook

```gdscript
const Binoculars = preload("res://scripts/binoculars.gd")
Binoculars.spottable(node, "<isle>/<slug>")   # or "" for no objective
```

- **What it does:** it puts the node in the group `binocular_finds`, with
  its objective id as meta. Nothing else needs to change.
- **Who uses it:** `kit_tokens.gd` calls it for every token it lays, which
  is all 57 rune tokens across the aqueduct isle and the motif isles.
- **For a plane part:** call it on the part's node with the part's ledger
  id.
- **When a find glints:** only while the binoculars are fully up. It also
  has to be:
  - unfound (its objective not done, or no id) and visible in the tree
  - 25 to 2000 m from the eye
  - in front, inside the two circles on screen
  - with no physics hit between the eye and 1 m short of it
- **How it looks:** a small warm four-point star with a dot, drawn on the
  overlay. It twinkles on a per-find phase between 35 % and 100 %. It's
  overlay-only, so it can't show without the binoculars.

## Tests

`tests/test_binoculars.gd` (headless, about 35 s) on the aqueduct isle
with its motif isles. It checks:

- `pick` by aim
- raise and lower timing, with the camera at his eyes and the fov narrowed
- his figure hidden while they're up
- the shuffle and no jump
- the chase camera looking where they looked, with its fov back
- the bell spires' card after the dwell, counted from the ledger, held,
  fading when the view leaves and when they're lowered
- a far find glinting only while they're up, and not when near, behind,
  or found
- the tokens all listed
- look slowed by the zoom, and the zoom's range
- none in the air, up on landing with the button held, none in the plane

## What's weak

- **Nothing visual is verified.** Headless has the dummy renderer, so none
  of these have been seen:
  - the circles' look, the glint's size and subtlety
  - the arm pose and the pair in his mitts (only measured: mitts at
    ±0.08 m, 0.91 m up, 0.12 m ahead)
  - whether 0.85 is the right moment to hide his body
  - the sway's feel
- **`EYE` is a guess,** (0, 0.95, −0.08) in his frame, from the head bone
  at 0.85 m. It's not taken from the head mesh.
- **The figure's facing lags.** He turns to the look on an ease. A
  sideways shuffle pulls his facing toward his travel, so the body
  briefly fights the look. The view is unaffected.
- **The occlusion ray hits anything with collision.** That includes
  foliage colliders or a parked plane in the way. A find tucked under a
  lip is hidden, which may be right.
- **Glints read the ledger every frame** for every listed find in view.
  57 tokens is fine, but a few hundred finds would want a cache.
- **The isle you stand on never shows its card.** This is by design, but
  "check the progress card from the ground" doesn't cover the home isle.
- **Rare quit leak.** One of four `zenscape.tscn --quit-after 300` load
  checks reported 15 leaked audio playbacks at quit. That's the quit leak
  kit_audio.gd already documents; the other three were clean.

## Open questions

- Should the home isle's card show when you look down at your own ground,
  or only through the pause menu?
- Should zoom be stepped on the pad too (D-pad up/down), or is smooth on
  the triggers enough?
- Should the glint brighten as you zoom onto it, or take a dwell to "tag"
  a find (map pins, next round)?
- Should the dragon, the serpent and the passing plane be spottable as
  "things", with a glint, a soft ring or a name, or is seeing them enough?
- Should the binoculars come up from a ledge hang or the sail? Today
  they're ground only.
- Should first person start at a fixed zoom, or remember the last zoom?
  Today it remembers within a session.

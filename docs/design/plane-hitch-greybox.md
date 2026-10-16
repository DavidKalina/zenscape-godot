# Plane hitch: greybox round 1 (ground only)

On the aqueduct isle (and in the game, `studies/zenscape.tscn`), five loads
stand round the parked plane: a small crate, a big crate, and a small, a
middle and a big boulder. There is a reel on the plane's tail post. Press
**E** (pad B) to do whatever fits where you stand:

- **At a load:** tie the line on and take the other end. Walk it to the
  plane, then press E at the reel to hitch it.
- **At the reel:** take the hook, walk it out (the reel brakes you a
  little), then press E at a load to clip on.
- **Hitched, at the reel:** in crank mode, hold E to wind. Slack comes in
  fast, then the line slows as the load drags, and stalls at 6000 N. In
  pull mode, press E to unclip.
- **Hitched, at the load:** untie. Carrying, anywhere else: drop the line.

**H** switches between the two versions. `--hitch=pull|crank` picks the
starting one (crank is the default). `--no-hitch` leaves the hitch out.

- **crank:** a tied load's line pays out as you walk, so you leave slack,
  then wind it in at the reel.
- **pull:** a tied load is on a short fixed line, so you drag it to the
  plane. You're slowed by its weight (a 1800 N pull at most) and held by
  one you can't shift.

Weights: the crates and the small boulder can be dragged by hand. The
middle boulder is too heavy to drag but the winch can wind it in (slowly).
The big boulder stalls both. Hitched loads also trail behind the plane as
it taxis, and the line parts over 25 000 N.

## Code

- `scripts/interactables/plane_hitch.gd`: the line, the reel, input, UI,
  load placement. The line is a one-way spring (K 12 000 N/m) applied in
  `_physics_process`. The pilot is slowed by scaling `motor.run`/`walk`, and
  held by pulling his feet back to the line's length.
- `scripts/interactables/hitch_load.gd`: crate and boulder rigid bodies
  (layer 1, mask solid|turf).
- `scripts/interactables/foot_pieces.gd`: an additive `extras` list (each
  item gets `before`/`after`/`pose` round the motor).
- `studies/aqueduct_isle.gd`: one `build` line.

## Proof (uncommitted, in `scratch/`)

- Smoke: `zenscape.tscn` and `aqueduct_isle.tscn`, 0 errors.
- `scratch/hitch_drive.gd` (`python tools/drive.py scratch/hitch_drive.gd`):
  29/29 checks through the real loop (key events, stick actions). It covers
  crank in for the small crate and the middle boulder, a winch stall on the
  big boulder, pull-dragging the crate and small boulder to the plane and
  hitching them, the big boulder holding him, and the reel-hook flow.
- `scratch/hitch_shots.gd --rendered`: stills judged by eye.

The full test suite was not run. No existing tests are known to break: the
FootPieces change only adds to it.

## Playtest (the user, 2026-10-15)

"Kinda cool", parked on a branch. The rope kept breaking. Not yet looked
into. Three things can end the line early, and each shows its reason as a
word on screen:
- "The line tore out of your hands": in `_carry`, the tie point and the
  hand more than 2.5 m apart in height while the line is taut. This likely
  fires on slopes and tiers.
- "The line parted": over `SNAP` (25 000 N) while hitched to the plane.
- "The load fell away": the load dropped below the isle's lost height.

## Not done, and open

- There's no pilot animation for cranking or hauling. Dragging only leans
  his body a little toward the load.
- The plane doesn't feel the load (a hitched load doesn't slow its taxi).
  Flying with a load is round 2.
- Loads collide with the parked plane's column but not with the walker's
  body. They can pass through him.
- The line sags as a parabola and lies on the ground, but it doesn't wrap
  around obstacles.
- Model budget: these are greybox primitives (crates ~84 tris, boulders
  ~60). The rope reuses the swing rope mesh, 20 segments × 288 tris ≈ 5.8k.
  A 3-sided or 12-band segment would cut that by 4x, about 4k tris saved.
  The cost is negligible at one line.
- The harness lacks a way to press a non-movement key through the input
  path. The driver sends `InputEventKey`s by hand.

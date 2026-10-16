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

"Kinda cool", parked on a branch. The rope kept breaking while flying:
you can't carry a load off with the plane. That is `SNAP` (25 000 N) on
takeoff, and every load hits it. The plane is an anchor that doesn't feel
the load, moving at flight speed, so the stiff line (K 12 000 N/m, tuned
for dragging on the ground) jerks the load from rest to flight speed in a
fraction of a second. Even the small crate needs ~2 m of stretch, ~24 000 N.
Round 2 is carrying in flight.

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

## Round 2: carrying a load in flight

Hitch a load, board (Space), roll off the edge, and it comes with you.
There are no new keys or flags. `--no-hitch` still leaves it all out.

- **The plane feels the line.** `SkyPlane.tow` (m/s², zero by default, so
  every other scene flies as before) is the line's pull over `PLANE_HEFT`.
  The share along the path slows or speeds the plane. The rest knocks it
  off its path (`tow_drift`), and the wings take that back over
  `TOW_SETTLE` (0.5 s), so a load hanging below is a steady sink.
  `ManualLanding` adds the pull to the ground roll (never rolling it
  backwards) and to the dip off the edge.
- **The reel slips.** In the plane (on its wheels or flying) a pull over
  `BRAKE` pays out line until the stretch holds just the brake's pull, up
  to `MAX_LINE` (40 m). So takeoff is a lurch. Only at full line can the
  pull reach `SNAP` and part it. The readout shows "reel slipping" and the
  line paid out.
- **An air line.** In the plane the line is `K_AIR` (3000 N/m, softer than
  the ground's 12 000), damped against the plane's real velocity (round 1
  used zero for the plane end, which added drag while taxiing). The load
  gets air drag (`AIR_DRAG`), and is kept awake. The line is drawn
  `AIR_THIN` thick.
- **Loads off layer 1 in the plane.** Otherwise the plane's stone checks
  (`roll_blocked`, bumps) treat its own load as stone. Back on foot they
  return to layer 1.
- **Set down.** A load hung from the plane on a taut line isn't "lost"
  below the isle. After landing it hangs off the edge until he cranks it
  up.
- Off the plane, on foot, round 1's K, SNAP, crank and drag are untouched.

Constants (`plane_hitch.gd`): `BRAKE` 6000 N, `K_AIR` 3000, `PLANE_HEFT`
900 (N per m/s²), `AIR_DRAG` 0.6, `AIR_THIN` 0.55. In `sky_plane.gd`:
`TOW_SETTLE` 0.5.

**The big boulder can't be lifted.** On the wheels, the brake's pull
straight back (6000/900 = 6.7 m/s²) beats the throttle's push (4.5 m/s²).
So the reel pays out while the plane creeps, and then the plane is held
on the turf. I chose this over parting because the brake already caps the
pull: the plane simply can't drag 1800 kg, and the pilot can see the reel
slipping on the readout. If he does get airborne with it (the pull came
from the side, which the wheels shed), it parts at full line.

### Proof (uncommitted, `scratch/hitch_fly.gd`)

`python tools/drive.py scratch/hitch_fly.gd -- --load=<kind> --wind=3`
(`--bare` for no load, `--shots` with `--rendered`). The run goes through
the real input: E key events to tie, hitch and crank it to 3 m, Space to
board, `fly_boost` held to roll off the edge, the stick to climb 2.5 s,
then 10 s level, then the stick to fly back, brake and flaps, F to get
out, and E to untie.

| load | line held | peak N | paid out | climb peak m/s | mean speed | height over 12.5 s |
|---|---|---|---|---|---|---|
| none | – | – | – | 11.2 | 14.3 | +31.9 |
| crate_small 35 kg | yes | 6000 (brake) | 0.0 m | 10.2 | 13.9 | +28.7 |
| crate_big 110 kg | yes | 6000 | 0.8 m | 8.8 | 13.1 | +18.1 |
| boulder_small 150 kg | yes | 6000 | 3.3 m | 8.6 | 13.2 | +19.2 |
| boulder_mid 380 kg | yes | 6000 | 26 m | 7.4 | 13.6 | −12.8 |
| boulder_big 1800 kg | held on turf | 6000 | 17.6 m | – | – | – |

The crates and the small boulder land with the load (firm touch, the load
on the turf), are untied on foot and pass every check. The middle boulder
sinks the plane. Its long line has it hanging 34 m under the ring after a
hard touch. He cranks it up (98 s of cranking), but it ends hanging at the
lip below the plane, and the untie can't reach it (open). Round 1's
`scratch/hitch_drive.gd` passes 29/29. The smoke check passes, 0 errors.

Stills: `captures/hitch/2b_side.png` and `3b_side_close.png` (side
cameras), `2_cruise.png` and `3_cruise_late.png` (chase camera),
`4_landed.png`.

### Open

- **Snags.** Dragged across the turf behind the taxiing plane, a load can
  catch on stone. The crate stopped dead on an aqueduct pier 2.7 m beside
  the plane's run. The reel then pays out to 40 m and the line parts. A
  load cranked in close trails in the plane's own run and doesn't snag.
  The 8 m line in the test snagged and parted.
- In the chase camera the load hangs below and behind, under the eye, so
  it is mostly out of view (the side stills show it). The camera hasn't
  been changed.
- On a 3 m line the load can bob 1–2.5 m above the ring when the nose
  drops. It passes through the plane figure (no collision).
- There's no reel-in in the air. A big snatch leaves a long line, which
  needs a high approach.
- A load hanging off the lip after landing can't be untied (the reach is
  from the hand).
- No existing tests are known to break: the tow is zero unless the hitch
  sets it. The full suite was not run.

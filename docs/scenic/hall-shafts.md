# Hall light shafts

A beam of sunlight through a broken roof into a dark nave, with dust hanging
in it. Rare and hard: a beam needs darkness round it to read.

## What changed

- `scripts/hall_shafts.gd` (placement and build, worker side),
  `scripts/hall_shafts_director.gd` (one a line: wake trail, flare),
  `shaders/hall_shaft_beam.gdshader`, `hall_shaft_dust.gdshader`,
  `hall_shaft_flare.gdshader`.
- Hooks: `hall_line_build.gd` (one call after `SunderedBuild.near`, plus a
  `shafts` count in the made dict), `hall_line.gd` (create the director in
  `configure`, `tick` it in `advance`).

## Placement

From the bay plans' roof state (`HallShafts.openings`): only a `broken` bay,
never an end bay or torn, never beside an `open` bay, with at least
`MIN_DARK` (1) `whole` bays within two either side. At most `MOST_BEAMS` (2)
a piece, never in adjacent bays, best-dark bays first (seeded). A bay's beam
is its largest `weave.gaps` opening, so its edges are the real light's. In
practice: slit and nave pieces get 1-2, shafts pieces mostly none, cloisters
none.

## Light and look

- Direction and strength are read on the GPU from the celestial rig's
  `zs_key_direction` / `zs_key_irradiance` / `zs_celestial_clear`, so the day
  clock re-aims the beams with no CPU work; they fade with sun height,
  cloud and night (moonlight gives a faint beam). The director reads the
  same values from the isle study's `_celestial.state` (the globals cannot be
  read back at run time).
- Beams: one mesh a piece of slanted walls (vertex shear along the light),
  noise streaks scrolling down, edges faded by view angle, soft against scene
  depth, warm and brighter looking into the sun.
- Dust: one MultiMesh a piece, motes placed in the beam in the vertex stage,
  sinking slowly; the plane's last 8 places (0.2 s apart) are a wake trail
  uniform: motes near it are pushed out, swirled and dragged, settling over
  about 2 s.
- Flare: a full-screen additive canvas layer (-1, under the HUD), warm and
  sun-side. It is mostly the step into the light (an adaptation low-pass),
  plus a faint warmth while inside. Driven by the camera and the plane
  against every beam's slant.
- Built on the worker under the piece's `Near` node: freed with the piece,
  hidden with it when the far mesh takes over. No collision.

## Knobs

`--hall-shafts=0` off. `--hall-shafts-gain=<x>` beam and dust brightness (1),
`--hall-shafts-dust=<x>` mote count (1; 0 none), `--hall-shafts-flare=<x>`
(1; 0 no canvas layer). Constants: `MOST_BEAMS`, `MIN_DARK`, `MOTE_DENSITY`,
`MOTES` in `hall_shafts.gd`; `FLARE`, `ADAPT` in the director.

## Cost

Rendered, in a bay with beams, on this PC (autopilot, window default):
GPU 3.93 ms on vs 3.79 ms off (+0.14 ms), CPU 0.68 vs 0.56 ms, draws +2.5,
triangles about +500. Worker build adds well under a millisecond a piece.
With the earlier dense placement (8 beams) it was +0.2 ms. Technique:
additive beam meshes plus billboarded motes in one draw each; fog volumes
were not tried (they cost per-froxel across the whole view).

## See it

`python tools/godot.py --rendered studies/aqueduct_isle.tscn -- --no-title --near-ring --autopilot`
(pieces 1 and 8 are slit pieces with beams; flight reaches piece 1 about
a minute in). Compare with `--hall-shafts=0`.

## Existing tests

None found that touch this; `LineBuild.build`'s result gains a `shafts`
key. Not run: the full suite. Unverified: the flare while the plane itself
flies through a beam (the autopilot's lane mostly misses the beam; the
camera's edge-catch was seen), and day-clock re-aiming at dusk (the shader
reads the live globals, not exercised over a day).

## Polish round (soft volume, fine dust, fly-through)

- Beams are now a fake volume. The mesh is a closed prism per beam
  (`_beam_mesh`: 8 corners, roof four plus four sheared down the light);
  `hall_shaft_beam.gdshader` draws only its back faces (`cull_front`,
  `depth_test_disabled`) and each pixel integrates light along the whole view
  ray through the box (6 jittered steps, ray cut by scene depth). Density thins
  smoothly toward the sides (`edge_soft`, a part of the beam's width), fades up
  into the roof and down toward the floor, is ignored right round the eye
  (smoothstep 1.5-12 m), and a ray lights at most `path_cap` (11 m) from where
  it enters, so a ray running along a side no longer draws a line. The old
  glass-card edges are gone at every angle and from inside.
- Dust: specks 1.2-5 cm (min about 1.7 px, dimmer as they shrink), mostly a
  faint 0.22 glow with sharp glints, shown only while inside the beam's column
  (`lit`, tested in the vertex stage, so wake-stirred motes fade as they leave
  it). More of them: `MOTE_DENSITY` 3.2, `MOTES` (60, 320).
- Knobs: `edge_soft` 0.32, `path_cap` 11, `per_metre` 0.11 and the 0.5 ceiling
  and x2.4 gain in the beam shader's end; dust gain x6 and size floor 0.003.
- Fly-through: the plane was flown by the real stick (turn from the lane's own
  steering, pitch to hold 6.5 m above the nave floor), day clock frozen at
  phase 0.68 so the light slants along the lane. Entering, inside and past
  read as soft light; no pop or wash-out seen. The flare is faint (sun is
  behind the chase camera there). Dust swirl in the wake is too fine to judge
  in stills: unverified by eye.
- Cost (this PC, rendered, piece 1, clock frozen phase 0.4): shafts off GPU
  4.22 ms; before this round 4.21; after 4.87 ms median (5.69 mean, spiky),
  CPU 0.63 vs 0.57. The disabled depth test makes the beam draw its whole
  prism's back faces even behind geometry. Worth a follow-up if it matters
  (cheaper: fewer steps, or depth test back on with a cap fix).
- Unfinished: cost trim above; sunset/other-phase look not re-checked.

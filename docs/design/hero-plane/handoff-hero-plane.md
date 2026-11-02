# Hero plane: handoff

The wanderer's plane is an authored, painted model, and its title idle is an
engine that starts and runs. Spec: `spec-hero-plane.md`. Trail:
`git log --grep='^ITER(hero-plane)'`.

## What's built

- **Model:** `art/blender/hero_plane/` (`hero_plane_build.py`, and
  `hero_plane_paint.py` for the numpy atlas) exports to
  `assets/models/hero_plane/`. A radial-engined biplane on the old figure's
  holds. 14 surfaces, 21,994 triangles with the blades hidden. Re-run the build
  with `tools/blender.py`, then import by hand
  (`python3 tools/godot.py --import`): smoke and drive don't reimport the glb,
  and show the old mesh with no error.
- **Figure:** `scripts/plane_figure.gd` builds the model for the wanderer (no
  livery). Traffic keeps the old code-built figure. `repaint(livery)` is new;
  `shop_stock._paint` calls it.
- **Idle:** `scripts/plane_idle.gd`: a start-up keyed to `engine-start.wav`'s
  bursts, parts on springs stepped at 240 Hz off time, noise under 9 Hz.
  `scripts/plane_exhaust.gd` holds the wisps and heat haze.
- **Light:** `hero_surface` has `shade_lift`, easing with `zs_daylight` and with
  a `roof` uniform under stone. In a bore the model takes the bore's render
  layer.
- **Prop disc:** `shaders/prop_blur.gdshader` is rewritten, and traffic shares it.
- **Wires:** `hero_wire.gdshader` holds each at 1.5 px and fades by coverage.
- **Grass:** `scripts/endless/grass_react.gd` and
  `shaders/grass_react_stamp.gdshader` have calm stamps, so held air holds.
  `EASE` 3.5 is the knob.

Tunable first: `shade_lift`, `shade_night` and `fill_night` in the build's shader
strings; `PART_SPANS` for the title's parted grass; `EASE` for the grass's
return.

## What's stood in

The name WANDERER and the number 27 on the fuselage were chosen by an agent.

## What's open

Nobody has watched the motion at full speed or heard it. Judge by playing:

- The prop at idle: blades or flicker. Each 60 fps frame draws two 48 degree
  sectors, repeating about every 4 frames.
- The start-up's picture against its sound.
- The heat haze moving, and the instant sun cut at a bore's mouth.
- The rear still doesn't read as one mass of colour at chase as the old plane's
  did.

Not checked:

- A flight the user flew, with the frame log; frame cost on the PC. Mac driven
  runs showed no cost within their 3 to 5 ms spread.
- Under arches and rock overhangs (code path only); flying out of a bore's
  mouth (tested by lifting the plane out).
- `desert_afternoon`'s still, and `rosewater_dusk` on the final shader.
- The title's parted grass was seen at one orbit phase.
- Grass: a real touchdown; one point ahead of the parked nose still reads -1.02
  on the roll, read as the direction turning rather than ring, not isolated.
- On the wheels the chase eye sits deep in tall grass, as it did before.

## Tests

No committed tests were added. `test_glide_camera` and `test_world_scale_guard`
pass. `test_sky_plane` fails its two "little hop" checks, the same as main before
this work. `test_ruin_kit` printed 48 FAIL lines on kit pieces, none on the plane,
the same 48 main printed before timing out at 180 s. The full suite wasn't run.

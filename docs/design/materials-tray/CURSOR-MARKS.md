# In-hand ground marks (cursor sketches)

The build of Claude Design's HUD 4b "Cursor (ghost hand) per held item": a
faint cream mark on the land under the ghost hand, sketching what a press
there will touch. The 3D ghost hand stays the cursor. There is no 2D icon
cursor, and the tool props belong to each tool's own work.

| In hand | Mark | Size at 1× (terrain metres) |
|---|---|---|
| Hand | soft stitched loop, faint fill | radius = land_clay `RUB_RADIUS` (1.6), the thumb's rub; groove half-width 1.35, palm 2.0, pinch from 2.2 |
| Paddle | wide stitched ellipse, long across the view | `PADDLE_HALF` 3.0 × 1.5 (placeholder, the design's 180×54 against the hand's 96×58) |
| Chisel | hard square, one **solid** line, in the plane of the face, squared to its fall line | `CHISEL_HALF` 0.8 (placeholder) |
| Wire | a toggle dot on hover; while dragged, a 2 px line from the press to the pointer with a toggle at each end | the drag itself |
| Hammer | small stitched ring and six scree specks fanned downhill | `HAMMER_RADIUS` 0.9, `SCREE` (placeholder) |
| Material | dotted drop ring under the carried item | hand_materials `SCATTER` spread (flowers 0.75, dandelion 0.9, reeds 0.4, never under `MATERIAL_MIN` 0.45); seeds 1.3, water 1.0, stone 0.45 (`MATERIAL_RADIUS`) |

Every size is multiplied by the roll's size (0.6×, 1×, 1.5×). Chisel, wire and
hammer can't be picked in play yet (`tool_roll.gd` `UNBUILT`). Their marks
exist, and the probe selects them by setting `roll.tool`. The wire has no verb
yet, so its drag shows during the clay's own `land` hold (`WIRE_HOLDS`).

## Where the build departs from the design: faint

The design draws the marks in cream at .85–.95 alpha. The user turned down
outcome-previewing ground outlines as "hand holdy" (the promise marks, now
behind `--show-promise`). They agreed to these marks only in a quiet form:

- Line at `LINE_ALPHA` 0.3 and the hand's fill at `FILL_ALPHA` 0.05.
  `FAINT_CAP` 0.4 is the probe's ceiling for any of them.
- The mark fades in over `FADE_IN` (0.2 s), and only while the hand hovers the
  land with nothing pressed. It fades out over `FADE_OUT` (0.12 s) once a
  press, drag or pinch starts.
- The one exception is the wire's line (`WIRE_ALPHA` 0.3). It is the drag's
  own preview, so it shows during its drag.
- The mark has no bob, pulse or loop, and holds still while it shows.
- It never shows over the materials bar or the tool roll, over the void or
  sky, while the camera moves, or when a prop, tree or resident is under the
  pointer.
- Night dims the cream by `NIGHT_DIM`, so the mark doesn't glow in the dark.

## How it is drawn

`scripts/ground_marks.gd` places one box decal (`shaders/ground_mark.gdshader`).
The shader reads the depth buffer back to the ground, as the pollen footprint
does, so the mark lies on the terrain's facets. It doesn't paint above
`CEILING_LIFT` over the highest ground under the mark, which keeps trees and
props clean. The mark's shapes are in world metres. Line widths (`LINE_PX`
1.5, `WIRE_PX` 2), dots (`DOT_PX`, `TOGGLE_PX`) and the stitch's anti-aliasing
are in screen pixels, read from the ground's derivatives, so the lines stay
crisp at any zoom. The stitches (`STITCH_METRES` 0.42, `STITCH_DUTY` 0.55)
echo the linen hem and always close the loop evenly. The shader uses
premultiplied alpha with `fog_disabled`, so fog doesn't paint the box.

The API is `update(kind, point, size_scale, delta, from = null)` and
`hide(delta)`. `step(delta)` reads the hand each frame and picks between them.
scripts/hand_reach.gd creates the marks with the tray and calls `step` right
after `materials.step`.

## Checks

```sh
godot --headless --fixed-fps 60 --path . -s res://tools/probe_ground_marks.gd -- --no-title
godot --headless --path . --script tools/check_shaders.gd   # grep SHADER ERROR
```

Headless draws nothing, so the probe checks only what the mark is told to
draw. Still unverified on screen:

- the whole look: the stitch, the faintness, and the cream against grass, rock
  and snow
- whether the depth read lands cleanly on facets and water edges
- the pixel widths
- the GPU compile. `check_shaders` misses GPU limits and some semantic
  errors, so run a short windowed compile check before merging.

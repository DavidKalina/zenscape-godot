# Handoff: the water look (sea, lakes, river read as liquid)

Prototype round, 2026-11-25. Branch `worktree-agent-a63290ba50b0e4d5f`.
`--water-look=0` brings back the old look; the default is the new one.

## The cause, and the evidence

The water's body was lit as an opaque solid, not seen as a liquid:

1. **Sun-lit ripples (`body_shade`, `river_body_shade`).** Both shaders
   brightened or darkened the water body by `dot(normal, sun)` × 2 to 2.5,
   up to ±45-50%, through the fine chop as well. That is a solid's Lambert
   shading: the ripples read as lumps in a cast. A matched A/B (the same
   frame, one uniform changed: `scratch/water/sheet_ab2c.png`,
   `sheet_ab3_rivz.png`) shows the river and pond lose their hammered,
   gel-like relief with this term off.
2. **A soft sun path off the rippled normal.** `zs_lake_glint`'s path lobe
   (pow 96, about 8°) on a normal carrying 70% of the chop painted wide,
   soft white blobs: a glossy gel's sheen. With `glint_share` 0 the blobs go
   (`sheet_ab2.png`).
3. **A bright, milky body.** `water_light` 2.6 and a saturated
   `tint_shallow` made the shallows an opaque pale turquoise.
4. **The dotted rings** in the coast lagoon are the ground shader's lily
   pads (`river_pads`) on a river mouth's still pool, about 0.6 m across,
   in rows: from the air they read as decals.

The scout's suspect, the simplex noise chop, is not what draws the sea
in a rendered run. With the FFT on (the default when there is a rendering
device), the sea's fine normals come from the FFT cascades, and the noise
chop runs only headless or with `--sea-fft=0`. The river still uses the
noise maps for its largest ripple layer.

## What changed (swaps, no new passes or targets)

Sea (`shaders/endless_sea.gdshader`, knobs in `EndlessSea.WATER_LOOK`):
- `body_shade_fine` 0: the sun light falls on the swell's faces only, not
  the chop. `body_shade` is 0.6.
- `view_shade` 1.2 (new): the ripples show by the eye's side of them. Faces
  tilted away from the eye are lighter, because they see the paler low sky
  in the mirror, and faces turned to it are darker. It fades out between
  `view_fade` 120 and 450 m, so far water calms to a mirror.
- `path_break` 1 (new) with `path_share` 0: the sun's path is an envelope
  off the swell, broken into the chop's facets that catch the sun
  (`smoothstep(0.99, 0.998)` of the full normal).
- `calm_share` 1: the mirror follows the full normal.
- `water_light` 1.7.
- `tint_shallow` is (0.40, 0.76, 0.73), down from (0.42, 0.90, 0.82). The
  river copies it.

River, ponds and lakes (`shaders/endless_ground.gdshader`, knobs in
`EndlessLook.RIVER_LOOK`):
- `river_stretch` (2.5, 1.2) (new): the live ripple layers, noise and FFT,
  are sampled in a frame stretched up to 3.5 times along the current, so
  running water streaks down the flow. The slope is mapped back through
  the same matrix.
- `river_view_shade` 1 (new) and `river_body_shade` 0.2.
- `river_path_break` 1 (new): the path off a flatter normal, broken into facets.
- `river_light` 1.7, `river_calm` 1.
- `river_bank_mirror` (4.0, 1.0), `river_fresnel` (0.14, 2.2): a darker band
  of bank in the mirror under the far bank.
- `river_pad_mouth` 1 (new): no lily pads on a river mouth's still pool by
  the sea (`r_tint`). Upland ponds keep them.

To tune a knob by hand: `--sea-set=view_shade:1.5` and `--river-knob=river_stretch=Vector2(3,1)`.

## Sheets and films (all in this worktree's `scratch/water/`)

- `final_coast.png`, `final_river.png`, `final_cruise.png`, `final_high.png`:
  old and new from separate runs at the default hour.
- Matched old/new, the same frame: `sheet_h17.5_{coast,cruise,river}.png` (sun low),
  `sheet_h7_*.png` (morning), and `ab7_12.5/` and `ab8/` (noon, with the
  `view_shade` strengths tried). `sheet_ab8_rivz.png` is the river close.
- Films, old left and new right, 3 s at 30 fps: `film_coast_old_new.mp4`,
  `film_river_old_new.mp4`, `film_cruise_old_new.mp4`. Time strips:
  `strip_*.png`.
- Drivers: `scratch/water/ab.gd` (matched A/B: a uniform set per variant in
  the same frame; `old.txt` holds the old look's values), `film.gd`.

## Frame time (look_views --time=240, 1440x900, median ms)

| run | coast | cruise |
|---|---|---|
| old a | 24.41 | 26.65 |
| new a | 24.51 | 26.91 |
| old c | 29.98 | 26.06 |
| new c | 24.55 | 26.18 |
| old d | 26.03 | 25.97 |
| new d | 26.24 | 26.08 |

These are the same within noise. A second four-view pass (run b) was
disturbed by other load, 25-31 ms both ways. The cost is a few ALU ops a
pixel, with no new texture reads.

## Tests at risk

No test refers to the uniforms touched, `endless_sea`, `EndlessSea` or
`endless_ground`'s river knobs; I grepped `tests/`. The full suite was not
run. A GPU test that reads the colour of water pixels would see the darker,
less green water.

## Not done, and next steps

- Motion is judged from the films only: the river's flow layers still
  cross-fade in place (`zs_live_flow`'s two copies), and the user should
  judge whether that pulses.
- The pond in `cruise` has pale diagonal slashes, a few metres long, that
  this round did not touch (live foam or eddy lines, it seems).
- The sea's lagoon at a low sun goes rather dark and flat. `view_shade` or
  `water_light` could lift it.
- No crest sharpening of the FFT slopes was tried. The FFT is already
  wave-shaped. The gel look came from the lighting, not from the shape.

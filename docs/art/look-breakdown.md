# Look breakdown (endless flight)

First draft. Descriptive only: how the look is made (code, each line checked
against the file) and what it measures on screen. Measured with
`tools/look_measure.py` on 10 rendered stills of main's endless flight
(seed 1, no trees, plane and HUD hidden, so the whole frame is world): seven
at the default 9.6 h (meadow low, hills, carved rock, coast and sea, river
from the air, cruise, high view) and three at 12.5 h. Dawn (6.5 h) and dusk
(18.5 h) are measured apart. Pixel classes are a rough hue/value sort, see
the tool's header; treat small shares as noisy.

## Techniques

**Ground paint.** The grass colour on the land is world-space value noise at
six scales, 900, 260, 70, 19, 5.5 and 1.4 m (`shaders/endless_ground.gdshader:329-334`;
`ep_fade`, `shaders/endless_patch.gdshaderinc:33`, fades each scale to its
mean as a pixel's footprint grows past it, so distant blotches melt rather
than shimmer). Two more layers have a defined edge, clumps of 34 m and 8 m
(`ep_patch`, `endless_patch.gdshaderinc:41`; `endless_ground.gdshader:336`),
whose edge widens to a blur with distance. Their sum picks a point on a
three-colour ramp: GREEN, toward SUNLIT or toward DEEP (`:337-338`, colours
`:180-184`), meadows pushed lusher (`:340`). A warm/cool drift from the two
broadest scales multiplies the colour by about (1.32,1.05,0.62) or
(0.80,0.97,1.16) at half strength (`:342-343`), and `ep_region`
(`endless_patch.gdshaderinc:64`) multiplies in broad hue regions (lush,
lime, sage, straw, heather; `:47-52`) at 130-380 m. The tufts read the same
noise (`scripts/endless/endless_patch.gd` mirrors it), so ground and grass
agree.

**Grass.** Tufts darken at the root and lift toward the tip, colour times a
root-to-tip gradient, with a hemisphere sky/ground fill as emission and no
light ramp (`shaders/endless_tuft_far.gdshader:113,123-125`). Dry straw flecks
come from world noise, `smoothstep(0.5,0.78,noise)` (`shaders/grass_look.gdshaderinc:61`),
and the paint is straw mixed by that, then root-dark to tip-sunlit (`:66`).

**Carved rock.** Light is stepped: the facet's own `dot(normal,sun)` goes
through a 3-step ramp with soft shoulders, then is mixed 0.7 with the smooth
value (`shaders/endless_rock.gdshaderinc:265-270`), and read off a
shadow, mid, lit colour ramp (`:273`). Each plane gets its own tone
(+/-13%) and a warm or cool lean (`:278`), and each rock drifts sandy-warm to
grey-cool (`:281`). Beds step in tone with crisp cracks between.

**Clouds.** Ray-marched volume, lumps from value noise
(`shaders/endless_cloud_march.glsl:405,416`); the composite pass colours them
with a sun and a shade colour from the sky's palette, bounce tint, a pale
"painted" ramp at night, haze share and sun glow
(`shaders/endless_cloud_composite.gdshader:59-77`).

**Sea.** Colour by depth over a ramp of four tints, shallow turquoise
(0.42,0.90,0.82), mid, deep, abyss (0.02,0.12,0.36), at 1.5, 7, 22 and 55 m
(`shaders/endless_sea.gdshader:150-154`), with absorption and a
screen-texture refraction (`:31`); swell and foam on top.

**Sky, haze and light.** Depth fog from 120 m to all-sky by 7600 m, curve
0.75, coloured by the sky's own horizon so far land goes into sky with no
line, with Godot aerial perspective at 0.35 (a bluer middle distance), and a
sun glow in the haze (`scripts/endless/endless_look.gd:56-65,158-168`). Sun
shadows reach 900 m in four splits (`:138-146`). Tonemap is ACES, white 16,
exposure from the mood (`scripts/landscape_lighting.gd:38-39`;
`endless_look.gd:221-225`), with SSAO (radius 0.65, light affect 0.12) and a
weak glow (0.12 at threshold 1.8) (`landscape_lighting.gd:41-47`). Ambient
light is off; the sky reflects, and the grass fills itself.

**Time of day and mood.** T steps the sun's hour through 6, 12, 18, 0
(`studies/celestial.gd:263-268`); L steps the nine moods
(`endless_look.gd:46`: alpine_morning, golden_meadow, ocean_light,
meadow_morning, after_the_rain, desert_afternoon, rosewater_dusk, rose_dusk,
moonlit_stillness). A mood is a palette (sky, horizon, glow, grass, water
colours), exposure 1.03 to 1.18, and ambient energy
(`scripts/scene_look_presets.gd`). The game opens on alpine_morning at 9.6 h
(`endless_look.gd:47-52`).

**Not used.** No full-screen painterly post-process: the only screen reads are
the sea's refraction and the cloud composite. The look is in the materials'
noise and ramps, not a filter.

## Measured ranges

Scale of the measure: values 0..1 on the displayed (tonemapped) picture;
HSV hue in degrees; pixel scales at 720 px wide. Ranges are min..max across
the 10 daytime stills (medians in brackets).

| Material | Value (V) p5 / p50 / p95 | Saturation (S) p50 | Hue | Lit tenth vs shaded tenth (luma) |
|---|---|---|---|---|
| Grass | 0.39-0.68 / 0.54-0.78 / 0.71-0.83 | 0.22-0.54 (0.36) | 65-89 (yellow-green, 72) | 1.2-2.1x (1.4) |
| Rock and sand | 0.33-0.68 / 0.65-0.79 / 0.82-0.89 | 0.15-0.36 | 35-50 (warm tan) | 1.3-2.9x (1.75) |
| Sky | 0.63-0.70 / 0.66-0.75 / 0.75-0.82 | 0.39-0.63 | 210-215 | 1.3-1.7x (gradient) |
| Cloud | 0.54-0.76 / 0.73-0.85 / 0.82-0.93 | 0.06-0.20 | beige, 15-25 (lit 213,205,197; shade 142,129,119) | 1.2-1.8x |
| Water | 0.38-0.75 / 0.71-0.78 / 0.76-0.89 | 0.45-0.62 (p95 up to 0.90) | 189-207 (cyan-blue) | 1.7-2.6x |

- **Shadows.** In daytime frames the darkest 1% of pixels never goes below luma
  0.21 (median 0.33); the darkest 5% never below 0.31. No daytime pixel is
  black. The shaded tenth of the grass is olive, hue 66-100, V 0.35-0.67
  (typically rgb about 117-160, 140-167, 69-111). On rock the shaded tenth is
  warm brown to violet-grey (rgb about 130,117,101 to 66,61,64); in the far
  haze it leans blue (hue 210-233, e.g. 49,50,62). Lit sides go to cream:
  grass rgb about 181-205, 195-212, 109-168; rock about 216-221,208-218,194-205.
- **Contrast.** Lit versus shaded is soft: grass 1.2 to 2.1x in luma, rock up to
  2.9x, whole-frame luma p5..p99 about 0.41..0.85.
- **Blotch scale.** Block-mean luma spread, as a share of the 1 px spread: for
  grass 0.92 at 2 px, 0.82 at 4, 0.75 at 8, 0.60 at 16 and 0.42 at 32 px (the
  last in the 4 stills with enough open grass). So grass variance sits in
  fine speckle plus patches 8 to 32 px across (about 1 to 4 percent of the
  picture's width), with a smooth gradient to the horizon. Water 0.82 at 8 px,
  sky 0.91 at 8 and 0.81 at 32.
- **Edge softness.** Luma gradient per px at 720 wide: grass median 0.01-0.04,
  90th percentile 0.03-0.09, hard-edge share (over 0.08) median 2 percent;
  rock 90th percentile 0.03-0.12, median hard share 4 percent (up to 21%
  where cliff planes meet); sky 0.000-0.004; water 90th percentile 0.01-0.07.
  Hard edges are rare and belong to rock planes, shorelines and flowers.
- **Aerial perspective (grass, nearest quarter of the rows to farthest).**
  Saturation falls and value rises toward the horizon in most frames:
  saturation change -0.10..+0.06, value change -0.24..+0.14 (a low sun or a
  dark foreground can reverse it, e.g. low meadow: V 0.48 near, 0.62 far, S
  0.58 to 0.48), hue moves -17..+11 degrees, no consistent direction. The haze share is large near cliffs and over the sea: the foggy
  near field in the coast still is the lightest grass (V 0.76).
- **Dominant colours.** Grass: mid yellow-green (hue ~67-82, S 0.0-0.67, V 0.5-1.0).
  Sky: S 0.33-0.67 blue at hue ~217 with a paler band toward the horizon (hue
  ~202). Water: three bands at hue 202/217, V 0.5-1.0. Rock: tan to cream
  (hue 37-52, S under 0.33).
- **Dawn and dusk** (6.5 h, 18.5 h), whole frame, luma p1 / p50 / p99: dawn
  0.07-0.22 / 0.30-0.46 / 0.70-0.88, dusk 0.08-0.22 / 0.16-0.39 / 0.61-0.80.
  Their darkest 2 percent is navy to violet (rgb 43,54,83; 23,26,56; 56,54,74)
  or, over grass, near black green (13,20,9). Midday blacks never get that
  dark.

## Example stills (committed in `docs/art/look-breakdown/`)

- `meadow_low.jpg`: 5 m over a meadow, tall tufts and stream, 9.6 h. Fine
  speckle and patches at ground level.
- `cruise.jpg`: 45 m cruise over meadow, flower drifts, distant range under
  haze, 9.6 h.
- `high.jpg`: 260 m looking down: broad colour regions, river, lakes, flower
  drifts; the 70 to 260 m scales read.
- `hills.jpg`: ridge with carved rock faces, grass to the rock's edge, 9.6 h.
- `rock.jpg`: close carved cliff, stepped light, per-plane warm and cool tone.
- `coast_h12.5.jpg`: coast and sea at 12.5 h: depth ramp turquoise to deep
  blue, cream beach, aerial haze on the near grass.
- `cruise_h6.5.jpg`: the same cruise at dawn.
- `coast_h18.5.jpg`: the same coast at dusk: blue-violet shadows.

## Reproduce

Stills: `python tools/drive.py tools/harness/look_views.gd --rendered -- --views=meadow_low,hills,rock,coast,river,cruise,high --out=DIR --scene-args --no-title [--hour=12.5]`
(the spots are seed 1; names in the driver). Ranges: `python tools/look_measure.py --build-ranges DIR/*.png`.
The ranges file holds the 10 daytime stills' measures; the committed jpgs
are only examples.

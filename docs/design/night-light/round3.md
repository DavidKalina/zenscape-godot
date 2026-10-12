# Night light, round 3

Branch `look/night-light-3`, off `look/night-light-2` (round 2, `round2.md`). Not merged.
The goal was the grass and turf up close on the aqueduct isle at night (clear, 23:00).
Autumn is the default season.

## What was wrong

Round 2 made the near turf grey. The reason is not the turf shader alone. The night
grade (`shaders/look_grade.gdshaderinc`, `zs_look_night`) mixes 62 to 80 % of every land
pixel into a cool rod-lit grey (`celestial.gd` `NIGHT_GRADE`, `NIGHT_HUE_*`). Autumn's
straw and sand are bright, so they came out as pale silver-grey. Round 2's
`NIGHT_NEAR_COOL` added more grey on top. With the grade turned off for a test
(`x2_circle.png`), the same turf is a warm sandy tan.

Other things I tested:

- **Grass translucency** at night: turning it off barely changed anything (`x1_circle.png`).
- **The rim sheen** (`zs_look_rim`): it mixes in a flat `vec3(0.5)` grey, but it only
  added a little (`x3_circle.png`).

Round 2's note says editing the grade's colour keep "did not change the capture at all".
The grade does run at Balanced: returning early from `zs_look_night` changed the capture
a lot. The keep term likely did nothing because it only acts on pixels brighter than 0.5.

## What changed

1. **Turf up close at night** (`shaders/reference_surface.gdshader`, the fragment's night
   block). This applies to the ground, grass blades and flowers. It is full strength
   within 12 m and eases out by 70 m (`NIGHT_NEAR`, unchanged). The steps:
   - **Gold lean.** Warm turf (red above green, red well above blue) has its green
     raised toward `NIGHT_NEAR_GOLD` (0.8) of its red, and its blue cut to
     `NIGHT_NEAR_BLUE` (0.6). Tan and pink-sand become a deep gold-olive. Green turf
     (summer) is skipped.
   - **Richer.** Chroma is scaled by `NIGHT_NEAR_RICH` (1.6) around luma, so some of
     the hue survives the grade.
   - **Levelled dim.** The colour is multiplied by `NIGHT_NEAR_DIM` (1.0) ×
     min(1, (`NIGHT_NEAR_LEVEL.x` / luma) ^ `NIGHT_NEAR_LEVEL.y`), with level (0.06, 0.9).
     Bright autumn straw goes down a lot. Summer's dark green goes down little.
     Round 2's flat ×0.5 crushed summer.
   - **Removed:** round 2's `NIGHT_NEAR_COOL` and `NIGHT_NEAR_HUE` grey mix.
   - **Moon tip sheen.** A soft emission on the upper blade (`NIGHT_TIP_SHEEN`: x 0.5
     strength, y 0.5 where on the blade it starts). It uses `zs_moon_light`'s colour on
     a half-grey version of the blade's tint. It is stronger on blades leaning to the
     moon and when looking toward it. It is subtle and does not glow.
   - **Rim term.** The look-pass rim (`zs_look_rim`) is faded out on the near turf at
     night (`× (1 - night_near)`). Its flat grey was part of the frosty look.
2. **The night grade eases off up close** (`shaders/reference_air_blend.gdshader`). This
   is the display-fog blend that carries the grade in the game. From the depth copy,
   pixels within 12 m take only `NIGHT_NEAR_GRADE` (0.6) of the rod-grey share. This
   eases back to the full share by 70 m (`NIGHT_NEAR_GRADE_FAR`). It applies to
   everything near, not just turf:
   - Stones up close keep a little more of the moon's blue.
   - The plane keeps more of its red.
   - The standalone grade (`look_grade.gdshader`) has no depth, so it is unchanged.
     It is only used where native woodland fog hides the blend.

Day is unchanged, as the measured boxes below show. The wide view (150 m and more) is
outside both ranges.

## Knobs

- `reference_surface.gdshader`: `NIGHT_NEAR` (range), `NIGHT_NEAR_DIM`, `NIGHT_NEAR_LEVEL`,
  `NIGHT_NEAR_RICH`, `NIGHT_NEAR_GOLD`, `NIGHT_NEAR_BLUE`, `NIGHT_TIP_SHEEN`.
- `reference_air_blend.gdshader`: `NIGHT_NEAR_GRADE` (lower keeps more colour; 1 is
  round 2), `NIGHT_NEAR_GRADE_FAR`.
- Darker turf: lower `NIGHT_NEAR_LEVEL.x`. More moon-blue: raise `NIGHT_NEAR_GRADE`.
  Less vivid summer green: lower `NIGHT_NEAR_RICH`.
- `celestial.gd` `NIGHT_AUTUMN` is untouched.

## Captures

All are in `/private/tmp/zs-night3/`, 1440x900 windowed, taken with
`tools/capture_night_light.gd`. The "before" captures are round 2's shaders (branch
head `db2a6bab`), taken in this session. The helpers are in `scripts/`: `cap.sh` runs
one capture and kills the process, and `m.sh` measures box means.

| view | before | after |
|---|---|---|
| near grass, autumn | `before_circle.png`, `before_plane.png`, `before_aqueduct.png` (also round 2's `zs-night2/after_circle.png`) | `after_circle.png`, `after_plane.png`, `after_aqueduct.png` |
| near grass, summer 23:00 | `before_summer_circle.png`, `before_summer_aqueduct.png`, `before_summer2_plane.png` | `after_summer_circle.png`, `after_summer_aqueduct.png`, `after_summer_plane.png` |
| summer, moon up (02:00) | | `after_summer_h2_circle.png`, `after_summer_h2_aqueduct.png` |
| wide (about 150 m) / ruins pass | `before_wide.png`, `before_ruins.png` | `after_wide.png`, `after_ruins.png`, `after_summer_wide.png` |
| day, 13:00 autumn | `day_before_{circle,plane,wide}.png` | `day_after_{circle,plane,wide}.png` |
| diagnosis | `x1_circle.png` (no translucency), `x2_circle.png` (no night grade), `x3_circle.png` (no rim/sheen) | tuning steps `r1`…`r9` |

Measured (sRGB box means; the near turf box is the lower right of the circle shot):

- **Autumn circle turf:**
  - before: luma 0.191, rgb (0.176, 0.191, 0.231), so blue-grey
  - after: luma 0.117, rgb (0.110, 0.122, 0.095), so dark gold-olive
  - the moonlit stone slab: 0.325
- **Summer 23:00 circle turf:** 0.079 → 0.044, deep green instead of teal-grey. The summer
  moon at 23:00 is weak (stones 0.10 in both), so the whole scene is dark. The 02:00
  capture shows summer under a moon.
- **Day:**
  - circle 0.332 → 0.332
  - plane 0.516 → 0.518 (grass sway)
  - wide 0.703 → 0.703

## Open

- **Summer green at 02:00** reads a little vivid and even (emerald). Try
  `NIGHT_NEAR_RICH` 1.3–1.4 if it looks too saturated. That would also mute autumn
  slightly.
- **Near-to-far seam.** The near turf is gold-olive. Past 70 m it fades back to round 2's
  tan-grey moonlit tone. In the ruins pass the foreground is a little warmer than the
  middle ground. It is not a visible ring in the captures, but walking may show the
  shift.
- **Tip sheen** is subtle. In stills it mostly reads as lighter blade tops. Raise
  `NIGHT_TIP_SHEEN.x` if motion needs more.
- **Lantern light** reads warm on autumn grass (`after_plane.png`). On summer grass it
  goes yellow-green, because warm light on a green albedo does that.
- **Dragon underside:** not checked. It is usually beyond 70 m, so these changes don't
  reach it.
- **Other night styles** (Nocturne, Mystic, Opal): not captured this round. The
  air-blend change is style-independent.
- **Ground pattern (for the later round, not verified).** Two likely sources of the boxy
  or checkered turf pattern:
  - The ground's per-vertex terms (`zs_ground_lush_at`, `zs_ground_form_at`,
    `zs_ground_shade_at` in `ground_look.gdshaderinc`) are computed in `vertex()` and
    carried in `earth_side`, so they interpolate across each triangle pair of the
    grid. `zs_ground_lush_at` and `zs_ground_form_at` also return 0 wherever the
    vertex is more than 0.35 / 0.6 m off the map height. That could give square
    patches.
  - The fragment lights the ground with the facet normal from derivatives, blended
    with the smooth normal only by `ground_soft × grassness`. Where that blend is low,
    every grid triangle is shaded on its own.
- **Tests (headless).** Import is clean. Passed: `test_night_styles`, `test_night_fill`,
  `test_look_light`, `test_kit_time_weather`, `test_aqueduct_isle_life`.
  `test_aqueduct_isle_look` fails as on base (16 plants off turf). None of these render
  the look. The look was checked by eye and by box means in windowed captures only.

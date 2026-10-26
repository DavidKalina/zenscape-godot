# Light pass, round 1: the light carries the scene (handoff)

Branch `light-pass`. Brief: `light-audit.md`. A prototype round. The proof is
the smoke check plus rendered stills and a throwaway light probe in
`scratch/light/` (git-ignored, uncommitted). No tests were added.

The change: the sun's colour and the shade's colour are now published every
frame. Materials that paint some of their own light (the rock's light ramp,
the grass's warm and cool pairs, the spruces' shade olive, the gold glints)
take those colours instead of fixed ones. The sky fill and the rim light
take the shade's colour. At golden hour the low sun gets deeper and stronger,
and the fill eases off. At the default mood and hour the frame is
pixel-identical to main (table below). `--light-follow=0` gives the old light.

## Fly it

```
cd ~/Documents/Projects/zenscape-light && python3 tools/play.py -- --ledger=/tmp/light_pass_ledger.json
cd ~/Documents/Projects/zenscape-light && python3 tools/play.py -- --ledger=/tmp/light_pass_ledger.json --hour=17.5
cd ~/Documents/Projects/zenscape-light && python3 tools/play.py -- --ledger=/tmp/light_pass_ledger.json --mood=golden_meadow
cd ~/Documents/Projects/zenscape-light && python3 tools/play.py -- --ledger=/tmp/light_pass_ledger.json --mood=golden_meadow --hour=17.5
cd ~/Documents/Projects/zenscape-light && python3 tools/play.py -- --ledger=/tmp/light_pass_ledger.json --mood=rosewater_dusk
cd ~/Documents/Projects/zenscape-light && python3 tools/play.py -- --ledger=/tmp/light_pass_ledger.json --mood=rose_dusk
cd ~/Documents/Projects/zenscape-light && python3 tools/play.py -- --ledger=/tmp/light_pass_ledger.json --day
```

Add `--light-follow=0` to any of these to see main's light. In play, T steps
to the next quarter of the day and L to the next mood. `--day` runs the clock
(a day in about eight minutes), so you can watch the land warm toward evening.

## What the measurement found

The probe (`scratch/light/probe.gd`) holds each of `look_views.gd`'s views
(plus a `forest` view) and renders the frame several ways: as the game shows
it, then with linear tone mapping as sun only, sky fill only, rim only,
neither (fog, sky reflection, emission glows), and without trees (to mask
them). Pixels are sorted into grass, rock and tree, sunlit (the sun gives over
60% of their light) or in deep shade (under 10%). It prints each light's
share of what lands on screen. The shares come from separate passes, so they
are approximate. Seed 1, five views, the Mac at 1440x900 (3D at 0.8,
MetalFX).

**Where the light on screen comes from (main):**

| mood, hour (sun height) | sunlit grass: sun / fill / rim / haze | sun : fill on sunlit grass | deep-shade grass: fill / rim / haze | deep-shade rock: fill / rim / haze |
|---|---|---|---|---|
| default (alpine_morning) 8.6 h (0.48) | 84 / 6 / 8 / 3 % | 12.9 : 1 | 30 / 34 / 36 % | 18 / 50 / 32 % |
| default at 17.5 h (0.10) | 67 / 17 / 17 / 1 % | 3.9 : 1 | 31 / 56 / 15 % | 27 / 45 / 25 % |
| golden_meadow at 17.5 h (0.10) | 68 / 17 / 16 / 1 % | 4.0 : 1 | 35 / 58 / 11 % | 28 / 30 / 33 % |
| rosewater_dusk 16.6 h (0.28) | 84 / 7 / 7 / 2 % | 11.9 : 1 | (too few px) | 31 / 46 / 27 % |
| rose_dusk 17.0 h (0.19) | 89 / 5 / 6 / 1 % | 19.7 : 1 | (too few px) | 16 / 74 / 9 % |

The gap the audit saw (about 10:1 in code, 1.4:1 in the image) is not a gap
in the light:

- **On screen the sun does dominate sunlit land.** It gives 84% of sunlit
  grass's light at the default, and sun to fill is 12.9:1 (the code's 10:1,
  times the mood's key 1.05 over its fill 0.95). Sunlit grass is about 5.8
  times as bright as grass in deep shade (linear luma 0.21 against 0.036),
  or V 0.58 against 0.17 on screen.
- **The 1.4 is `look_measure`'s `lit_dark`.** That compares the brightest and
  darkest tenth of grass-classed pixels. In open-meadow views nearly all
  grass is sunlit (deep-shade grass is 1 to 4% of the grass pixels in the
  probe's views, and the committed world stills are high open-meadow views).
  So it measures how much the paint varies inside sunlit turf, after the
  display curve, not sun against shade. On a still with real shadows (the
  `hills` view) it reads 4.9.
- **Shade is not lit by the sky fill alone.** In deep shade the hemisphere
  fill gives only 18 to 35% of the light. The **rim light** gives 30 to 74%.
  It is a second, shadowless directional light (`celestial.gd` `_rim`) in a
  fixed palette colour, (0.58, 1.07, 1.59) at luma 1, the same at every hour.
  The rest, 10 to 36%, is **haze and glow**: depth fog in the horizon's
  colour from 120 m out, plus the rock's own bounce glow, which was a fixed
  blue and orange.

Why golden hour did not warm the grass (main):

1. **The default sun is already orange.** Its hue at 8.6 h is (1.43, 0.93,
   0.45) at luma 1, and the albedos are balanced under it. At 17.5 h the sun
   is (1.83, 0.83, 0.20), so red over green only rises 1.4 times. That fixed
   `ffb45c` low sun is the same in every mood: no mood sets its own.
2. **The cool light holds while the sun falls.** As the sun drops, its term
   on flat land falls (energy times its height). The sky fill (0.34 to 0.37)
   and the rim (0.35 to 0.32) stay put. The sun's share of sunlit grass falls
   from 84% to 67%. A third of the light on sunlit grass is then green-blue,
   which cancels the warmth.
3. **The fill's hue never moves.** The sky fill sits at (0.80, 1.03, 1.34)
   from morning until the sun sets, while the zenith turns violet and the
   horizon orange. Shade could not follow the sky.
4. **Fixed paint.** The rock's ramp paints its lit facets beige (0.58, 0.47,
   0.33) and its shade blue at any hour. The grass's warm and cool pairs are
   fixed too.

## What changed and where

- `scripts/shared/celestial.gd` (`update_rig`; constants after `_luma`)
  publishes these new globals (in `project.godot [shader_globals]`):
  - `zs_sun_hue`: the key's colour at luma 1.
  - `zs_shadow_tint`: the shade's colour at luma 1. It is the sky fill's
    hue, turned as the zenith turns from its day colour (to the power
    `SHADOW_SKY`), and cooled against a sun warmer than the reference (the
    reference over today's sun hue, to the power `SHADOW_COMPLEMENT`). This
    is the one shared shadow tint: `zs_hemi_sky` is now this tint at the
    fill's strength, so grass, rock, tufts, trees and water are all lit in
    shade by the same colour, and it moves with the hour.
  - `zs_sun_lean` and `zs_shade_lean`: today's sun hue and shade tint over
    the reference light's (`REF_SUN_HUE`, `REF_FILL_HUE`: alpine_morning at
    8.6 h). They are exactly (1, 1, 1) at the default mood and hour.
  - `zs_light_follow`.
  - The rim light's colour leans with the shade lean.
  - Golden hour (`GOLDEN_E`, sun height 0.42 down to 0.14, under a clear
    sky): the sun's hue deepens past the reference (`GOLDEN_DEEPEN`), the key
    grows (`GOLDEN_KEY_LIFT`), and the fill and rim dip
    (`GOLDEN_FILL_DIP_FOLLOW`, `RIM_GOLDEN_DIP`). The paint's leans follow
    the hour's sun, not the deepening, so painted tones don't double up on it.
- `shaders/light_leans.gdshaderinc` (new): `zs_warm(c, k)` and
  `zs_cool(c, k)` multiply a painted tone by a lean to the power k.
  `zs_glint(c)` turns a glint's colour with the sun.
- `shaders/endless_rock.gdshaderinc`: these take `zs_cool`: the ramp's
  shade tone, the shaded crack and glint, the carve's groove, and the sky
  bounce. These take `zs_warm`: the lit tone and lip glint (`rock_follow`),
  the crest, and the ground bounce. The mid tone takes half. The bounce glow
  now eases with the sky fill's strength (`ER_REF_FILL`, set in
  `endless_ground.gdshader`). The rock's own hue leans (planes, drift, beds)
  are left alone.
- `shaders/endless_ground.gdshader`: the grass's warm and cool pairs take
  `zs_warm` / `zs_cool` (`paint_follow`, 0.5): the drift (3 places), the
  slopes to and from the sun, the sheen, the high-ground patches, the paper
  light, and the warm cast on the rock patches. The river's sun glint takes
  `zs_glint`.
- Trees: the shade olive takes `zs_cool` in `endless_spruce_sprite`,
  `endless_spruce_ring` (`shade_follow`), `endless_forest_floor`,
  `reference_surface` (`SPRUCE_SHADE_OLIVE`) and `reference_direct_light`
  (the look-fill olive, which endless flight doesn't use).
  `reference_surface`'s underglow takes `zs_warm`.
- `shaders/endless_sea.gdshader`: the sunset glint takes `zs_glint`.
- `scripts/scene_look_presets.gd`: golden_meadow gets a honey sun (`ffc480`)
  and sun energy 1.24 to keep its brightness. Its Summer palette's pale sun
  had read cooler than the default mood's. This is a mood change, not a
  light-follow one, so `--light-follow=0` does not undo it.

Detail, texture, paint noise and contrast patterns are untouched. Only the
hue that the light-tone literals carry, and the light's balance at low sun,
move.

## Knobs

| knob | where | value | what |
|---|---|---|---|
| `--light-follow=X` | celestial | 1 | 0: main's light (leans 1, old fill and rim colours, old dip). Values between blend. |
| `GOLDEN_E` | celestial | (0.42, 0.14) | sun heights where golden hour fades in and is full |
| `GOLDEN_DEEPEN` | celestial | 0.5 | how far the low sun's hue deepens past the reference (power of its lean) |
| `GOLDEN_KEY_LIFT` | celestial | 0.3 | key x1.3 at full golden hour |
| `GOLDEN_FILL_DIP_FOLLOW`, `RIM_GOLDEN_DIP` | celestial | 0.3, 0.3 | fill and rim eased off at golden hour. At 0.5 and 0.6 the deep shade went near black and lost its cool. |
| `SHADOW_SKY`, `SHADOW_COMPLEMENT` | celestial | 0.5, 0.3 | how far the shade tint follows the zenith, and cools against a warm sun |
| `REF_SUN_HUE`, `REF_FILL_HUE` | celestial | the default's | the reference light, where every lean is 1 |
| `rock_follow` | endless_rock (ground material) | 0.75 | the rock ramp's follow. Try it with `--rock-knob=rock_follow=X`. |
| `paint_follow` | endless_ground | 0.5 | the grass pairs' follow. At 1, painted warm patches went orange in shade. |
| `shade_follow` | spruce sprite and ring | 1 | the far spruces' shade olive |

## Before and after (pixel-matched over main's masks)

Each figure is the median V and S on screen (0..1) and the mean B/R
(blue over red; higher is cooler), over the five views. The before is main
(a detached worktree), and the after is this branch, with the same seed,
views and pixels.

| mood | sunlit grass V | sunlit grass S | shade grass V, B/R | sunlit rock V, S | shade rock V, B/R | sunlit tree V | shade tree V, B/R |
|---|---|---|---|---|---|---|---|
| default 8.6 h | 0.579 -> 0.579 (0.0%) | 0.522 -> 0.522 | 0.165 -> 0.165, 1.07 -> 1.07 | 0.656 -> 0.656, 0.310 -> 0.310 | 0.331 -> 0.331, 1.53 -> 1.53 | 0.463 -> 0.463 | 0.155 -> 0.155, 1.66 -> 1.66 |
| default 17.5 h | 0.296 -> 0.326 (+10%) | +3% | 0.132 -> 0.102 (-23%), 1.75 -> 1.86 | +14%, +19% | +4%, 1.19 -> 1.21 | +23% | -8%, 1.35 -> 1.50 |
| golden_meadow 17.5 h | 0.324 -> 0.408 (+26%) | +6% | -20%, 1.64 -> 1.66 | +22%, +22% | +12%, 0.97 -> 0.89 | +36% | -7%, 1.34 -> 1.44 |
| golden_meadow 8.6 h (honey sun) | +1.4% | +3% | -4%, 1.11 -> 1.08 | +7%, +15% | -1%, 1.38 -> 1.36 | +2% | -1%, 1.68 -> 1.67 |
| rosewater_dusk 16.6 h | +6% | +1% | (too few px) | +6%, +8% | -9%, 1.17 -> 1.14 | +8% | -10%, 1.22 -> 1.21 |
| rose_dusk 17.0 h | +18% | +5% | (too few px) | +9%, +15% | -20%, 1.25 -> 1.21 | +21% | -20%, 0.95 -> 0.89 |
| default 17.95 h (sun on the horizon) | (no sunlit grass) | | -9%, 1.09 -> 1.35 | +17%, +22% | +5%, 1.15 -> 1.16 | +31% | 0%, 1.20 -> 1.26 |
| default 12.5 h (noon) | +0.1% | +0.7% | | -2%, **-21%** | +3%, 1.48 -> 1.54 | -1% | -1%, 1.59 -> 1.43 |

Sunlit B/R falls at every low sun (warmer): grass 0.37 -> 0.31 at 17.5 h, rock
0.61 -> 0.53, trees 0.32 -> 0.25. Rock and trees gain the most, since the
rock's ramp was the most fixed paint. On screen, golden hour now reads gold:
the rock goes orange-gold, the grass olive-gold, and the tree shadows on the
grass navy-violet (`a8/dusk175/hills.png`, `a8/golden/forest.png`).

Drift worth knowing:

- **Noon**: the rock is greyer (sunlit S -21%). The noon sun (1.25, 0.96,
  0.67) is whiter than the reference morning sun, and the rock's painted lit
  tone now follows it. `--rock-knob=rock_follow=0` keeps the warm noon rock,
  and so does an asymmetric lean (warm only) if that reads better.
- **Rosewater and rose dusk** are mood hours with the sun still fairly high
  (0.28 and 0.19), so they change less than true golden hour. Their deep
  shade goes 10 to 20% darker. At rose_dusk the deep shade is very dark
  (V about 0.04 to 0.06), as before but darker still.
- **Shaded rock and trees at a low sun** pick up warmth from the haze (the
  horizon-coloured depth fog is 20 to 35% of their light from about 120 m
  out) and from the warm ground bounce. Shade B/R holds or warms slightly
  there, while near grass and tree shade cools.
- The probe counts the rock's bounce glow under "fill" now (it scales with
  the fill). That moved the probe's own classes, but not the pixels; the
  pixel-matched default is identical.

## PC fidelity

Captured with the window raised to the Mac's full screen at the game's best
anti-aliasing (`--msaa=8 --screen-aa=smaa --render-scale=1`; there is no
quality preset): default, default at 17.5 h and rose_dusk. The stills are
full size, in `scratch/light/pc_before/best/` (main: hills, rock, cruise,
forest) and `scratch/light/pc_after/best/` (this branch: hills, cruise).
macOS clamped the window to 3024x1898 on some runs and 3024x1702 on others,
so a before and after pair can differ in height. Compare them by eye; they
are not pixel-matched. At this size they show what 1440x900 shows: the
default is unchanged, and at the low sun the rock goes orange-gold, the grass
olive-gold and the shadows navy, with the rock's beds, facets and relief and
the grass grain intact.

**FSR2 hangs in rendered captures on this Mac.** With `--render-scale=0.75
--render-upscale=fsr2` the capture produced no rows and was killed after
about 5 minutes, twice. The PC's upscaled look is therefore unverified here.
It is worth a look later; I didn't debug it this round.

## Existing tests likely to break

None found by grep: no test reads the changed literals, `zs_hemi_sky`, the
rim's colour, the golden dip, or golden_meadow. The rendered (gpu) tests that
render reference_surface or the sea at a low sun could shift by a few
percent. I didn't run the suite (as briefed).

## Left for the next round

- **Moods as a few light values over the day** (audit round b). Sun colour,
  height, fill colour and energy, and haze at 4 to 6 hours, with the presets
  as nudges. The fixed low-sun colours (`ff6222` -> `ffb45c`) and
  `DAY_SKY` belong in that table. Today a mood's sun swatch only shows above
  sun height 0.4.
- **The rim light** is a hidden second fill: 30 to 74% of the light in deep
  shade, shadowless. It now leans with the shade, but it should be folded
  into the fill model or given a clear job (a rim).
- **The haze** (depth fog in the horizon's colour, `endless_look.gd _haze`)
  adds 20 to 35% to mid-distance shade and is warm at a low sun. It is the
  main thing still warming far shadows. A shadow-aware or sky-split fog
  colour would let far shade cool too.
- Not touched (audit sections 3 to 5): the cloud composite's `BOUNCE_TINT`
  and `FOG_COOL`, the sky dome's belt and shadow tint, `endless_post.gd`
  MOODS (the post is off by default), and `reference_surface`'s storm and
  night grades.
- Grass shade on green turf can't show much violet. The albedo has almost no
  blue, so a cooler fill only deepens it to teal-navy. If the user wants
  lavender shadows on the meadow (rosewater's "lavender shadows"), the
  shaded side needs a share of desaturated albedo times the tint.
- `look_measure.py` classes golden-hour grass (hue about 50) as rock_sand, so
  its grass ranges are blind to golden hour.
- **Harness**: `project.godot` has `window/size/mode=3` (full screen). On
  this Mac, drive.py's `--windowed --resolution 1440x900` sometimes lost to
  it, and the run rendered at 3024x1898 with 3D at 0.38 (MetalFX) while
  `shot()` scaled the still back to 1440x900. Stills from different runs then
  differ in render resolution without saying so. The probe forces the window
  after `open()` (root.mode, then root.size, waiting frames) and logs the
  viewport. `look_views.gd` and `shot.py` should do the same. The harness
  also lacks a light-split tool. The probe (`scratch/light/probe.gd`, with
  `compare.gd`, `cmpagg.py`, `agg.py`, `runset.sh`) is a candidate for
  `tools/harness/` if this work continues.

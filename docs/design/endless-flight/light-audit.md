# Light audit: fixed colours that decide the look

Branch `look-clean`, round 3. A list, nothing fixed here beyond the clean look's own
tints (see the round 3 section of `clean-look-handoff.md`). Line numbers are
of this branch. Sources: reading by scouts plus my own checks; items marked
**(?)** are unverified.

Legend. **Own**: a material's own colour, fine to keep. **Light**: a lighting
colour pretending to be fixed; should read the published light (`zs_key_irradiance`
sun colour, `zs_hemi_sky`/`ground`/`energy` fill, `zs_sky_up/down/glow`,
`zs_cloud_sun/sky`, `fog_light_color`). **Mixed**: a literal that multiplies a
published value, so it follows the light but with a fixed lean.

## 1. Land and grass (`shaders/endless_ground.gdshader`)

| line | literal | colours | kind | should read |
|---|---|---|---|---|
| 657, 739, 844 | `(1.32,1.05,0.62)` / `(0.80,0.97,1.16)` | warm/cool drift of grass by the broad light | Light | sun hue / sky fill hue |
| 681 | `(1.10,1.05,0.86)` / `(0.90,0.95,1.02)` | sun-facing vs turned slope tint | Light | `zs_cl_warm` / `zs_cl_cool` style |
| 701 | `(1.25,1.22,0.85)` x1.55 | wind sheen | Light | sun hue (sheen is sun on blades) |
| 721 | `(1.07,1.03,0.86)` / `(0.88,0.98,1.06)` | high ground patch warm/cool | Light | as 681 |
| 754-755, 766 | `(0.72,0.96,1.02)`, `(1.30,1.14,0.58)`, `(1.12,0.92,0.62)`, `(0.62,0.80,0.78)` | watercolour pigments of the patch wash | Own (paint) | keep |
| 759 | `(0.66,0.76,0.70)` | wet-edge darkening | Own | keep |
| 762 | `(1.18,1.16,0.98)` x1.18 | "paper light" crowns | Light | sun hue |
| 787 | `(1.10,1.0,0.86)` | warm tint on rock patches | Light | sun hue |
| 282-293 | GREEN, SUNLIT, DEEP, DRY, MEADOW, TUNDRA, OLIVE, ROCK, ROCK_PALE, SAND, SAND_WET, SEABED | albedo palette | Own | keep (moods nudge them, section 6) |
| 294 | `SNOW (0.86,0.89,0.95)` | snow albedo | Own (a cool lean is baked in) | keep |
| 902-913 | `zs_clean_*` | clean look sun/fill | now reads light | done |
| 915-923 | haze planes | distance layers | was fixed blue; now `zs_cl_haze_mid/far` | done |
| 1091, 813 | weed, bank pebble | albedo | Own | keep |

`endless_patch.gdshaderinc:64-97` (hue multipliers, flower washes): Own.
`endless_forest_floor.gdshader:100` `(1.20,1.05,0.22)` olive canopy fill: Light
(a fixed olive pushed through the fill), should be the fill colour times a
foliage albedo. `:25, :32` litter and canopy albedo: Own. `endless_tuft_far`: none.

## 2. Rock (`shaders/endless_rock.gdshaderinc`) - the biggest block of pure constants

| line | literal | colours | kind | should read |
|---|---|---|---|---|
| 59-60 | `ER_SHADOW1`, `ER_SHADOW` | shade tones of the three steps | Light | sky fill hue x albedo |
| 63-64 | `ER_MID`, `ER_LIT` | mid and lit tones | Light | sun hue |
| 61 | `ER_SKY_BOUNCE (0.30,0.38,0.72)` | blue bounce | Light | `zs_hemi_sky` |
| 62 | `ER_GROUND_BOUNCE (0.95,0.60,0.34)` | warm bounce, used at 392 | Light | `zs_hemi_ground` |
| 65-66, 356-357 | `ER_GLINT`, `ER_CRACK`, `(0.40,0.40,0.54)` | glint, crack in lit and shade | Light | sun / sky |
| 382-383 | `(0.50,0.50,0.66)`, `(1.30,1.22,1.08)` | carved groove and crest | Light | sky / sun |
| 282, 285, 302 | hue leans | albedo leaning per plane | Own | keep |

The rock paints its own light (a fixed ramp), then goes to EMISSION. So rock
does not follow the mood's sun at all; at dusk it is lit by the ramp, not by the
sun's colour. Biggest single offender with the sky dome (below). **(?)** how much
of this the dusk stills show: the rock looked warm at dusk through the sun's
`LIGHT_COLOR` on the land's own sun term, not through this ramp.

## 3. Trees, snags, shared surface

- `endless_spruce_sprite.gdshader:49`, `endless_spruce_ring.gdshader:~81`: `OLIVE (1.20,1.05,0.22)` in emission: Light. Read fill colour.
- Spruce sprite `:134` / ring `:92`, `reference_direct_light.gdshaderinc:22`: `(0.96,0.99,1.04)` / `(1.04,1.02,0.94)` sun tint: Mixed (x `LIGHT_COLOR`). Fine.
- `:24` back-sun `(0.9,1.0,0.85)`, `:52` transmission `(0.82,1.0,0.58)`: Mixed, foliage-green leans; fine.
- `:39` olive fill ratio: Light (cancels the fill and puts olive back).
- `endless_tree_far.gdshader:29`: now `zs_cl_cool`; was `(0.9,0.97,1.12)`.
- `reference_surface.gdshader:1137` `(1.0,0.88,0.62)` underglow: Light (fixed warm; scalar from `zs_hemi_energy` only).
- `:1067` `(0.8,0.86,0.95)` storm grade: Light, weather only.
- `:1093-1096`, `:785-786` night gold/blue: Light, night only.
- `:1103` snag `(0.36,0.305,0.26)`; `:1056` snow `(0.88,0.91,0.95)`; `:289` peak snow: Own.
- `shaders/spruce_paint.gdshaderinc:40` `SPRUCE_SHADE_OLIVE`: Mixed (x hemi).

## 4. Water

- `endless_sea.gdshader:1270`, `endless_ground.gdshader:1242`: sunset glint `(1.0,0.62,0.35)` -> `(1.0,0.98,0.9)` keyed on `sun.y`: Light, fixed gold; should be `zs_key_irradiance` hue. (At rosewater_dusk the glint is gold-peach while the sun is rose-orange: close, not equal.)
- Sea `:1138` foam `(0.9,0.96,1.0)`, `:1169` cloud mirror `(1.0,0.99,0.97)`: Mixed (x ambient/key). Fine; the cloud mirror should use `zs_cloud_sun` **(?)**.
- Sea/river tints `tint_shallow/mid/deep` (`:181-184`; river `:145-147`, absorb `:154`), `sss_color :108`: Own (water colour; mood-driven, section 6).
- River block `:1131, 1136, 1163` whites and froth, `:1187` blossom, `:1209` shore tone `(0.16,0.22,0.12)` (a fixed shore colour mirrored: Own), `:1231` cloud reflection: Mixed. `:1151` `vec3(0.02)` additive: Light, tiny.
- `:1245` wet albedo black: Own (it is all emission).

## 5. Sky, clouds, mist, valley fog

- `endless_cloud_composite.gdshader:33` `BOUNCE_TINT (0.78,0.9,0.82)`: Mixed (x `c_sun`). Fixed green-grey bounce; should be the land's bounce (`zs_hemi_ground`).
- `:40` `FOG_COOL (0.8,0.95,1.2)` valley-fog shade: Mixed (x `c_shade`); fixed cool lean, so valley fog stays blue at dusk **(?)** (not seen in my stills).
- `:96` glow white `(0.95,0.97,1.0)` mixed with `sun_hue`: partly Light.
- `cumulus_light.gdshaderinc:39` golden `(1,0.8,0.66)`, `:41` shade `(1.3,1.02,0.98)`: Mixed (the old clouds' own lean; as main). Cream/white options now read `sun_hue` and the shade's hue (round 3).
- `endless_post.gd:22,25-34` MOODS and default `shade`/`light` Vector3s into `P.shade`/`P.light`: Light, stand alone (the mood grades of the old post; per-mood hand tuning).
- `endless_post.glsl:156` sunlit-face warm `(1.22,1.05,0.78)`: Light, fixed, scaled only by `ndl`. Should be the sun hue.
- `endless_post.glsl:110, 148`: fog colour and grey fill: Mixed (x horizon LUT).
- `reference_sky_common.gdshaderinc:164` belt pink `(0.42,0.13,0.16)` (x `zs_belt`), `:165` shadow tint `(0.55,0.62,0.80)`: Light, stand alone. `:62-63, 110, 137-138` aurora, rainbow, moonbow: Own.
- `zsBelowAir`, `zsBelowDeck` (`:188-227`): many standalone pearl/lilac literals; **(?)** unconfirmed that endless flight draws them.
- `scripts/endless/endless_look.gd:573-578`: fog light colour comes from `horizon()` (follows light). No colour literal in the Environment glow/fog setup.
- Clean look's own (this round): `clean_look.gd` `_tints` trims `(1,0.885,1)`, `(1,1.03,1)`, `(0.975,0.975,1)` and the 0.125 grey lift of the edge colour (`_edge_colour`): fixed numbers that keep round 2's values at the default; they are trims, not colours.

## 6. Where moods repaint material colours by hand

`scripts/scene_look_presets.gd` (keys merged over each family's colours at `:61-62`;
consumed as `zs_palette_<surface>` globals, `scene_look.gd:104`):

| mood | grass | foliage | water | rock | hour (phase) |
|---|---|---|---|---|---|
| alpine_morning | - | - | yes | - | 0.40 |
| golden_meadow | yes | yes | yes | - | 0.36 |
| copper_autumn | - | yes | yes | - | 0.40 |
| rosewater_dusk | yes | yes | yes | - | 0.69 |
| enchanted_forest | yes | yes | yes | - | 0.335 |
| halloween_hollow | yes | yes | yes | yes (+earth) | 0.055 |
| first_snow | - | yes | - | - | 0.43 |
| nordic_night | - | yes | yes | - | 0.035 |
| after_the_rain | yes | yes | yes | - | 0.355 |
| the 9 editor moods (rose_dusk, meadow_morning, desert_afternoon, autumn_evening, winter_hush, misty_hollow, ocean_light, moonlit_stillness, storm_gathering) | family default | family default | family default | family default | 0.02-0.71 |

No preset sets the sun colour by hand (`celestial.gd:333`, `look.rgb("sun")`
from the family). Endless flight offers nine of them (`endless_look.gd:49`).
Grass in the ground shader reads `zs_palette_grass` as a ratio on its own
palette, so a hand-set grass colour moves the albedo: that is why golden_meadow's
grass (set, and at a high sun, phase 0.36) stays midday green.

## 7. Fill against the sun on flat grass (ground shader terms)

Sun on flat ground = `key_irradiance / PI * sun.y`; fill = `hemi_sky * energy / PI`
(the grass adds it as emission x albedo). Measured from the live state
(`scratch/fill_ratio.gd`, luma):

| lighting | sun.y | sun luma | fill luma | sun : fill | sun colour rel. luma | fill colour rel. luma |
|---|---|---|---|---|---|---|
| alpine_morning 9.6 h | 0.477 | 0.505 | 0.049 | 10 : 1 | (1.43, 0.93, 0.45) | (0.80, 1.03, 1.34) |
| golden_meadow | 0.483 | 0.554 | 0.062 | 8.9 : 1 | (1.32, 0.96, 0.50) | (0.80, 1.03, 1.31) |
| hour 16.5 | 0.290 | 0.245 | 0.048 | 5.1 : 1 | (1.57, 0.90, 0.35) | (0.80, 1.02, 1.34) |
| rosewater_dusk | 0.279 | 0.213 | 0.063 | 3.4 : 1 | (1.70, 0.85, 0.37) | (0.91, 1.00, 1.31) |

So by this arithmetic the sun dominates, by 3 to 10 times, and its colour is
strong. That does **not** match the "lit/shade ratio ~1.4" the look measures (and
the sun's colour barely showing at golden hour). **(?)** The gap is probably
in what a still sees: the ACES tone map and the display's grade compress highs, the
tufts and grass blades take the sun through `reference_surface` (wrapped, banded,
translucent) not through the plain Lambert here, `zs_ground_shade` and
cloud shade darken the sun term, and `look_measure` compares sunlit slope with
shaded slope, not with the fill alone. I did not find which of these costs most;
the follow-up round (a) must measure it first (grass sun-lit vs shaded pixel
pairs under a debug flag with the fill off). What does hold: the fill's colour
is the same blue-white at every hour (rel. luma `(0.80,1.03,1.34)`) while the
sun's goes from `(1.43,.93,.45)` to `(1.70,.85,.37)`, and the fill's energy
does not fall as the sun lowers (0.049 to 0.063, rising at dusk through
`DUSK_FILL`), so low sun loses ground to the fill.

## 8. Counts and ranking

About 45 fixed lighting literals (Light or Mixed with a fixed lean) in the
files read; about 25 are pure Light (stand alone). Albedo palettes (Own) not counted.

Biggest offenders:
1. Rock ramp and bounces (`endless_rock.gdshaderinc` 59-66, 356-392): the rock paints its own fixed light.
2. Ground grass drift and sheen (`endless_ground.gdshader` 657-787): fixed warm/cool pairs.
3. Sky dome belt and shadow tint (`reference_sky_common.gdshaderinc:164-165`), the old post's sunlit warm (`endless_post.glsl:156`) and its mood tables (`endless_post.gd:22-34`).
4. Spruce and shared olive fills (`OLIVE` x3, `reference_direct_light.gdshaderinc:39`).
5. Cloud composite's `BOUNCE_TINT`, `FOG_COOL`; the sunset glints.

## 9. Follow-up rounds

**(a) Low-sun balance**, about one round (Opus; looks and light, 5 to 8 files):
measure the sun:fill split first (section 7 gap), then let the fill's energy
fall as the sun lowers so the sun dominates, publish one shared shadow tint
global (`zs_shadow_tint`, from sky fill and a slight lilac) and have ground,
tufts, surface, spruce, rock and water read it; turn the rock ramp's lit/mid
tones and the grass drift pairs (section 1, 2) into functions of
`zs_key_irradiance` and the shadow tint. Risk: it changes main's look, so it
goes behind a switch like the others. Unsure: how far the soft look (1.4)
can go before the grass reads contrasty.

**(b) Moods as a few light values over the day, material colours as nudges**,
about one and a half rounds (Opus): a table of sun colour, sun elevation, fill
colour and energy, haze at 4 to 6 hours, interpolated by the clock; the 18 presets
become small nudges to grass, foliage and water ratios on top (`zs_palette_*`),
and the nine editor moods lose their family copies. Touches `scene_look.gd`,
`scene_look_presets.gd`, `celestial.gd`, `endless_look.gd`. Unsure: the nine
mood-specific grades in `endless_post.gd` MOODS, and which presets depend on
`EndlessPost.tuning(id)` for sun values (not read).

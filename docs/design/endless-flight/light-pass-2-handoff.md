# Light pass, round 2: golden hour and sunset (handoff)

Branch `light-pass-2`, off main at 7f3e0211 (harness 3e1bddb7) (round 1, `light-pass-handoff.md`).
A prototype round. The proof is the smoke check plus rendered stills and the
light split (now a harness tool). No tests were added.

Round 1 made the land follow one light. This round adds light at a low sun,
in three parts, each with its own off flag:

1. **Haze toward and away from the sun** (`--haze-sun=0` turns it off). At
   golden hour the sky's horizon glow gathers toward the sun's bearing. Away
   from the sun, the horizon cools to a pale blue taken from the zenith. The
   land's depth fog takes more of the sky behind each pixel, so its colour
   now turns with the view's angle to the sun, and it takes more of the
   sun's scatter.
2. **Backlight** (`--backlight=0`). Grass tips and spruce silhouettes seen
   against a low sun catch it, in the sun's own colour.
3. **Clouds lit from below at sunset** (`--cloud-under=0`). Over the last
   of the sunset, cloud bellies take the low sun's colour, half of it leaned
   to rose.

Nothing changes above sun height 0.42. At the default mood (8.6 h, sun 0.48)
the frame is pixel-identical to main, and noon is untouched too. All three
come in with round 1's golden hour (`GOLDEN_E`, a clear sky, light follow
on), so `--light-follow=0` also turns them off. Detail, texture, paint noise
and contrast patterns are untouched. The changes only add light, or turn
the haze's colour.

## Fly it

```
cd ~/Documents/Projects/zenscape-light2 && python3 tools/play.py -- --ledger=/tmp/light_pass2_ledger.json --hour=17.5
cd ~/Documents/Projects/zenscape-light2 && python3 tools/play.py -- --ledger=/tmp/light_pass2_ledger.json --hour=17.85
cd ~/Documents/Projects/zenscape-light2 && python3 tools/play.py -- --ledger=/tmp/light_pass2_ledger.json --mood=golden_meadow --hour=17.5
cd ~/Documents/Projects/zenscape-light2 && python3 tools/play.py -- --ledger=/tmp/light_pass2_ledger.json --mood=rose_dusk
cd ~/Documents/Projects/zenscape-light2 && python3 tools/play.py -- --ledger=/tmp/light_pass2_ledger.json --mood=rosewater_dusk
cd ~/Documents/Projects/zenscape-light2 && python3 tools/play.py -- --ledger=/tmp/light_pass2_ledger.json --day
cd ~/Documents/Projects/zenscape-light2 && python3 tools/play.py -- --ledger=/tmp/light_pass2_ledger.json
```

To compare, add any of `--haze-sun=0`, `--backlight=0` or `--cloud-under=0`,
or `--light-follow=0` for main's light before round 1. Fly toward the sun
for the backlight and the warm haze, and away from it for the blue air.
17.85 h is the sunset, where the cloud bellies turn rose.

## What changed and where

- **Haze** (commits 8e94b0c9, 7a076774, 6cab466a):
  - `scripts/shared/celestial.gd` publishes `zs_haze_sun`, which is golden
    hour's ramp times light follow times `--haze-sun=`.
  - `shaders/reference_sky_common.gdshaderinc` `zsSkyBase` is the dome's
    sky, used by the sky, the cloud haze, and the ground's and sea's
    reflections. Its horizon glow gathers toward the sun (`ZS_HAZE_GATHER`
    0.4). Away from the sun, the horizon band mixes toward the zenith's hue,
    part white (`ZS_HAZE_BLUE` 0.6), by `(1 - toSun)^2` (`ZS_HAZE_COOL`
    0.55). The band is held at the brightness it had before the glow
    gathered, so it goes blue, not dark.
  - `scripts/endless/endless_look.gd`: `horizon()` mirrors this at y 0 for
    the depth fog's base colour. `_haze` lerps `fog_aerial_perspective`
    from 0.35 to `AERIAL_SUN` 0.6 and `fog_sun_scatter` from 0.18 to
    `SUN_SCATTER_SUN` 0.45, both by `zs_haze_sun`. Godot's aerial
    perspective samples the sky's radiance behind each pixel, so the haze
    turns per pixel, not just per frame. Far land meets the dome's own
    horizon in every direction, not only at the screen's middle.
  - `shaders/endless_cloud_composite.gdshader`: the cloud haze's sun
    scatter grows with the land's.
  - Valley fog is left alone (`FOG_COOL` in the composite, and its own
    march).
- **Backlight** (ced48921, d854b3a1):
  - New `shaders/backlight.gdshaderinc` with `zs_backlight`. The glow is a
    lobe round the view's line to the sun (cos^8 and cos^32), times how
    thin the spot is, at a fixed brightness through the leaf
    (`ZS_BACKLIGHT_THROUGH` 0.25), mostly in the sun's hue
    (`ZS_BACKLIGHT_LEAF` 0.45 of the leaf's own). It applies to the sun
    only, and only in its light (shadowed).
  - `zs_backlight` is published by celestial: golden hour's ramp times
    light follow times `--backlight=`, and 0 under the moon.
  - Near tufts: `reference_direct_light.gdshaderinc` (`ZS_BACKLIGHT_GRASS`,
    set to 4 in `reference_surface.gdshader`). It lights the blade tips
    only, `along^8`.
  - Near sprays spruce: the same file (`ZS_BACKLIGHT_SPRUCE` 3), a rim off
    the crown's volume normal.
  - Far tufts (20 to 230 m): `endless_tuft_far.gdshader`, through Godot's
    `BACKLIGHT` output, so it is shadowed and lit by Godot. `along^6`,
    gain 5.
  - Spruce sprites (200 to 1440 m): `endless_spruce_sprite.gdshader`, the
    crown normal's rim plus the atlas cover's edge (a fragment-to-light
    varying), gain 2.
  - Spruce rings: `endless_spruce_ring.gdshader`, the same rim, gain 2.
    The rings draw nothing by default.
- **Cloud under-light** (c0e1ae24, f21e51c2):
  - Celestial publishes `zs_cloud_under` (`CLOUD_UNDER_E`: in from sun
    height 0.16 to 0.03, out from 0 to -0.08 under the horizon; clear sky,
    light follow, `--cloud-under=`).
  - `endless_cloud_composite.gdshader` adds the march's bounce term, which
    is strongest at a cloud's base. It is `UNDER_GAIN` 6 times the low
    sun's colour, half of it a rose at the sun's strength (`UNDER_ROSE`,
    `UNDER_ROSE_SHARE` 0.5), and more on the sun's side of the sky. Valley
    fog is excluded.
- Moods: no preset changed.

## Knobs

| knob | where | value | what |
|---|---|---|---|
| `--haze-sun=X` | celestial `haze_sun` | 1 | 0: the haze as main (0..1 between) |
| `--backlight=X` | celestial `backlight` | 1 | 0: off; above 1 stronger |
| `--cloud-under=X` | celestial `cloud_under` | 1 | 0: off; above 1 stronger |
| `ZS_HAZE_GATHER`, `ZS_HAZE_COOL`, `ZS_HAZE_BLUE` | `reference_sky_common.gdshaderinc`; mirrored as `HAZE_*` in `endless_look.gd` (keep the two equal) | 0.4, 0.55, 0.6 | glow gathered toward the sun; how far the away side cools; how blue the cool hue is (else white) |
| `AERIAL_SUN`, `SUN_SCATTER_SUN` | `endless_look.gd` (the cloud composite's `0.45 / 0.18` follows) | 0.6, 0.45 | the depth fog's sky share and sun scatter at full golden hour (0.35, 0.18 by day) |
| `ZS_BACKLIGHT_GRASS`, `ZS_BACKLIGHT_SPRUCE` | `reference_surface.gdshader` | 4, 3 | near tufts' tips, near spruce rims |
| `BACKLIGHT_GAIN` | `endless_tuft_far`, `endless_spruce_sprite`, `endless_spruce_ring` | 5, 2, 2 | far tufts, sprites, rings |
| `ZS_BACKLIGHT_THROUGH`, `ZS_BACKLIGHT_LEAF` | `backlight.gdshaderinc` | 0.25, 0.45 | brightness through the leaf; share of the leaf's hue |
| `CLOUD_UNDER_E`, `UNDER_GAIN`, `UNDER_ROSE`, `UNDER_ROSE_SHARE` | celestial; composite | (0.16, 0.03, 0, -0.08), 6, (1, 0.42, 0.52), 0.5 | when, how strong, how rose |

Tried and dropped:

- Aerial 0.7 with scatter 0.3: the haze toward the sun read duller.
- A cool side that kept the gathered horizon's own brightness:
  golden_meadow's haze away from the sun went a third darker.
- Grass backlight at gain 8 with `along^6`: at full size it lifted whole
  blades and filled the dark gaps between them.
- Cloud under-light at gain 12 from sun height 0.3: golden_meadow's 17.5 h
  clouds went pale pink-white instead of gold.

## Numbers

Seed 1, 1440x900 on the Mac (3D at 0.8, MetalFX). The before set is main,
from a throwaway worktree with this round's harness copied in.

**Default (8.6 h) and noon: no change.** The default is pixel-matched over
11 views, without clouds, and every class is +0.0% in V, S and B/R. For
noon the haze, backlight and under-light terms are all zero by construction
(sun height 0.75). Its unmatched class medians sit within ±1% of main
(`light_split.py stats`), and its pixel match is spoiled by run-to-run drift
(see the tool notes below).

**The haze's own colour** (linear, `fog_light_color` x energy, the base the
aerial sky and the scatter add to), per view:

| mood | toward the sun | across (90°) | away |
|---|---|---|---|
| default 17.5 h (sun 0.10) | (1.59, 0.46, 0.13) -> (1.57, 0.45, 0.12) | (0.41, 0.30, 0.19) -> (0.28, 0.26, 0.24) | (0.15, 0.14, 0.14) grey -> (0.09, 0.13, 0.23) blue |
| golden_meadow 17.5 h | (0.91, 0.08, 0.02) -> same | (0.94, 0.11, 0.04) -> (0.78, 0.14, 0.09) | (0.32, 0.10, 0.06) orange -> (0.13, 0.11, 0.14) lavender |
| rose_dusk 17.0 h (sun 0.19) | (0.91, 0.05, 0.03) -> same | (0.91, 0.05, 0.04) -> (0.44, 0.06, 0.07) | (0.52, 0.06, 0.04) red -> (0.18, 0.06, 0.18) plum |

Aerial goes 0.35 -> 0.6 and scatter 0.18 -> 0.45 at full golden hour
(rose_dusk: 0.58, 0.43).

**The horizon band on screen** (rows 33 to 47% of the frame: far land and
the sky just above it; mean display V and B/R; with clouds):

| mood | toward: V, B/R | across: V, B/R | away: V, B/R |
|---|---|---|---|
| default 17.5 h | 0.798 -> 0.805 (+0.9%), 0.56 -> 0.57 | 0.329 -> 0.316 (-4%), 0.64 -> 0.68 | 0.454 -> 0.429 (-5.5%), 0.56 -> 0.65 |
| golden_meadow 17.5 h | 0.773 -> 0.801 (+3.6%), 0.34 -> 0.35 | 0.434 -> 0.381 (-12%), 0.45 -> 0.51 | 0.546 -> 0.498 (-8.8%), 0.41 -> 0.50 |
| rose_dusk | 0.721 -> 0.744 (+3.2%), 0.30 -> 0.31 | 0.371 -> 0.330 (-11%), 0.29 -> 0.37 | 0.558 -> 0.485 (-13%), 0.30 -> 0.44 |
| default 17.85 h (sunset) | 0.794 -> 0.808 (+1.8%), 0.41 -> 0.43 | 0.307 -> 0.302, 0.53 -> 0.55 | 0.428 -> 0.422, 0.43 -> 0.47 |

Toward the sun the band holds or brightens. Away from it, it cools (B/R up
by 15 to 45%), loses saturation, and drops 5 to 13% in V.

**Backlight**, in the views toward the sun (each run's own classes,
unmatched, without clouds):

| mood | sunlit trees V | near grass |
|---|---|---|
| default 17.5 h | 0.379 -> 0.455 (+20%), B/R(lin) 0.32 -> 0.19 (gold) | sunlit grass V -4% (the class gains newly lit tips); shade grass +0.5% |
| golden_meadow 17.5 h | 0.398 -> 0.460 (+16%) | shade grass +3% |
| rose_dusk | 0.308 -> 0.407 (+32%) | |

In views away from the sun the land is within a few percent of main: trees
-4% to -7% in V at golden_meadow and rose_dusk, from the haze. The land in
the middle distance shifts little in numbers, because the depth fog is a
small share there. The change shows in the far land and in the sky.

## Stills

All are in `scratch/light2/` (git-ignored), main against this branch, with
the same seed and views:

- `before/<mood>/`, `after/<mood>/`: 13 views each, for `default` (8.6 h),
  `noon` (12.5 h), `dusk175` (17.5 h), `golden` (golden_meadow 17.5 h),
  `rosedusk` and `sunset` (17.85 h).
  - Toward the sun: `sun_toward`, `sun_toward_low` (6 m over the grass
    into the sun).
  - Away: `sun_away`, `sun_away_low`.
  - Across: `sun_side`.
  - Cloud views: `clouds_toward`, `clouds_up`.
  - The old views: `meadow_low`, `hills`, `rock`, `forest`, `cruise`,
    `high`.
- `sheets/<mood>.png`: before | after pairs (toward low, away, across,
  clouds).
- `pc_before/`, `pc_after/`: the PC-fidelity set, at full size (3024x1898,
  3D at 1.0) with `--msaa=8 --screen-aa=smaa --render-scale=1`, for
  default, `dusk175` and `golden` (views `sun_toward_low`, `sun_away`,
  `hills`, `cruise`). The window was forced, so all are at the same size
  this time.

What they show: toward a low sun, the blade tips of the near reeds, the
far meadow's tips and the spruce outlines on far islets catch gold. The
reeds keep their dark strands. The haze into the sun stays warm. Away
from the sun the sky's horizon and the far haze go pale blue, and lavender
in golden_meadow. At sunset the cloud bellies go rose.

## Frame times

Median ms from frame to frame, vsync off, 1440x900 on the Mac
(`look_views.gd --time=400`; runs alternated main and branch):

| view | main | this branch |
|---|---|---|
| high, 8.6 h | 12.03, 12.05 | 12.02 (13.6 to 13.8 in two runs) |
| cruise, 8.6 h | 23.25, 23.33 | 23.34 (24.2 in two runs) |
| high, 17.5 h | 12.35 (14.2 once) | 12.32, 12.33 |
| cruise, 17.5 h | 23.77 (24.6 once) | 23.78, 23.80 |

The Mac's frame times flip between two levels about 1.7 ms apart (main does
it too). Comparing like runs, there is no measurable cost. Backlight on
against off in the same build at 17.5 h was within 0.1 ms.

## Tool fixes

- **Window size** (`tools/harness/drive.gd`): `open()` calls a new
  `fit_window()` in rendered runs. It sets the window to `--win=WxH`
  (else the driver's `--size=`, else 1440x900), windowed, and notes the
  window, viewport and 3D scale. `--win=keep` skips it. The 3D scale
  follows on its own (`render_resolution.gd` listens to size_changed).
  This covers `shot.py`/`shot.gd`, `look_views.gd` and every driver.
- **`look_views.gd`**:
  - SUN views looking along the sun's bearing (`sun_toward`, `sun_away`,
    `sun_side`, `sun_*_low`), the cloud views and `forest`.
  - `aim(name)`, `--full-size` and `--time=N`, a ROW of frame times per
    view (median, p90).
  - The GPU timer reads 0 on Metal, so the times are wall clock.
- **Light split, promoted from round 1's probe**:
  - `tools/harness/light_split.gd` adds a fog-only pass (fog share and
    hue) and a `haze_far` class (far land where the depth fog is over 40%
    of the light). It runs on look_views' views.
  - `tools/harness/light_match.gd` (pixel-matched classes).
  - `tools/light_split.py` with `shares`, `views`, `match` (skips views
    whose classes moved, `--min-agree`) and `stats` (unmatched).
  - Both rows are in `tools/README.md`.
- **Run-to-run drift (not fixed)**: two runs of the same build don't always
  match. The clouds' places can differ, and now and then a run's frames
  differ as land and trees stream in on worker threads. Use `--no-clouds`
  for land numbers, and `stats` when `match` skips views. A lighting change
  also moves pixels between classes, so `match`'s agreement test only
  catches drift when nothing changed.
- FSR2 was not tried (it hangs captures, round 1).

## Existing tests likely to break

None found by grep. No test reads the fog's aerial or scatter, `zsSkyBase`,
the new globals, the tuft, sprite or composite shaders, or look_views.

`tests/test_lake_complete_lighting.gd` and `test_lake_flash.gd` build
shaders that include `reference_direct_light.gdshaderinc`. That include now
also pulls in `backlight.gdshaderinc`, whose global `zs_backlight` is in
project.godot, and its new blocks are behind defines those tests don't set.
Both are gpu tests and were skipped headless, so they are unverified. The
rendered tests of the sky or clouds at a low sun could shift. I didn't run
the suite (as briefed).

## Left for round 3

- **Moods as light values over the day** (audit round b), unchanged from
  round 1's list. This round's three ramps all hang off `GOLDEN_E`; a
  table of the day could own them.
- **rose_dusk and golden_meadow away from the sun**: their warm horizon all
  round is now red -> plum and orange -> lavender behind the sun. That
  reads as dusk to me, but it changes those moods' character. If the user
  wants their old warmth all round, lower `ZS_HAZE_COOL` per mood (it
  would need a mood value), or set it to about 0.3.
- **The away side is 5 to 13% darker on screen**: the aerial sky's blur
  takes in the darker zenith. A brighter cool target, or less aerial away
  from the sun, would hold it. Godot's fog has one aerial share for the
  whole screen.
- **Godot's sun scatter is a fixed cos^8 lobe**, and it also counts the rim
  light (a second directional light). A wider warm glow toward the sun
  would need a compositor pass, or a FOG write in each land material.
- **The rim light** is still a hidden second fill (round 1's note).
- **Backlight on the ground's painted grass**: the painted field (not the
  tufts) has none. That was on purpose, to avoid a wash. A view-dependent
  sheen of the paint's tips could follow if the far field reads flat
  against the sun.
- `look_measure.py` still classes golden-hour grass as rock_sand (round 1).

Throwaway checks in `scratch/l2/` (uncommitted):

- `runset.sh`, a light split per mood (`REPO=` for main's worktree).
- `stills.sh`, look_views per mood.
- `band.gd`, the horizon band's colour.
- `crop.gd`, side-by-side crops.

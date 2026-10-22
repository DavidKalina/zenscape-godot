# Endless flight: janky clouds and water flicker (fix round)

The user reported two things on main at cc3f6d1e. Some clouds looked like
"weird artifacted shapes", and the water flickered. This round found the
causes in rendered stills and frame bursts and fixed them. The rest of the
cloud look is unchanged.

## Clouds

### Cause 1: mushrooms on stems

The weather map holds one span per layer in each texel: the low layer's
top and base, and the high layer's top and base. Two clouds of the same
layer can overlap in plan with one standing over the other. Examples are a
wisp (base 180 to 320 m) over a mid cumulus, or a puff over or under a fair
cloud. Where the two touched, the texels joined them into a pillar.
Elsewhere, `take()` kept only the thicker one, which cut the other round
it. The result was a flat saucer on a stem over a cumulus, plus bites and
hooks.

In one coastal view (seed 1), the CPU mirror counted 17 wisps. 14 of the
overlapping same-layer pairs involved a wisp, and about 50 involved puffs.

Fix: such a pair is never placed. In `shaders/endless_cloud_march.glsl`,
`recipe` is split into `recipe_shape` and `recipe_lift`, and new functions
`yields` and `clash` decide which cloud gives way:
- A puff yields to a broad cloud.
- A wisp yields to any other cloud.
- Between two puffs, the thinner yields.

Two clouds at about one level, where the upper base is under half the
lower cloud's height (`YIELD_LEVEL`), still merge as before. The broad
clouds other than wisps never yield. Stacked pairs of those are rare: 2 in
that view, both fair over fair. Asking for every texel they cover also
cost too much.

The question is only asked within a puff's or wisp's reach plus 80 m
(`YIELD_NEAR`). Asking only on covered texels left a hooked rim artifact.

The CPU mirror matches: `endless_clouds.gd` has `_recipe_lift`, `_yields`
and `_clash`, and `clouds_in` skips clouds that yield.

Cost: within the noise. On a busy machine, interleaved runs measured 19 to
24 ms with the fix against 22 to 35 ms with `--cloud-stack=old`. A first
version that asked on every texel for every cloud cost 5 to 10 ms; it was
dropped.

Side effect: there are fewer wisps and puffs. In that view the count went
from 546 to 481 clouds: wisps 17 to 5, puffs 353 to 300.

### Cause 2: smooth bells

A small puff (r 23 to 70 m) is only a few weather-map texels across
(15.7 m texels, smoothed over 2). The cloud's lobes and swells come from
noise at 230 m and 95 m tiles, so a near puff drew as a featureless,
flat-based bell.

Fix: thin low-layer cloud (map thickness under 25 m, fully gone by 90 m:
`PUFF_THIN`) mixes in lobes and swells from a 70 m tile (`PUFF_TILE`), so
a puff reads as a small cumulus. Broad clouds are untouched.

### Ruled out

- Valley fog: the bells and stems look the same with `--no-valley-fog`.
- The per-texel meadow lift: turning it off left the bells as they were.

### Flags

- `--cloud-stack=old`: brings back the stacked pairs.
- `--cloud-puffs=old`: brings back the bells.

They use spare march slots `flash.z` and `flash.w`.

## Water

### Cause 1: the sea popped whenever its sheet moved

The sea sheet is snapped to 64 m under the eye (`EndlessLook.step`). The
vertex shader chose which swell waves to hold, and how far the swell
heaves, by each vertex's reach from the sheet's middle. Each snap therefore
changed the swell's displacement at every world point, and the whole
glitter and swell pattern jumped in one frame. At cruise that happens
about every 1 to 2 s.

Measured from a fixed camera: the frame of the snap differed by 1.68 mean
luminance against 0.77 for an ordinary frame. Its second difference spiked
to 1.20 against a 0.50 baseline.

Fix (`shaders/endless_sea.gdshader`): reach is now measured from the
camera, plus `SNAP_SLACK` (32 m). That bound is conservative: the held
waves are never finer than the sheet's own cells, and it is 1 m cells at
the eye as before. After the fix, the same burst has no spike (max 0.52).
The look is otherwise the same. The CPU skim mirror (`height_at`) never
filtered, so it is unchanged.

Flag: `--sea-set=lod_from_eye:0` gives the old behaviour.

### Cause 2: cloud shade on the sea jumped for one frame

The clouds' shade map is redrawn in the compositor at PRE_TRANSPARENT, so:
- the solid land reads it before the redraw, with the published square
  (`zs_cloud_shadow_at`, the previous one);
- the sea is see-through (blend_mix), so it reads it after the redraw.

On each frame the shade square moved (every 23 m of travel), the sea read
the new map with the old square. Its cloud shadows, the sun path's
shadowing and the mirrored clouds were then a texel off for one frame.

Fix:
- The sea gets a `shade_square` uniform: the square actually in the map as
  it draws, set by `endless_clouds.gd` `_fill` through `sea_material`
  (wired in `endless_look.gd`).
- `zs_sea_cloud_shade` and the cloud mirror read it.
- C (clouds off) zeroes it.

A/B on a sliding burst under heavy cloud: identical frames, except that
the old run had a single-frame spike at the snap frame and the new run has
none.

Flag: `--sea-shade=old` brings it back.

### Ruled out by flicker maps (fixed camera, second difference over 10 frames)

- Cloud shadows and the cloud mirror otherwise: the maps were the same
  with `--no-clouds`, `cloud_mirror:0` and `cloud_shade:0`.
- Z-fighting at a river mouth (`--at=-760,-1700`): only the shore foam line
  shimmers, faintly.
- The river and sea join: no flicker found there, so nothing in that area
  was touched.
- The bright patch that sparkles is the sun's path and glitter, not a
  mirrored cloud.

## Proof

- Headless import: 0 errors.
- Smoke PASS, 0 errors, for:
  - `endless_flight.tscn`
  - the same with `--cloud-stack=old --cloud-puffs=old --sea-shade=old`
  - the same with `--water=old`
- Every rendered run (dozens) showed only the usual exit-time "shaders
  never freed" line.

## Stills (git-ignored, this worktree's `captures/cwfix/`)

- `clouds_before_after.png`: left is before (main), right is after. Rows:
  1. the coast play view, where the saucer on a stem is gone;
  2. the bells over the valley;
  3. a zoomed bell, now a lumpy puff.
- `clouds_saucer_crop.png`: the mushroom close up, before and after.
- `flagcmp.png`: `--cloud-puffs=old` against the new puff.
- `water_pop_sheet.png`: top row before, bottom row after. In each row:
  the frame, an ordinary frame-to-frame change, and the change at the
  sheet's 64 m snap (scaled 8x). Before, the snap lights up the whole sun
  path; after, it matches an ordinary frame.
- `ss_glitch_pair.png`: the shade-square glitch frame. It is faint in that
  view; it shows most where a cloud shadow edge crosses the glitter.

The drivers are in `scratch/` (git-ignored):
- `cw_survey.gd`: free or fixed camera, bursts, `--list` clouds via the CPU
  mirror, `--slide`, `--log_shade`, play-camera mode.
- `cw_pairs.gd`: same-layer overlap stats.
- `cw_perf.gd`
- `cw_exp.sh` and `cw_zoom.sh`
- `cw_flick.sh`, `flick.py` and `flick2.py`: flicker maps and series. They
  need PIL; use `/usr/bin/python3` on the Mac.

## Not verified

- By eye in real flight at the user's resolution. The flicker fixes are
  proved by frame bursts, not by watching. If the user still sees flicker,
  the remaining suspects are:
  - the shore foam line's faint shimmer;
  - sun glitter aliasing in rough patches;
  - the foam buffer or depth-map moves, which were not checked.
- Other seeds and moods were surveyed only lightly (seeds 1, 2, 3, 5,
  alpine morning).
- The mid cumulus rims still fray into horizontal "wind-combed" strands.
  That is by design (cloud-shape round), but close up it can read as a
  smear. It was left as is.
- Rare stacked broad clouds (fair over fair) can still form a small
  pillar.
- Cost was measured on a busy machine only.

## Existing tests this breaks

None known. No test covers these shaders or the endless clouds and sea
scripts. The suite was not run.

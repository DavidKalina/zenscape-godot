# Cloud shade flicker on the grass (fix)

Seen flying from the title over the meadows past the first woods: the
shadows on the grass flickered. Turning off the clouds' shade on the land (a
debug key, since removed) stopped it.

The clouds' shade map (`shaders/endless_cloud_march.glsl` `shadow_pass`,
256 texels over 6 km, redrawn every other frame) was read back each frame in
flight. Each new map was compared with the last at the same ground (the
squares' texel offset), counting texels whose sun let through moved more
than 0.05 between two redraws. A drifting cloud's edge moves a few
hundredths of a texel in one redraw.

Before: 120 texels jumped each redraw, at the small puffs' shade. Two causes:

- **The march.** It stepped up the light's line (8 m growing to 50 m) and
  leapt over clear air by the ceiling map. A small puff got one or two
  samples, and whether a step fell just over a block's top changed the
  leap, which moved every sample after it. As the sun turned (the day runs)
  and the eye moved, the puffs' shade jumped. The fix samples a fixed stack
  of heights 10 m apart (`SHADE_PLANE`) and skips the ones the ceiling rules
  out. Each sample slides smoothly, and a skipped one moves no other.
  `--cloud-shade=old` brings back the stepped march.
- **The weather map's grid.** The map sat on the world's grid while the
  clouds drifted through it. A cloud's edge slid between texels as the map
  was read shifted by the drift, then snapped back when a fresh map came in
  (every 8 frames, sliced). The corner is now snapped in the low layer's
  drifting frame (`endless_clouds.gd` `_fill`). The high layer, on its own
  wind, is sampled its own offset within a texel off it (`spare[21]`,
  `scripts/cloud_volume_effect.gd` `LAYER_PHASE`, set by the endless effect
  only). Every map then samples each layer's field at the same points.
  `--cloud-phase=old` brings back the world's grid.

After: 1.5 texels a redraw (1.2 with `--cloud-weather-slices=0`). With the
old grid and the new march it is 3.9. What's left is the clouds' life: each
map holds the clouds' growth at the moment its cycle began, so a swap
brings in 8 frames of it at once.

Look: the same view old and new differs in 0.07 % of pixels by more than
6/255, and the mean is the same. Cost: the shade pass is 0.049 ms old and
0.090 ms new (RTX 4070 SUPER), every other frame.

Test: `tests/test_cloud_shade_steady.gd` (`## suite: gpu`) flies from the
start with the old march, then the new. The old jumps 128 to 140 texels a
redraw (it must pass 30, so the test is seen to catch it). The new jumps
4.9 to 5.1 at this PC's real frame rate (limit 15). The run's exit prints
"4 shaders of type SceneForwardClusteredShaderRD were never freed", as
every windowed endless flight does. `tools/run_tests.py` now files that line
with the other exit leaks, so the test passes with a known engine error.
Run it with `python tools/run_tests.py --rendered --gpu-only --tests
test_cloud_shade_steady.gd`.

Not done: not flown by hand after the fix, and not checked on the Mac.

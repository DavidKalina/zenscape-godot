# Endless flight: cloud shape and placement (handoff)

What changed (shaders/endless_cloud_march.glsl, mirrored on the CPU in
scripts/endless/endless_clouds.gd `_recipe`, `_bubble_span`, `_cloud_floor`):

- An organic field replaces the near-grid. Cells jitter well past their
  middles (JIT), and a two-octave cluster gate (CLUSTER 2600 m) groups clouds
  into fields with clear sky between. Small puffs follow the gate too.
- Kinds: fair (low), mid, tower, row (6-9 bubbles in a line), wisp (thin,
  frayed into strands) and small puffs; 2-9 wobbly bubbles each, sizes
  skewed small.
- No flat bases. Each bubble has its own round belly, with its own depth
  and roundness (belly, qb), and side bubbles hang at their own heights
  (LIFT 0.3), so the underside is a run of lumps. A low cloud over land is
  now lifted whole over the ground (`cloud_floor`: the ground map at 7 points
  under its footprint, plus the meadow clearance for low ones, plus up to
  30 m of its own), so it keeps its belly. Before, the per-texel ground
  clamp cut every low cloud over land to one level line. That clamp is still
  there as a safety net. Past the rims the map keeps the nearest rim's height
  as its base, which stops the smoothing from pulling hanging strands down
  at the rims. The ceiling pass's base bound now has 12 m of margin (it was 4).
- Every pixel is marched by default. The march also leaps by the sample's
  own distance to the cloud, so the field reads fully at 110 steps.

Flags: `--cloud-field=old` (the earlier field), `--cloud-half-res` (the
earlier quarter-res march). The grain fix (cloud-grain-handoff.md) is
unchanged.

Cost (cruise, 1440x900 window on Retina, frame median, back to back):
new 10.4 ms, `--cloud-field=old` 11.8 ms, `--no-clouds` 8.7 ms. The cloud
cost is now 1.7 ms, against 3.1 ms for the old field.

Left open: the CPU mirror leaves out the per-texel safety clamp and the
march's billow and lump noise, as before. Near clouds can look a little
smooth and potato-like up close. The wisps' strands are only lightly tuned.

Captures in captures/cloudshape/: before_* / after_* (the earlier pass),
pre_below.png (flat bases, looking up from the ground), after_below.png,
after_below_near0.png and after_below_near2.png (from below, near clouds),
after2_cruise.png, after2_high.png.

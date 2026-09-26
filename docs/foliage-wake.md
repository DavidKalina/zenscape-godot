# Bigfoot's vegetation wake

Restored from `3614ff4` on `feature/stitched-terrain` (also contained in
`codex/bigfoot-control-sandbox`). The original `foliage_tread.gd` controller and
shader include form the base, with their shader hooks integrated into the current
surface shader. This replaces the rejected procedural shimmy and slowdown.

The inhabited world publishes Bigfoot's ground position and seven fading trail
samples. Flexible low foliage parts and presses down around him, recovering over
five seconds; trees give slightly while their roots remain planted. Native
conifer, broadleaf, layered and redwood trunk/crown materials share a height per
tree type. Imported conifers and broadleaves use the source branch's settings.
Mushrooms without sway remain rigid, as in the source implementation.

Tree contributions now ease in over half a second and fade before the oldest
sample leaves the ring. A soft radial core avoids abrupt direction changes near
a trunk. Low foliage retains the original footprint response. A moving GPU
regression measured the largest crown step at 3.50 pixels with the original
shader and 1.00 pixel with smoothing, at the same camera and 1 m/s walk.

Navigation uses the source branch's trunk-core bounds, keeping the ordinary
50 cm body margin and full clearance for other solids. Visual interest bounds
remain intact for tree contacts. The actor keeps his normal walk. This opens
routes; it does not override destination choice or make water and cliffs safe.

Pickup, hidden residents, cave concealment and geometry replacement clear the
wake. Pause holds its decay. These effects are transient, not saved scenery edits.

`test_foliage_tread.gd` retains the original ring and GPU deformation tests and
adds native habitat core/route checks. `test_cozy_worlds.gd` checks the resident
publisher, native material flags, pickup clearing, regeneration and persistence.

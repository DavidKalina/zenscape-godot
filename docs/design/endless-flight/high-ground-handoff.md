# High ground: tufts gone from altitude, painted ground carries the look

What changed
- `scripts/endless/endless_grass.gd`: `TUFT_TOP` 80 m. The rings' rise rate is now
  max(RISE, LOD.w / (tuft_top - FLAT_UP)), so tufts thin and pull in fast with
  altitude and the far ring is empty (no cells, no draw) by 80 m over the ground.
  Smooth: the same 3D-distance thinning, no pop or ring edge. `--tuft-top=H`
  (0 = the old rule, tufts to about 165 m).
- `shaders/endless_ground.gdshader` (ground/carpet part only): `high_paint`
  (1.0, `--` no flag; shader param) and `high_paint_alt` (35..120 m eye height).
  Over that range the carpet speckle fades out and the turf gets broad light/deep
  and warm/cool patches, soft wind-combed streaks, and darker hollows/creases.
  No river code touched.

Captures (seed 2, heading 200, altitude 10 / 60 / 140 over the start, before and after):
`captures/hg/before_{10,60,140}.png`, `captures/hg/after_{10,60,140}.png`
(git-ignored; in the worktree). Low (10 m) is unchanged.

Smoke: endless_flight.tscn PASS, 0 errors. No tests reference EndlessGrass; none known broken.
Not tuned: streak/patch strengths (0.30/0.34/0.30 in the block after `speck`).

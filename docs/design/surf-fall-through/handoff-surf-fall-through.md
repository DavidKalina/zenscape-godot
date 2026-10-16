# Handoff: steep-ground surf fall-through

Loop `surf-fall-through`, branch `iter/surf-fall-through` (unmerged).
Spec: `spec-surf-fall-through.md`. Trail:
`git log --grep='^ITER(surf-fall-through)' --format='%B'`.

## What's built

- **Reader fix** (`a93cad1a`, `scripts/pilot_physics_ground.gd`): when
  `height_from`'s ray lands more than STEP_UP under the feet, one ray goes
  up; if it meets the land's open top (a ray down from TOWER agrees within
  2 cm), the start counts as inside the land. Every pilot reader going
  through `height_from` (surf, ledge, `_stand_on`, `_footing`,
  `_gradient`) gets it. No cost on flat walking.
- **Surf guard** (`bbe2b6d3`, `scripts/pilot_motor.gd`): when the down read
  is steep but the plain uphill read isn't, `_surfing` rereads uphill in
  0.25 m chained steps through `ground_from`. Heightfield callers leave
  `ground_from` empty and get the old check.
- **Enemies** (`e8a7bbe7`): the test is shared as static `top_over()` /
  `land_top()`; `EnemyField.floor_under` (all its callers) and
  `HeadlessBody._floor` use it.

## Results

Missed slides on steep open turf, main → reader fix → + guard:
editor_mountain 180 → 29 → 23, editor_tarn_peak 107 → 33 → 27,
colonnade_spine 274 → 152 → 134, felled_colonnade 169 → 30 → 22,
coliseum_pit 102 → 21 → 15. The repro flank on editor_mountain slides from
frame 0; he can't walk up it.

Normal ground: per-frame logs identical to main on the aqueduct isle
(including walks off cliff edges), bell_spires, coliseum_pit and
felled_colonnade. Enemy runs identical on flat ground and real edges
(one 1e-6 m blip on a perched inhaler head). Steep-turf enemy probes read
as void: 166 → 26, 111 → 29, 173 → 28, 16 → 10.

## Climbs lost (accepted by the user; no terrain changed)

- editor_mountain: spawn → summit up the east face (stuck at
  (16.0, 1.9, -5.0)); rim routes still reach the summit, slower. Mid flanks
  at 47-53°, and the 49° face at (-3.64, -28.67, 5.48).
- editor_tarn_peak: the stamped mountain at (-20, -2), 47-51°; summit
  routes still pass.
- felled_colonnade: the bank at x 13-51, z -36 to -24; path1 leg 3 now
  fails at the 77-80° bank face near (-40.9, 8.7).
- coliseum_pit: the 50-59° tier banks at x 41-85, z 30-37, incl. the 53°
  face at (73.32, 11.20, 21.20). Its six paths still pass.
- colonnade_spine: one face at (33.4, 29.3, 4.1), 56°.

## Open

- Headless bodies count slopes under 60° as floor, so one roaming straight
  up a steep flank now presses into it for ~7 s until roaming times out
  (before, it turned at the false edge). Climbing rules left alone.
- Still missed: a collided overhang whose underside is also the topmost
  surface; hanging Sides only partly improve.
- `iter/editor-traps` put a convex wedge under editor-carved ramps
  (`bcfee054`) to dodge this bug; now redundant but harmless. Keep or drop
  it on purpose when the two merge.
- No committed tests (prototype round). `test_pilot*` 10/10 and
  `test_*ledge*` 2/2 pass; no tests cover the enemy readers.

## Play it

From the worktree: `godot --path . studies/motif_yard.tscn -- --motif=editor_mountain`
and walk onto the flank near (3.1, 14.6, 2.8), or west from the spawn at
the summit.

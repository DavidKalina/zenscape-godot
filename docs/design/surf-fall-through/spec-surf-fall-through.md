# Spec: steep-ground surf fall-through

Loop `surf-fall-through`, branch `iter/surf-fall-through`, model Opus
(motor/physics). Cap and budget: the iterate skill's defaults.

## The bug

The pilot surfs (slides) only on ground steeper than `slide_auto` (~44°)
that stays that steep for `SLOPE_FAR` (1 m) up and down the fall line
(`scripts/pilot_motor.gd`, `_surfing`). The uphill read goes through
`PilotPhysicsGround.height_from` (`scripts/pilot_physics_ground.gd`), a ray
cast down from ~0.45-0.5 m above the feet. On slopes over ~27° the ground
1 m uphill is above that start, so the ray starts under the land. KitLand's
land collision (`scripts/kit_isle/kit_land.gd`) is a hollow trimesh, so the
ray passes through and hits the collided "Sides" 20-40 m down, or nothing
(-INF). The surf check fails: on `editor_mountain`'s 48.7° flank at
(3.10, 14.58, 2.76), fall (0.56, 0.83), the uphill read is -38.5 m (truth
+1.21 m); the pilot runs down at 4.8 m/s never sliding, stands on it
indefinitely, and walks up it at 2.2 m/s.

Where a convex cliff prism sits under a face, the existing 3 m "inside"
fallback already reads right; only steep ground without prisms is hit.
Designed slides (banisters, copings, the cloister hood roof) are convex
boxes and unaffected. The aqueduct isle's steep ground is >75° cliffs on
prisms: negligible change there.

Same fault, other readers (from code): pilot `_gradient` (0.2 m probe,
>68°), `_stand_on` (>40°), `_footing` (>63°), `PilotLedge.find` via
`top_from` (21-31° inward rise; its 40 m TOWER fallback only works on
convex shapes). Enemies: `enemy_field.floor_under`, `enemy.edge_ahead`
read steep turf as a void edge; `headless_body._floor` skips faces over 60°.

## Done looks like

- On steep open turf (>44°) the pilot slides, standing still or walking
  down, and can't walk up it. The repro flank above: slides from frame 0.
- Normal ground feels the same: per-frame trajectory logs with and without
  the fix are identical on the aqueduct isle (including walks off cliff
  edges), bell_spires and a greybox. Reads at cliff edges in the air stay
  as they were (-INF stays -INF, not "wall").
- A list, in the handoff, of motif routes that were walkable uphill only
  because of the bug and are now slide-only (colonnade_spine,
  editor_mountain, editor_tarn_peak at least). **Do not change any isle's
  terrain to fix them**; softening a slope or adding a step is the user's
  call per motif.
- Enemies read steep turf as ground, not a void edge.

## The fix (option B, in the reader)

In `PilotPhysicsGround.height_from`: only when the down hit lies more than
STEP_UP under the feet, cast one ray up to REACH. If it meets something,
and that something is the open top (a ray down from TOWER lands on the
same height within 2 cm), treat the start as inside the land and use the
existing REACH fallback. Don't use facing: Jolt flips the normal on
back-face hits (`scratch/surf_upray.gd`). Without the top test, reads at
cliff edges in the air change. ~15 lines; no cost on flat walking.
Prototype: `scratch/surf_fixed_ground.gd`. Known limits: a collided
overhang whose underside is also the topmost surface still fools it;
hanging Sides only partly improve.

Rejected: solid prisms under every steep face; a heightfield.

## Tasks, in order

1. **Reader fix.** Port option B into `pilot_physics_ground.gd`. Prove:
   the repro flank slides (standing still and walking down; can't climb);
   flat-ground per-frame diffs show 0 differing lines (aqueduct isle with
   two walks off cliff edges, bell_spires, a greybox); headless
   `python3 tools/run_tests.py --tests 'test_pilot*'` and
   `--tests 'test_*ledge*'`, reporting any failures and whether they fail
   on main too.
2. **Scan and route walks.** `scratch/surf_scan.gd` + `surf_agg.py`
   before/after on colonnade_spine, editor_mountain, editor_tarn_peak,
   felled_colonnade, coliseum_pit; `tools/harness/chain.gd`
   `walk_motif_paths` on colonnade_spine, editor_mountain,
   editor_tarn_peak before and after. Commit a short findings note in this
   folder listing every route that breaks (where, the slope, what it
   was). No terrain edits.
3. **Option A guard (surf only).** In `_surfing`, after the
   `steep <= slide_auto` early return, a chained uphill read (0.25 m steps
   up the fall line, each from the last one's height). Needs a y-taking
   reader; keep the heightfield callables working. Keep it only if it cuts
   the remaining land misses and the flat-ground diff stays at 0.
4. **Enemies' readers.** Give `enemy_field.floor_under`,
   `enemy.edge_ahead` and `headless_body._floor` the same inside-the-land
   test (share the helper rather than copy it). Prove with a real-loop
   check: an enemy on steep turf doesn't stop at a false edge; enemy
   behaviour on flat ground and at real edges is unchanged.

## Checks every task

- Smoke (`tools/smoke.py`): `studies/zenscape.tscn -- --no-title`,
  `studies/aqueduct_isle.tscn`, the motif yard on `editor_mountain`,
  `colonnade_spine` and `editor_tarn_peak`.
- Prototyping rules: no new committed tests, no full suite.

## Tools (scratch, git-ignored; copied into this worktree)

`scratch/surf_walk.gd` (real-input walk/log: `--at`, `--fall`, `--still`,
`--here`, `--all`, `--fix=up`), `scratch/surf_scan.gd` (`--scene=`,
`--per=`, `--fix=up`, `--want=`), `scratch/surf_agg.py`,
`scratch/surf_fixed_ground.gd`, `scratch/surf_upray.gd`,
`scratch/flat_*.log` (earlier normal-ground runs). Once the fix is in the
real reader, the `--fix=up` switch is redundant; compare against main's
reader (or a toggle you add in scratch) for before/after.

Example: `python3 tools/drive.py scratch/surf_walk.gd -- --at=3.099766,14.57934,2.760756 --fall=0.562577,0.826745 --frames=120 [--still] --scene-args --motif=editor_mountain`

## The other loop

Loop `editor-traps` (branch `iter/editor-traps`, unmerged) put a convex
wedge under editor-carved ramps (`Slope.hull()`, KitLand `solid_more`,
commit `bcfee054`) to work round this bug, and adds opt-in `whole_sides`
(commit `a1cf613a`). Don't touch that branch. After this fix the wedge is
redundant but harmless; the merge keeps or drops it on purpose.

# Harness tools, round 1: collider probes and the land-outline check

Two additive tools. `tools/README.md` is not updated yet; its lines are below.

## Collider probes (`tools/harness/drive.gd`)

Each probe returns hit Dictionaries, or `{}`/`[]` for nothing. A hit has:
`collider` (the Node), `path` (relative to the study), `name`, `layer`, `mask`,
`shape` (its index), `shape_type` ("Box", "Convex", "Concave"...), and
`shape_node` (the CollisionShape3D). Ray hits also have `position`, `normal` and
`distance`. `hit_text(h)` turns a hit into one line:

```
Art/NearIsland/Body (Concave) layer 1+12 mask 1 shape @CollisionShape3D@85 at (100.0, 30.0, 15.92) n (0.0, 1.0, 0.0) d 50.00
```

| Signature | Example |
|---|---|
| `ray(from, to, mask := ALL_LAYERS, inside := false, exclude := [], areas := false) -> Dictionary` | `say(hit_text(ray(motor.feet+Vector3.UP*50, motor.feet+Vector3.DOWN*50)))` |
| `pierce(from, to, mask := ALL_LAYERS, most := 8, step := 0.05) -> Array[Dictionary]`: every surface along the line, in order | `for h in pierce(Vector3(x,200,z), Vector3(x,-50,z)): say(hit_text(h))` |
| `what_is_at(pos, radius := 0.25, mask := ALL_LAYERS, most := 16, areas := false) -> Array[Dictionary]`: one entry per shape touched | `for h in what_is_at(motor.feet, 0.6): say(hit_text(h))` |
| `what_is_in(box: AABB, mask := ALL_LAYERS, most := 16, areas := false) -> Array[Dictionary]` | `what_is_in(AABB(p-Vector3(3,0,3), Vector3(6,6,6)))` |
| `colliders(node) -> Array[Dictionary]`: each CollisionObject3D under the node, with `shapes` ({type: count}) and `box` (world AABB) | `for c in colliders(first("Island")): say(hit_text(c))` |
| `collision_box(node, local := false) -> AABB`: `local` works for a piece built off the tree | `collision_box(piece, true)` |
| `hit_text(h) -> String`, `space() -> PhysicsDirectSpaceState3D`, `ALL_LAYERS` | |

`inside` sets `hit_from_inside`. `exclude` takes CollisionObject3Ds or RIDs.
The existing API is unchanged.

Demo (scratch, uncommitted): `python3 tools/drive.py scratch/probe_demo.gd`
runs on the aqueduct isle. It makes 4 checks and all pass.

## Land-outline check (`scripts/shared/kit_land.gd`)

`KitLand.island` now checks `spec.outline` before it builds and calls
`push_warning("KitLand.island [name=.., seed=.., from (x, z)]: outline ...")`
for each problem it finds. The backtrace names the calling motif. The check
flags:

- fewer than 3 points, or no area (this includes a symmetric bowtie whose lobes cancel);
- self-intersection: edge i crosses edge j, and the warning gives the point. Edges
  that only meet at a repeated point (a closing point given twice) are not
  flagged;
- the wrong winding, but only when the spec sets `winding` (1 = counter-clockwise,
  `area > 0`, the winding Geometry2D's clip/merge returns for a boundary;
  -1 = clockwise). A clipped hole passed in as land then warns.

Why winding is opt-in: KitLand accepts either winding (`outward()` checks the
sign, and KitFlora uses |area|), and existing content uses both. With an
always-on winding check, 27 islands warned. They included the main aqueduct isle
(seed 12) and islands in coliseum_pit, face, felled_colonnade, haulway,
lamplighters_stair, procession, serpent_crossing, stacked_court and weir_stair.
None of those is a bug.

New API: `KitLand.outline_problems(outline: Array, winding := 0) -> PackedStringArray`
(e.g. `KitLand.outline_problems(Array(part), 1)` on a clip result), and
`KitLand.check_outlines := true` (set it false to silence the check). The new spec keys
are `winding` and `name` (`motif`/`id` also work). The check only reads the
outline and draws nothing from the rng, so every build is unchanged.

**What existing content trips (not fixed):** one island. In the `face` greybox, ridge
block 2 (`gb_face.gd` `ridge_blocks()`, seed 7707) folds back at its square end:
"edge 4 crosses edge 6 near (-38.8, -40.9)". Nothing else is flagged: all 17 greybox
slugs, all 4 `editor_*` motifs, the kit ids bell_spires, sundered_gorge,
colonnade_spine, stair_clouds and broken_ring, `studies/aqueduct_isle.tscn` and
`studies/zenscape.tscn` (with and without `--no-title`).

Scratch (uncommitted):
- `scratch/outline_check_demo.gd` (`python3 tools/godot.py --script res://scratch/outline_check_demo.gd`):
  good, reversed, lopsided and even bowtie, repeated closing point, two points,
  and a clip hole. It then builds a bowtie island and a reversed `winding: 1`
  island, and both warn.
- `scratch/outline_survey.sh`: the smoke survey above, with logs in `scratch/outline_survey/`.

## README table lines for a later round

```
| Who's at a point, what a ray hits | in a driver: `say(hit_text(ray(a, b)))`, `pierce(a, b)`, `what_is_at(p, r)`, `what_is_in(box)`, `colliders(node)` (drive.gd, Collider probes) |
| Check a land outline (bowtie, wrong winding) | `KitLand.outline_problems(outline, winding)`; `KitLand.island` warns on its own |
```

## Tests

No existing test breaks. The warnings are only reported by `tools/run_tests.py`
and do not fail a run. The full suite was not run. No tests were added.

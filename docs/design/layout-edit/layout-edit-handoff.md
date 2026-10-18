# Layout edit, round 1: handoff

An in-game edit mode on the aqueduct isle (the game). It moves the ring
route's rings, slabs and crags by hand and saves them to a per-scene file.
The game builds from that file on the next load.

## Launch

Any editor or debug run of the game or the isle, where the developer keys
are on (`scripts/kit_isle/dev_keys.gd`; a release export doesn't get it):

    godot --path . -- --no-title [--layout=/path/to/file.json]
    ./run-zenscape.command      (Begin, then F4)

On foot, press **F4**. No extra flag is needed. With the dev keys off
(`--no-dev-keys`, or a release export), the editor node is never made.

## Keys (edit mode)

| Key | Does |
|---|---|
| F4 | in/out. Out drops him where the camera's middle looks (on what the ray hits, facing the view), else back where he stood |
| RMB hold + move | look |
| W A S D / Q E, Shift | fly / down, up; fast |
| wheel (nothing selected) | fly speed |
| LMB | select (yellow box); drag moves it in the level plane at its own height (0.05 m snap) |
| wheel / PgUp PgDn | height 0.25 m (Shift: 1 m) |
| Z / X | turn 15 deg about world up (Shift: 5) |
| T / G | tip 15 deg about its own x (Shift: 5) |
| C | duplicate (rings and slabs) 3 m to the right |
| Delete / Backspace | delete |
| 1 / 2 / 3 | add an air ring / a bob slab / a ring-stair slab (7 pumps) where the view looks |
| Ctrl/Cmd+S | save |
| Esc | the pause menu, as before |

The hint text sits top left. The status line under it shows the selection,
where it is, its yaw and tip, and `[unsaved]`. Undo isn't built yet.

## Code

- `scripts/layout_overrides.gd`: the generic lookup. A placer calls
  `xform(name, coded)`, `deleted(name)` and `track(name, node, kind, coded)`.
  It also has `begin(scene_id)`, `apply`/`current` by kind (`layout_place`/`layout_pose` on the
  node if it has them, `land` = node offset from its coded transform),
  `build_added(host)`/`spawn` and `save(gone)`.
- `scripts/interactables/ring_route.gd`: every ring, slab and crag goes
  through `_ring`, `_slab` and `_land` by name. The names are:
  `ring_route/crag_1, outcrop, slide_rock, far_crag, catch_crag,
  chain_slab_1..3, kicker_slab, stair_slab, stair_ring_1..4, ring_a, ring_b,
  last_slab, last_ring, catch_slab, catch_ring_1..3`.
- `air_ring.gd` / `foot_slab.gd`: `layout_place(t)` sets the rest pose and
  `transform` (the slab forces its body's update). `layout_pose()` reads it back.
- `scripts/layout_edit.gd`: the editor node. `studies/aqueduct_isle.gd`
  `_build_art` calls `begin("aqueduct_isle")` before the foot route, then
  `build_added`, then adds the editor if the dev keys are on.

## File format

`layouts/aqueduct_isle.json` (none committed; with no file the game is as
before), or the file named by `--layout=PATH`:

```json
{
	"version": 1,
	"moved": {
		"ring_route/outcrop": {"pos":[233.0,30.0,-13.65],"rot":[0.0,0.0,0.0]},
		"ring_route/ring_a": {"pos":[341.95,42.75,-15.2],"rot":[81.41,105.0,0.0]}
	},
	"added": [
		{"kind":"air_ring","name":"added/air_ring_1","pos":[314.5,42.2,-14.05],"rot":[0.0,0.0,0.0]}
	],
	"deleted": [
		"ring_route/chain_slab_2"
	]
}
```

`rot` holds the basis's Euler angles in degrees (Godot's YXZ order). Each
moved object is saved at its absolute transform. Nothing that depends on
it follows. Possible follow-up: "move as group" (a crag with its slab and
rings). An added `bob_slab` has `"pumps"` only when they aren't 6. A save
lists only objects that are off their coded transform.

## Performance

A move sets one node's transform: a ring's `_home`, a slab's `rest` plus its
body, or a crag's node, whose collision goes with it. Nothing rebuilds,
not even on release. Picking runs only on click: one physics ray plus a
screen-space test over the ~22 named entries. When edit mode is off the
node's `_process` is disabled and `_input` checks one key. While editing,
the pilot's `tick` doesn't run (`study.scripted`), so the pieces hold still.

Rendered at 1440x900 (Retina 3024x1898) on the slide perch, Forward+, the
same view, 220 frames each (`scratch/layout/perf_drive.gd`, a real mouse
drag of `catch_ring_1` in circles):

| mode | Mac cap (60) | uncapped fps (mean ms / p95 ms) |
|---|---|---|
| play | 60 | 101 (9.9 / 13.2) |
| edit, idle | 60 | 109 (9.2 / 10.8) |
| edit, dragging a ring | 60 | 100 (10.0 / 12.5) |
| play, after | 60 | 106 (9.5 / 12.7) |

Dragging costs the same as play, within noise.

## Proof

- Headless import, plus a smoke of `studies/zenscape.tscn` (also with a
  layout file) and `studies/aqueduct_isle.tscn`: 0 errors.
- `scratch/layout/edit_drive.gd` (git-ignored) passes 25/25 through real key and mouse
  events. It covers F4; clicking ring_a; a drag east; +1 m on the wheel;
  Z; 1 adds a ring; clicking and deleting chain_slab_2; picking the outcrop by
  its turf and dragging it; Ctrl+S; reloading the scene (ring, outcrop, added
  ring back, slab still gone); F4 out over the moved outcrop; he lands
  on it, stands, walks and jumps.
  `python3 tools/drive.py scratch/layout/edit_drive.gd -- --scene-args --layout=/tmp/le_test.json --ledger=/tmp/le_ledger.json`
- Existing tests: none reference the ring route. `test_aqueduct_isle_plane.gd`
  ("R3 puts the camera back...") fails, and it fails the same way on main
  without this change.

## Missing / known gaps

- **A crag's grass and flowers don't follow a live drag.** Flora is grown
  once over the registered turf. The crag moves and its grass stays hanging
  in the air until you save and reload; on reload the flora grows on the
  moved outline. The crag's outline in the isle's gap test also updates
  only on reload.
  Deleting a crag hides it and turns its collision off; its grass stays until
  reload.
- No undo. Crags can't be duplicated or added. There's no grid toggle,
  no gizmo handles (moves are in the level plane, height by wheel), and no
  multi-select or move-as-group.
- `--foot-at=ring_slide/ring_far` spots and the route's standing-stone
  markers still use the coded spots.
- The file is written under `res://` (fine from the editor/debug runs; an
  export would need `--layout=` to a user path).
- **Not registered yet:** everything outside the ring route. That covers the aqueduct foot
  route's balustrades, ropes and beams, the ferry (a drift slab with a path),
  the first bob slabs and rings to the perch, the stair to the clouds, kit
  caches, traps (sluice), the isle's islets and ruins, and the route markers.
  To opt one in, place it through `xform`/`deleted`/`track` (and give the
  node `layout_place`/`layout_pose` if its pose is not just its transform).

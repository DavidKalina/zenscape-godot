# The Hollow Keel: handoff

Branch `look/motif-hollow-keel` (from main 3a0aef65). Not merged, not pushed.
The fifth ruin motif isle in the aqueduct isle's sky.

## What it is

A medium isle (plate about 94 x 80 m) that looks modest from above: turf with
a gentle swell and a broken chapel (rose gable, lancet walls, buttresses, the
arch you come in by, broken piers). The surprise is underneath. The kit's
colossus hall (`scripts/ruin_kit_hall.gd`, ten bays, 80 m) hangs under the
plate, open at both mouths and breached along its sides. The plane flies in
under the isle's edge, weaves the columns and ties, and out under the other
edge. Rock crags hang from the plate's underside either side of the hall and a
boat-shaped hull under its floor (porches beyond both mouths). Roots and ivy
hang over the mouths and breach heads (`RuinKit.Build.hang`).

On foot: a shaft is cut in the chapel's floor (a real hole in the turf mesh,
the plate's cut face showing round it) over the hall's three open bays. Three
grand stairs switch back down it (4.48 m each, 13.44 m in all) to the hall's
floor, with a stone turn slab between the second's foot and the third's head.
The east porch has a rope bridge to a small hanging islet (the lodestone rests
there).

Card: "The Hollow Keel", "Under the grass, a hall that was never told it flew".

## Run

```sh
./run-hollow-keel.command [--fly] [--look=rosewater_dusk]
zsh tools/hollow_keel_captures.sh DIR [above below west_mouth inside shaft stairs porch east_mouth]
godot --headless --path . --script tests/test_hollow_keel_isle.gd
```
Also in the scene picker (Ruins, "The Hollow Keel"). Same keys and flags as the
other kit isles. The start is before the chapel's arch, facing the shaft.

## Placement

`scripts/kit_isle/motif_sky.gd`: PLACES offset (285, 16, 370), MIDDLES (80,-15),
REACH 62. Middle at world (365, 355), turf at 46 m, hull bottom about 31 m.
468 m from the aqueduct isle, 294 m from the bell spires, 305 m from the
cloister tarn. The first try at (380, 380) was 507 m out and failed
`test_aqueduct_isle_sky`'s 500 m limit, so it moved. The islet hangs 72 m east
of the middle, outside REACH's circle.

## Files

- `studies/hollow_keel_isle_art.gd`: geometry (plate with shaft, skirt, soffit,
  crags, hull, hall plans, stairs, chapel list, islet, rope bridge ends, plane
  and foot tokens).
- `scripts/kit_isle/motif_hollow_keel.gd`: the `KitMotif`.
- `studies/hollow_keel_isle{,_life,_sky}.gd`, `.tscn`, `run-hollow-keel.command`,
  `tools/hollow_keel_captures.sh`, `tests/test_hollow_keel_isle.gd`.
- Appended edits: `motif_sky.gd` (PLACES, REACH, MIDDLES), `scene_catalog.gd`,
  `tests/test_aqueduct_isle_sky.gd` (source list, id list),
  `tests/test_kit_clouds.gd` (`places().size()` 4 -> 5).

## Plane lines (all in the art's `plane_tokens`)

- `hk:undercroft`: 10 tokens down the lane (z +6.3 from the middle, 2.4 m over
  the floor), mouth to mouth. The lane is the hall's own generous line.
- `hk:breach`: from the lane out through the first flyable south breach.
- `hk:keel`: one token under the hull.
Clearances (tested): a 2.0 x 0.5 x 1.4 m slab swept down the lane over 96 m
hits nothing and has 0.9 m to spare each side. The stairs leave the lane only
2.4 m between them and the south column row in the three open bays. The tight
optional lines are the hall's own (screens with knife slits, narrows, ties).

## Tests run (headless, one at a time)

| Test | Result |
|---|---|
| Import | clean |
| `test_hollow_keel_isle.gd` (new) | PASS: triangles, lane clear, 0.9 m spare, 14 plane tokens in open air, breach line, plate over hall, stairs walked chapel to floor, hall to porch to bridge to islet walked, 6 foot tokens in open air, songbird flocks |
| `test_motif_sky.gd` | PASS |
| `test_aqueduct_isle_sky.gd` | PASS (5 motifs) |
| `test_kit_clouds.gd` | PASS |
| `test_isle_lock.gd` | PASS |
| `test_scene_picker.gd` | PASS |

Full suite not run. `known_failures.txt` untouched.

Cost: 324k static triangles (the others ~250k), flora about 1.7M instanced; the
standalone builds in about 3.2 s headless. Rendered frame time in the
standalone about 17-38 ms uncapped on this Mac, not profiled further.

## Looks checked (rendered captures, standalone)

From above it is just turf and the chapel. From below the crags and hull read
well. The hall interior is readable but dim, with sun pools on the floor
through the open bays and mouths; not pitch black. The stairs themselves read
very dark (the stair pieces carry no shelter bounce).

## Open issues

- The stairs are dark; a shelter fill for the grand stair would help.
- The test crosses the second stair's foot to the third's head with one jump
  over the stair cheeks (curbs); a stick-only crossing stalls on them.
- Not checked rendered: the isle placed in the aqueduct sky (distance read,
  LOD), roots/ivy over the mouths, the chapel's piece orientations up close
  (buttresses' facing), the crags' colour from below (reads blue-black).
- Interior light under the whole roof relies on the ruin stone's shelter
  bounce; a few roof gaps would add shafts but the plate is over them.
- The hull's top ring is a flat stone cap, so the shelf outside the hall walls
  is bare stone, no grass.
- Only the south wall's flyable breach is a token line; the north's are open
  but untokened.

## Fix round (look/hollow-keel-fixes)

- Stairs: `RuinKit.grand_stair` takes an optional `shelter` callable (default none, so other isles are unchanged); the shaft's stairs and turn slab pass `Keel.stair_shelter(k)` (0.75 / 0.9 / 1.0, deeper = more), the same vertex-alpha bounce the hall uses. Readable now, not washed out; the hall interior was already readable and is unchanged.
- Walk: the third stair's west cheek stood 0.34 m over the turn slab. The turn slab now carries a ramp up over it and a deck across (`CURB`); the test walks the whole descent stick-only (jump removed).
- Crags/hull/soffit: faces lifted and warmed (`CRAG_LIFT`, `HULL_LIFT`, `SOFFIT_LIFT`), crags' rim moved to their own top. Reads about like the aqueduct isle's keel from below, but still navy-dark in the plate's shadow; the flat soffit stays near black. Not fully fixed.
- Shelf outside the hall walls: painted turf (plate turf tone) instead of stone. No plants: the flora pipeline raycasts from above onto one site and the plate covers the shelf, so growing there needs a second site (shared code). Not done.
- North-breach plane line: not added.
- Captures: `docs/scenic/captures-hollow-keel-fixes/` (before-/after-).

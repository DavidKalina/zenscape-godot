# Stair to the Clouds: handoff

Branch `look/motif-stair-clouds` (from main 3a0aef65). Not merged, not pushed.

The fifth ruin motif isle in the aqueduct isle's sky: a small round isle, the tallest of them, a stepped mesa of dark faceted rock over a low lawn. Card: "The Stair to the Clouds" / "A hundred and ninety-two steps to an open gate" (placeholder, like the others).

## Run

```sh
./run-stair-clouds.command            # on foot on the lawn, looking up the stair
./run-stair-clouds.command --fly
godot --headless --path . --script tests/test_stair_clouds_isle.gd
zsh tools/stair_clouds_captures.sh OUTDIR [flags]
```
Also in the scene picker (Ruins). Keys and flags are the aqueduct isle's.

## Shape (studies/stair_clouds_isle_art.gd, scripts/kit_isle/motif_stair_clouds.gd)

- **Plan.** A nonagon round O (80, -10) in the shared frame. The core inside is four wedge terraces, 8.96 m apart (first 8.96, summit 35.84 over the lawn). Outside it, a 6.4 m strip carries the stair. Side 9 faces south and is the entry: a flat lawn disc (r 11) off it.
- **The stair.** Eight kit `grand_stair` flights (4.48 m each, 192 steps), one per side, climbing round the mesa once, on plinths at each foot's height. A pad joins each pair at the vertices. Each even landing is flush with the terrace it hugs (a walk onto it); the odd ones are ledge shrines.
- **Shrines.** Piers, chests, a fallen pier on the landings; a chest, floor slabs, a broken arch and piers on the terraces. Summit: a lone `arch` gate on the south rim, a broken turret, two lancet walls, floor slabs.
- **Pinnacle and slot.** A small hanging rock 13.8 m off the summit's south wall, over the lawn, joined to the rim by a live rope bridge on `bridge_anchor`s. The gap between wall and pinnacle is the plane's slot (it is a gap, not a tunnel: the ground is a heightfield).
- **Land.** `KitLand.island` over a stepped height function (sheer steps via cliff points), sides hung from the rim with a trimesh "Sides" body so the plane meets the plinths.
- **Plane tokens.** `sc:slot` (in over the lawn, between wall and pinnacle) and `sc:corkscrew` (round the outside of the stair past each landing, over the summit).
- **Foot tokens (6).** Landings 1, 3, 5, 7, the gate, the pinnacle.
- **Perf.** About 333k static triangles (mesa 8 stairs make most), ~3.3k grass tufts. Standalone rendered: 17-27 ms a frame on this Mac with other things running.

## Placement

`motif_sky.gd` PLACES offset (440, 14, -254.6): middle world (520, -260), lawn at world y 44, summit y 79.8. REACH 33, MIDDLES (80, -5.4). 335 m from the bell spires (nearest), about 340 m off the hall chain's line, clear of the towers' keeps.

Edits to shared files are appended lines only: `motif_sky.gd` (PLACES, REACH, MIDDLES), `scene_catalog.gd`, `test_aqueduct_isle_sky.gd` (the two id lists), and `test_kit_clouds.gd` (`places().size() == 4` loosened to `>= 4`; it will break again for every added motif otherwise).

## Tests (headless)

| Test | Result |
|---|---|
| Import | clean |
| `test_stair_clouds_isle.gd` (new): whole climb walked stick-only to the gate, three landings onto their terraces, the rope bridge to the pinnacle, tokens taken, plane tokens clear, lawn sound, triangle budget | PASS |
| `test_motif_sky.gd` (lands the plane on it by hand, grass, birds, tokens, bridge) | PASS |
| `test_aqueduct_isle_sky.gd`, `test_kit_clouds.gd`, `test_isle_lock.gd` | PASS |

No full suite run.

## Open issues

- **Looks, from four rendered captures only.** The sheer walls are long thin facets and read dark and streaky, and the stair is in deep shadow in the morning look. They want intermediate facet points on tall cliffs (KitLand `cliff_points` gives one mid point) and a look pass.
- **Corkscrew is untested in flight.** Only that its tokens stand in open air. The slot is a wide gap, not a tight thread.
- Rope bridge on foot walked at the deck's rest only. Wall kicks, ledge catches on the plinths and the pad shrines' reach are unproven.
- The sky's offset was not validated by flight; the plane approach to the lawn is the headless hand landing only.
- The odd landings are a 4.5 m wall under the terrace: a ledge, not a way onto a terrace.
- The isle is larger than briefed (reach 33 m, 333k tris) because grand-stair slope fixes the climb at about 100 m of path.

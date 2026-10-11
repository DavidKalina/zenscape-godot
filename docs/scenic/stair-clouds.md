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

## Look fix round

Branch `look/stair-clouds-walls` (from main 4a1658e3). Everything stays in `studies/stair_clouds_isle_art.gd`. No shared code changed, so the other isles' layouts can't have moved. The collision is exactly as before, because only the drawn meshes change.

- **Walls drawn as faceted basalt** (`dress_walls`). `wall_runs` finds every step of the height function by sampling across each line where the plan can step: each side's core face and strip edge, each pad's ends, each vertex's ray and the lawn's rim. The heightfield's slivers in "Crags" within 1 m of a run are dropped. The sides' upper rings (any face above TOP−4.6) are dropped too. In their place is "Walls", a `KitLook.RockMesh` lattice of facets about 2.4–4.4 m wide and 4.6 m tall. Its rows slant, and each inner point is set back 0.05–0.75 m into the rock (plus a per-column lean). The lip and the ends sit flush. Each wall's foot is kicked 0.85 m over the turf's edge. The rim facade runs down to TOP−7.5, drawn 15% in toward the middle, over the kept rock rings. The facets are painted by depth under their own rim (the topsoil/clay/shale skin, then the basalt beds), like the islets.
- **Stair lit in the mesa's lee** (`lit_under_wall`, `wall_shelter`). This reuses the halls' bounce: the stone shader's `shelter_fill`, with the shelter in the vertex alpha. The eight legs and the pad shrines get 0.48–0.8 shelter, more under a tall wall. In the morning look their treads now read as warm grey in shadow. At noon (ocean_light) the sunlit flights stay stone-grey and are not washed out.
- **Slot left as is.** The slot is a heightfield wall plus a small hanging pinnacle. Moving the pinnacle in by a metre or two would not make it read as a thread; that would need a roof (an arch or a fallen lintel over the gap). Not done.
- Triangles: 331.7k (was ~333k).

Captures: `captures/stair-clouds-walls/{before,after}/` (gitignored), alpine_morning and ocean_light, views establishing / south / wallclose / westplane / stairwest / stairnorth / onfoot (`/tmp/sc_shots.sh`-style runs: `--preset=<look> --at --look`).

Open:
- Seen edge-on (the summit pad's west face from the south lawn), a wall still reads as a narrow dark column.
- Faces of the core in full shadow are near black at noon from the south. That is the rock material's shadow, the same as the islets'.
- The lawn and pad turf in the mesa's shadow stays dark. Only the stone gets the bounce.

Tests (headless): `test_stair_clouds_isle`, `test_motif_sky`, `test_aqueduct_isle_sky` PASS.

## Rock round

Branch `look/motif-rock` (from main 5430e81b). Only `studies/stair_clouds_isle_art.gd` changed; no shared code.

- **Skirt** (`skirt`). The island's ring sides (`KitLand.island`'s "Mesh") and the old rim facade are gone. Round the rim stands a column of rock every 2.4–4 m: the lip flush with the turf (and stepping where the rim steps), then buttresses that wander round the rim (up to 3.2 m out), sharper crags at the nonagon's corners (2.6–4.4 m), bays set in, bulges and hollows down each face, a batter, and broken tiers of talus ledges at about 8, 19 and 28 m that hold for a stretch and break off. Under the lawn level it tapers in column by column, each its own drop with the odd spur, to a keel 27 m under the lawn, off the middle. It is drawn and collided ("Sides") from the same faces, so the plane meets what it sees. Near the lawn the columns stand out little.
- **Summit spur** (`corner_spur`). The 36 m sheer face where the summit pad stands out of the summit wall over the lawn (the edge-on dark column) has a fluted spur of rock filling the corner, from 1.6 m under the pad's lip down to the lawn, fanning out like talus. Collided.
- **Tors** (`tor`, `TORS`). Two faceted rock tors on the summit's outer corners (vertices 6 and 0) break its square top. Collided.
- Every terrace, landing, the stairs, summit, bridge and walking route are unchanged (the heightfield and its collision are untouched; the inner step walls are as the walls round drew them).
- Fallen lintel over the slot: not done.

Triangles: 333.1k (was 331.7k–332.1k).

Tests (headless): `test_stair_clouds_isle`, `test_motif_sky`, `test_aqueduct_isle_sky` PASS (plane tokens 0.9 m clear, whole climb, landings, bridge, lawn).

Captures (gitignored, alpine_morning): `captures/motif-rock/{before,after}/stair/` (approach, establishing, below, west-low, close, edgeon), reference aqueduct isle in `captures/motif-rock/ref/`; intermediate rounds `r1`–`r4` (`r4/stair/summit.png`, `spur.png`).

Open:
- From the approach it reads as a craggy stepped mesa with a tapered keel, but the core's tall inner step walls are still sheer and the summit block's edge stays fairly square from some angles; the mesa is still tall and steep by design.
- Faces away from the sun read navy-dark, as the reference isle's do from the same angle (sky ambient).
- The spur only helps at the base; from the south lawn the pad's face above it still reads as a tall dark slab.

# Model audit: why the built-in-code models look flat (2026-10-28)

Asked: an audit of every 3D model in endless flight that isn't made in
Blender, why they look flat and badly lit, and what Blender would fix.

Stills (local, git-ignored; re-take with the drivers below):
`scratch/audit/sets/*.png` (Amberlands set pieces, far and near),
`scratch/audit/plane/*.png`, and before/after sheets
`scratch/audit/ab_*.png` (top-left: as shipped; top-right: `--ssao=1`;
bottom-left: `--ssao=1` with the Amberlands stone lift cut to
(1.7,1.45,1.1) and fill 1.6, a temporary edit that was reverted).
Driver: `scratch/sets/sshots.gd` (`name@near@<dist>@<up>` mode added),
`--scene-args --world=amberlands --no-title`.

## What's made where

| On screen | Made by | Shading |
|---|---|---|
| Ruins: set pieces (nave, belfry, rose gate, colosseum), bridges, land arches, halls, rival gates | Code: RuinKit convex blocks, `scripts/ruin_kit.gd:2806` (`Build.solid`), flat normals (`:2915`), no UVs (`:3112`) | `shaders/ruin_stone.gdshader` / `gothic_stone.gdshader` → `folk_surface.gdshaderinc`, vertex colour + `kit_weather` noise + `stone_moss` |
| Ivy and hanging growth | Code: quad stems and two-triangle leaves, `scripts/ruin_growth.gd:332,356` | `shaders/ruin_growth.gdshader`, flat tint (`gothic_growth.gd:646`) |
| Player plane, rival, traffic | Code: `scripts/plane_figure.gd:214` (`_hull`, `_wing`, `_join`) | `shaders/plane_surface.gdshader` |
| Rocks, sea stacks | Code: lofted rings, smooth normals, `scripts/endless/rocks/rock_build.gd:43,229` | The ground shader's rock path, world triplanar relief tile (`endless_rock.gdshaderinc:186`); tile baked with numpy, not Blender (`art/blender/rock_erosion/`) |
| Birds, fish | Code: `songbird_body.gd:92`, `life_models.gd:228` | Their own shaders |
| Spruces | **Blender** glb (`zenscape-spruce-sprays.glb`, `hero_trees.gd:22`), far ones as baked sprites | `spruce_paint.gdshaderinc` |
| Terrain, grass, sea, clouds | Code | The land's shaders (the user likes these) |

The Amberlands has no trees, so **nothing in the Amberlands comes from Blender**.
Every surface there is painted with world-space noise and vertex colours,
with no authored textures.

## Why it looks flat, worst first

1. **Light in the shade ignores occlusion.** The stone takes its sky
   fill as `EMISSION` (`folk_surface.gdshaderinc:178,183,186`): one colour
   per face direction, the same on a wall in the open as deep inside an
   arch. Godot's SSAO only darkens ambient light, never emission. That's
   why SSAO "changed no pixel" and was turned off
   (`endless_look.gd:176-191`), and why the `--ssao=1` A/B barely moves.
   So the only depth cue left is the sun's shadow map. Shaded walls go
   one flat olive, recesses don't darken, and the colosseum's ambulatory
   is a uniform dark slab (`sets/colosseum_near45.png`). Only the halls
   get a shelter term (vertex alpha); the set pieces and bridges don't.
2. **The stone is lifted 3x to compensate.** The Amberlands stone is the
   cut kit isles' dark Olmec basalt (`kit_weather.gdshaderinc:3-16`),
   multiplied by `STONE_LIFT` (3.0, 2.55, 1.95) with its fill tripled
   (1.2 → 3.6) (`land_arches.gd:27,104-106`). With the fill nearly as
   bright as the sun, lit and shaded faces converge, which flattens the
   form further. Cutting the lift doesn't help (`ab_*` bottom-left): the
   stone just goes muddy and is still flat. The brightness isn't the
   problem; the missing occlusion is.
3. **Pale splotches read as missing textures.** The worn and chipped
   patches are painted `weather_pale` (1.55x) on top of the lift
   (`kit_weather.gdshaderinc:40,192`). That was right for dark basalt, but
   on gold stone it clips to near-white blobs with hard edges (belfry,
   colosseum steps, nave). It's the single most "broken-looking" thing on
   screen.
4. **No detail at the size of a block.** Below the block itself, the
   faces have only noise, stacked at a few scales (washes, flecks,
   mottles): no mortar joints with depth, no cut-stone faces, no cracks
   with shadow. Up close it reads as sponge-painted camouflage on flat
   boards. From afar the per-face colour steps and pale blobs shimmer
   (the colosseum glitters at 1 km, `sets/colosseum_far.png`; MSAA is 2x).
5. **The edges are hard facets, not worn edges.** The chamfers are flat
   4.5 cm planes (`ruin_kit.gd:360,2449`). A facet tilted toward the sun
   lights fully, so each edge draws a crisp bright gold line, like CG
   trim (the nave's buttresses). Worn stone gives a soft highlight
   instead.
6. **The ivy reads as scraps.** Its leaves are flat two-triangle shapes
   with no texture and no alpha. Against the sky they read as dark
   chevrons or burnt paper (belfry, rose gate).
7. **Odd bits seen in passing:** bright yellow triangle shards floating
   on the shaded wall inside the colosseum's ambulatory; the
   ambulatory's vault underside reads as wooden planks (the
   crack/tooth relief stretched over a curved soffit). Both need a look;
   cause not traced.

The plane holds up better: smooth hull, clear shapes, sensible colours.
But it's plain: flat cream fabric with no rib tapes or stitching, no
panel lines or wear, and no occlusion where the struts meet the wings.
It's the one model on screen 100% of the time.

Rocks and sea stacks are mostly fine (smooth normals, world-space
relief). The sea cliffs' strata read well. Far hills show large flat
triangles (`sets/rose_gate_near35.png` background), but you're happy
with the terrain, so it's left alone here.

## What would make it look much better

The first two need no Blender and lift *everything* (ruins, bridges,
arches, halls) at once. Blender comes in from 3 on.

1. **Make the shade light occlusion-aware** (code, biggest single win).
   Either:
   - **(a)** Bake sky visibility per vertex at build time (a few rays
     per vertex, generalising the halls' shelter alpha to every piece),
     and multiply the emission fill by it. Large faces would need
     splitting so the occlusion has vertices to live on. It costs
     build time, not frame time.
   - **(b)** Move the fill out of emission into real ambient light so
     Godot's SSAO works. Simpler, but it's the 2.3 to 3.2 ms on the M5
     Pro you already traded away.

   Take (a), and A/B it against today before merging (per "Clean look
   lost the A/B").
2. **Quick fixes to the stone paint** (code): calm `weather_pale` on
   lifted stone so the worn patches stay stone-coloured, and give the
   chamfers a soft normal instead of a hard facet. This is a one-round
   tweak, judged by eye.
3. **A real stone material made in Blender.** This is where Blender pays
   off most per hour. Sculpt a tileable patch of cut and weathered stone
   (block faces, mortar joints, chips, cracks, worn edges) and bake
   albedo, normal, AO and height (1-2k, tileable). Apply it in the stone
   shader by triplanar or box projection in the piece's own space (the
   kit's stone never moves, and its blocks are boxes, so no UVs are
   needed), keeping the vertex colour and moss as tints on top. Every
   kit piece gets texel-scale detail and crevice darkness at once, with
   no change to the geometry, colliders, breaks or openings. Two or
   three variants (ashlar, rubble, gothic dressed stone) cover the
   Amberlands.
4. **Blender ivy cards.** Model a few leaf clusters and render them to
   an alpha atlas (a leaf-card texture), then swap the two-triangle
   leaves for alpha-cut cards with that atlas. The cost is about the
   same and the read is far better.
5. **Blender hero modules for the set pieces.** Only after 1 to 3, and
   only where the kit still looks blocky. The colosseum is the best
   candidate: one bay is already built once and repeated by MultiMesh
   (`ruin_kit_colosseum.gd:668`), so a sculpted, baked Blender bay
   (sculpt high, bake low: normal and AO maps on a 5-15k-triangle bay)
   would drop straight in. The nave bay, rose tracery and belfry could
   follow. Constraints:
   - The pieces are breakable (`break_kinds.gd:75`). Keep the kit's
     blocks as the collider and break source, and swap only the visible
     mesh, kept within a few cm of the kit's shape so the knife slots and
     openings stay honest.
   - A fixed bay means less variation per piece; the fallen side and
     broken arena can stay kit-built.
6. **The plane in Blender.** It's always on screen, so it's worth it
   once the world is fixed. Build a Blender biplane with a baked AO map,
   a fabric rib normal map, panel lines and light wear, and keep the
   part names the flight and crash code reads from `plane_figure.gd`.
   The concept .blends in `art/blender/plane/` (ruin and stone planes)
   aren't in the game and don't match the current plane; it would be a
   new build.
7. **Leave for now:** the rocks (optionally, later, swap the numpy
   relief tile for Blender-sculpted rock tiles), birds and fish (small
   on screen), terrain and grass.

### Model-budget tricks that apply (`docs/art/model-budget.md`)

| Trick | Applies to |
|---|---|
| Sculpt high, bake low | The stone material (3), the colosseum bay (5), the plane (6) |
| Parallax depth | The stone material's height map, for mortar joints and cracks (3). Costs a few texture taps per pixel, on the stone only |
| Vertex-colour grime | Recommendation 1(a) is exactly this (sky visibility per vertex) |
| Import LODs | Blender modules. The kit's own LOD (`ruin_lod.gd`) and the colosseum's far shell stay |

Estimated savings:
- A baked bay should come in under the kit's chipped-block bay in
  triangles. Not measured; measure it in that round.
- A triplanar stone material adds about 3 texture samples x 3 axes per
  stone pixel. That's well under a millisecond at 1440p on the Mac,
  unmeasured.
- Recommendation 1(a) costs nothing per frame.

## Suggested order

A look round with 1 and 2 (code only, A/B stills against today), then a
Blender round for 3 and 4, judged in play. Then decide on 5 and 6 with
those in hand.

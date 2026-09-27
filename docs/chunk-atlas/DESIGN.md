# Chunk atlas

Status: exploration on `feature/chunk-atlas`, 2026-09-27. First vertical slice
landed; nothing has been judged on screen yet.

## Vision

A Genesis chunk is one 28 m diorama. The atlas lets you paint a chunk, then
step to the square beside it and paint the next, and the chunks join into
one pannable world. That scale is what a single chunk cannot give: mountain
ranges that run across several chunks, oceans, giant tea lakes and dense
forests. The Electron ZenScape did this (one journal entry per chunk), and it
gave that game much of its depth.

This differs from the parked `feature/stitched-terrain`. That branch
generated 25 chunks from seeds as fixed meshes, and none of Genesis's
brushes, emergence, water or saves worked on them. Here every chunk is a real
Genesis document, made with the brushes.

## What the Electron source does

Findings from `~/Documents/Projects/zenscape` (see
[[zenscape-source-oracle]]):

- **`CHUNK_SIZE`.** 28 m, 44 cells, 45 border samples a side (`genome.js:33`,
  `terrain.js:361`). The Godot reference terrain matches this exactly: 45 rim
  vertices a side, spaced 28/44 (`tests/test_chunk_atlas.gd` asserts it).
- **Slots.** Chunks sit on integer slots (u, v), centred at x = 28u,
  z = -28v, so +v is north (`grid.js:67`).
- **New chunks.** A new chunk can go on any *frontier* square: a free square
  orthogonally next to a chunk. Squares touched only diagonally are not
  offered (`slots.js:84`). The first chunk is at (0, 0).
- **Edge strips are law.**
  - Each chunk regenerates from its own seed. Only its four edge strips are
    frozen: 45 heights at a 1e-4 quantum, plus a water level and stream
    markers (`strips.js:261`).
  - A newer chunk is pulled onto its neighbours' strips by a correction band
    that is `BAND_FRAC` 0.18 of the chunk wide (about 5 m).
  - The band blends as a Coons patch, so corners are exact
    (`strips.js:482`).
- **Colour and cover.** These blend over `BLEND_FRAC` 0.3 (about 8.4 m); the
  neighbour's weight rises to ½ at the border (`dress.js:116`).
- **Water crosses seams.**
  - A neighbour's wet border seeds a flood at its level, and every border caps
    how high a chunk's own water may stand
    (`inheritedWater`/`promisedWater`, `strips.js:813`).
  - A stream that leaves a chunk becomes an inlet in the next one.
- **Rendering.**
  - The live chunk stays at the scene origin and the others are drawn at
    offsets. Visiting another chunk slides the orbit target rather than
    moving the scene (`visit.js`).
  - Only a 3x3 ring is built (`NEAR_RINGS` 1), for GPU cost.
  - A fog bank covers frontier and unbuilt squares.

## Model in this slice: one live chunk, frozen neighbours

All of Genesis assumes one chunk at ±14. Emergence, water, the fog and air
volume, navigation, several shaders and the skirt hard-code it (the
research list is in the branch history). The atlas keeps that assumption by
following Electron's live-at-origin model:

- **The live chunk** is the editor's own `NativeTerrainData` at the origin,
  unchanged. Every brush, emergence, water, sound and save keeps working.
- **Frozen chunks** are stored documents (`data.to_document()`), drawn by
  `scripts/chunk_atlas_view.gd` at `(u-u₀)·28, -(v-v₀)·28` from the live slot.
  Each view has:
  - terrain from its own `NativeTerrainData.build_mesh()`;
  - the authored earth block, lifted to its rim, with walls only on outer
    borders;
  - a `GardenView` for its trees, props and ponds.
- **Stepping.** A plain arrow key (macOS keeps Ctrl+arrows for Spaces), relative to the camera, stores the
  live chunk and moves the live slot. The scene shifts under the camera, which
  then glides onto the new chunk (`GLIDE_S` 1.15).
  - An empty square gets a fresh plain.
  - A stored square is loaded back into the editor and becomes editable
    again.
- **The border pin** (`ChunkAtlas.Pin`):
  - The live chunk's strips come from its stored neighbours' facing borders.
  - `NativeChunkEditor.refresh()` applies the pin before every refresh, light
    or full, so no brush, weathering, pour or formation can open a seam.
  - The pin blends border offsets inward over the band as a Coons patch, then
    sets border vertices exactly to the strip. Applying it twice changes
    nothing.
  - A chunk's edges are snapped to the 1e-4 quantum when it is stored, so
    both sides of a seam hold the same number.
- **Skirt walls.** The earth-block walls on borders that face a chunk are cut
  away (`AtlasView.cut_sides`), on the live skirt too. Neighbours meet as one
  ground.
- **Plains.** Every plain in an atlas uses one seed, sampled in world metres
  (`Genesis.shape(data, seed, origin)`), so fresh plains already roll into
  each other before the pin.

### Frozen chunks are frozen (round 2)

The first playtest found that regenerating one chunk regrew them all. Growth
(`zs_growth`, `zs_water_growth`), stroke waves (`zs_growth_wave_*`) and the
emergence clock (`zs_emergence_time`) are shader globals. On top of that,
every frozen view drew with the live editor's own terrain material. So the
regrow's fold-down and grow-back, and every re-emergence, played on every
chunk at once.

- **Own materials.** `AtlasView.freeze()` copies every ShaderMaterial a
  frozen chunk draws with (terrain, skirt, plants, props, water; multimesh
  surfaces get a copied mesh) and sets `zs_atlas_frozen`.
- **Frozen reads.** In `reference_globals.gdshaderinc`, `zs_growth_now()`,
  `zs_water_growth_now()`, `zs_emergence_now()`, `zs_growth_wave_at()` and
  `zs_birth_growth()` read a frozen material as fully grown and settled. Every
  object, terrain and water shader reads growth through them; the air and
  fog volumes still read the globals.
- **Seam hold.** Shared borders of the live terrain keep their pinned height
  while it folds and grows (`atlas_hold`, 3.2 m, the source's `SEAM_HOLD`),
  so a seam never gapes mid-regenerate.
- **One ground pattern.** `NativeTerrainData.world_offset` samples the
  palette's grass, rock and shimmer noise in world metres, so the pattern runs
  on across seams instead of every chunk repeating the origin's.

### Neighbours shape the live chunk (round 2)

In atlas mode, Regenerate and New plain touch only the live chunk. The
result continues what is around it:

- **One sky.** No new mood, look, hour or framing is applied
  (`cozy_regrowth.regrow` checks `scene.atlas`). Sky, time and weather carry
  straight on.
- **Country votes** (`scripts/chunk_atlas_genes.gd`, after grid.js
  `countryOf`).
  - Each stored neighbour's terrain recipe votes: orthogonal neighbours count
    1, diagonal ones 0.5, and a plain votes gentle meadow.
  - One vote is drawn as the parent. The new chunk takes its composition, and
    its habitat 80 % of the time.
  - Relief and breadth are the weighted mean, ±0.12.
  - 18 % of regenerations are a surprise that ignores the neighbours.
  - Four candidates are scored by `world_beauty` and the best is kept, as
    `Generator.sample` does. It runs on a worker.
- **Carry-in** (`ChunkAtlas.carry_in`). Runs once, when a chunk is grown,
  regenerated or re-planed.
  - Each stored neighbour's border relief is carried inward. The band widens
    with the strip's relief: 5.04 m + 2.5 × relief + 0.5 × offset, capped at
    16.8 m, wobbled ±30 % by world noise.
  - So a ridge meeting a seam runs on as a spur instead of a 5 m ramp.
    Headless: a 3.4 m ridge carries 14.9 m and still stands 2.5 m high 7 m
    in.
  - Cover (`grass`, `blades`, `meadow`) and paint (`tint`, premultiplied by
    its weight) then blend toward the neighbour's border cells over
    `BLEND_FRAC` (8.4 m). They reach the neighbour's value at the seam, and
    corners share the weight.
  - After that the ordinary 5 m pin keeps the seam exact while you paint.
    Cover is not re-blended, so painting near a seam sticks.
- **New plains** form on the world field at the chunk's origin, so a fresh
  plain already meets plain neighbours before the pin.

### Save format

`user://cozy-worlds/atlas.json`:

```json
{"version": 1, "seed": 4242, "live": [u, v],
 "slots": [{"u": 0, "v": 0, "document": { ...NativeTerrainData document v10... }}]}
```

- **`places.json` is untouched.** With `--atlas`, the regrowth controller's own
  save goes to `user://cozy-worlds/atlas-live/places.json`, so an atlas
  session never overwrites the player's places.
- **When it saves.** The atlas is written on every step, on Save and on quit.

### In this slice

- `scripts/chunk_atlas.gd`: slots with revisions, frontier, strips, the pin
  (per-side bands and wobble), carry-in, cover blend, and save/load.
- `scripts/chunk_atlas_view.gd`: the frozen chunk, its frozen materials and
  the skirt cut.
- `scripts/chunk_atlas_controller.gd`: `--atlas` wiring, stepping, the glide,
  the 3x3 ring, the pad, and the regrow hooks (`sample_world`,
  `carry_in_live`).
- `scripts/chunk_atlas_genes.gd`: neighbour votes for Regenerate.
- Hooks elsewhere:
  - the pin and open sides in `native_chunk_editor.gd`;
  - `world_offset` in `native_terrain_data.gd`;
  - the world origin in `genesis_canvas.gd`;
  - the atlas branch in `cozy_regrowth.regrow`;
  - the frozen reads in the shaders.
- Checks, all headless:
  - `tests/test_chunk_atlas.gd`: seams after strokes, band locality,
    idempotence, corners, frontier, save/load, carry-in reach, cover at the
    seam, and mountain votes giving mountains.
  - `tools/probe_chunk_atlas.gd`: grow east, stroke across the seam, walk
    back, relaunch, arrow key and pad.
  - `tools/probe_chunk_atlas_tour.gd`: five chunks, a ridge carried over a
    seam, regenerate, new plain, a walk round the ring, save and relaunch.
    After each step it checks that neighbours are untouched, seams stay shut,
    no material is shared, the frozen flag holds, the sky doesn't jump, and
    the pad is ready.
  - `tools/check_shaders.gd`: parses every shader, since the dummy renderer
    still reports shader errors.

Launch: `./run-cozy-flow.command --atlas`, or with `-- --atlas`; both work.
Arrow keys or the WORLD pad (bottom right) step between chunks. Regenerate
and New plain in the world menu reshape only the live chunk.

### Out of this slice (known gaps)

- **Ground colour across a seam.** Cover, paint and the palette pattern now
  run on. The terrain's own colour can still step where one chunk has a
  generated biome (its snowline, rock slope and authored colours) and the
  other is a plain. Blending face colour needs the neighbour's built colours
  at the border, not just its masks.
- **Palette per chunk.** The atlas keeps one sky and one palette, as the
  shaders' `zs_palette_*` ratios are global. A chunk cannot yet be autumn
  beside a green one; per-chunk ground paint (tint) is the available lever.
- **Plants at the seam.** Forest density does not thin toward a neighbour's
  (foliage.js 808-829). A generated chunk's trees were placed before carry-in
  reshaped its band. The garden lifts them onto the new ground, but a tree may
  now stand on a slope it would not have been planted on. This is unverified
  on screen.
- **Water.** Generated rivers and ponds are planned for the chunk alone. A
  river that meets a pinned border ends against it, and no pond level is
  inherited across a seam (see the tea lake section).
- **The air stays on the live chunk.** The fog volume, air march box, display
  fog, precipitation and wind trails are sized ±14 around the origin, so
  neighbours sit outside the mist. Electron draws a fog bank over the
  frontier instead. The port candidate is the `stitched_air.gd` work on
  `feature/stitched-terrain` (`ground_half`/`air_half` uniforms).
- **Frozen chunks are still life.** They have no emergence, birds, fish,
  sound, wind sway reach or water motion; their GardenView does not process.
- **Only orthogonal neighbours constrain.** A diagonal-only neighbour can meet
  at a corner point with a small step.
- **Stepping is synchronous.** Headless:
  - Growing a chunk takes about 300 ms and stepping onto a stored one about
    170-200 ms, of which drawing the ring is 50-75 ms.
  - A regenerate runs about 9 s including its fold and grow animation.
  - Worker-built views and a staggered refresh would hide the stepping
    hitch.

## Open questions

1. **Water crossing seams.** Pours are planned inside ±14. The water brush
   scoops a hollow when water would run off the edge. See the tea lake
   section below.
2. **The fog and air volume.** Should it grow to the ring, follow the camera,
   or should the frontier get Electron's fog bank? The display fog also
   paints ground-hugging alpha as ground
   ([[zenscape-balanced-fog-hides-translucent]]).
3. **Life and navigation per chunk.**
   - Should creatures wander across seams? That needs `creature_navigation`'s
     `half`/`origin` parameters from the stitched branch, and a nav bake over
     the ring.
   - Should emergence run only on the live chunk, or keep growing frozen
     ones slowly?
4. **Performance with a 3x3 ring.**
   - Eight GardenViews each instantiate `geometry.scn` once. They could share
     one catalog.
   - Frozen instances could merge into one MultiMesh per part.
   - Electron measured about 0.3 ms per frozen chunk. This needs a rendered
     measurement on the 4070 Super before the ring grows.
5. **Macro features spanning chunks.** A range across three chunks cannot be
   painted in one stroke while only one chunk is live. Options:
   - a macro field (like `stitched_macro.gd`) that biases every chunk;
   - brushes that write into frozen neighbours' documents inside the band;
   - making the ring live, which means the ±14 refactor.
6. **Picking squares.** Keys are enough to explore. The Electron flow clicks
   a frontier square, outlined, and the camera glides there.

## Tea lake: the path to a giant one

The Electron "tea lake" is tannin peat water (ADR 0016 in
`~/Documents/Projects/zenscape`): tea-coloured over the shelves, near-black in
the middle, matte and still, on a big lake that crosses chunk seams. Two
things made that possible. The seam machinery carries a water level in every
strip (`w`), with `inheritedWater`/`promisedWater` at the borders. A shared
body also gets one mist field (`docs/lake-spectacle.md`).

In Godot the tannin ramp already exists (`native_recipe_water.gd`
`water_ramp`), but only generated worlds feed it. The Genesis water brush uses
the Fidelity water. The path:

- **(a) Water level in the edge strips.**
  - Add `w[45]` beside `h[45]` per side: the standing level at each border
    sample, or none. It is derived from the stored document's ponds and flood
    when the chunk is stored.
  - Store it in the atlas slot alongside the document, so strips stay cheap to
    read.
- **(b) Inherit or flood at the seam.**
  - When a pour on the live chunk reaches a border whose strip is wet, the
    water brush's planner (`water_brush.gd`, which already finds basins and
    spill levels) seeds its flood at the neighbour's level instead of
    scooping a hollow.
  - A dry neighbour border caps the level, which is `promisedWater`. It stops
    the live lake standing higher than the land it would spill across.
  - A pour that rises past a wet border's level adds nothing; the lake is
    already full.
  - Streams leaving a border become inlets in the next chunk. That is the
    same marker idea, and it is the later half.
- **(c) Draw frozen neighbours' water.** Frozen views already build a
  `GardenView` from the document, and it draws that document's ponds and
  streams. What is missing is the shared-surface rules:
  - one level across the seam, so both halves of the plane meet;
  - shore foam that stops at open borders;
  - reflections, which today are capped at the live chunk's two largest pond
    levels.
- **(d) A water look.**
  - Give the brush or mood a water look (Fidelity clear, tannin, silt, bloom)
    that selects the `water_ramp` family for plain ponds too.
  - The look should be a per-body property that travels with the strip's
    water, so a tea lake stays tea on every chunk it touches.
  - One mist field per shared body would follow once the air leaves ±14.

**Pieces this slice already makes easier:**

- Strips exist, are quantized and are read from stored documents, so adding
  `w` is a field, not a new mechanism.
- The border pin guarantees the lake bed's banks meet at the seam. A shared
  level then lands on a continuous shore.
- Frozen chunks already draw their saved ponds (c), so a lake that ends at
  the border shows on both sides once the levels agree.
- The live-at-origin model keeps the water brush's ±14 planner unchanged. Only
  its border rule changes.

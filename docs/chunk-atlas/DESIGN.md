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
- **Stepping.** Ctrl or Cmd plus an arrow, relative to the camera, stores the
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

- `scripts/chunk_atlas.gd`: slots, frontier, strips, the pin, and save/load.
- `scripts/chunk_atlas_view.gd`: the frozen chunk and the skirt cut.
- `scripts/chunk_atlas_controller.gd`: `--atlas` wiring, stepping, the glide
  and the 3x3 ring.
- The pin and open-sides hooks in `native_chunk_editor.gd`, and the world
  origin in `genesis_canvas.gd`.
- `tests/test_chunk_atlas.gd`, a data-only test: seams after strokes, band
  locality, idempotence, corner agreement, frontier, and save/load.
- `tools/probe_chunk_atlas.gd`, a headless launch check: grow east, stroke
  across the seam, walk back, relaunch.

Launch: `./run-cozy-flow.command -- --atlas` (or `godot --path .
res://studies/cozy_worlds.tscn -- --atlas`). Ctrl or Cmd plus the arrows steps
chunks. The camera's existing pan (middle drag) and zoom (up to 150 m) already
cover a 3x3 ring.

### Out of this slice (known gaps)

- **Look across seams.**
  - Face colour and cover do not blend yet. The palette's grass and rock
    noise is sampled in chunk-local coordinates, so tint may step at a seam.
    The fix is Electron's `BLEND_FRAC` mix, or world-space palette
    coordinates.
  - Frozen chunks use the live terrain material. Its shader samples
    `(xz+14)/28` for geology, so neighbours repeat the live chunk's pattern.
- **The air stays on the live chunk.** The fog volume, air march box, display
  fog, precipitation and wind trails are sized ±14 around the origin, so
  neighbours sit outside the mist. Electron draws a fog bank over the
  frontier instead. The `stitched_air.gd` work on `feature/stitched-terrain`
  (`ground_half`/`air_half` uniforms) is the port candidate.
- **Frozen chunks are still life.** They have no emergence, birds, fish,
  sound or water motion. Their GardenView does not process.
- **Only generated plains.** Recipe worlds (`--seed`, regrow) have no
  world-space seed. Regrowing inside an atlas replaces the live chunk with an
  unpinned recipe until the next refresh pins its border.
- **Only orthogonal neighbours constrain.** A diagonal-only neighbour can meet
  at a corner point with a small step.
- **Stepping is synchronous.** Headless: a grow is about 270 ms and a step
  onto a stored chunk about 140 ms, of which drawing the ring is about 47 ms.
  Worker-built views and a staggered refresh would hide it.

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

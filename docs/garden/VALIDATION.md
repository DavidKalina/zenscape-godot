# Native garden implementation and validation

The current editor runs **inside `studies/fidelity.tscn`**. `run-garden.command`
opens that original scene with Build controls enabled. Inspect/Build retains the
same camera, environment, imported chunk and shaders. Escape returns to Inspect.
`run-sandbox.command` remains the older, separate prototype.

## Current authoring loop

- Start flat clears the imported terrain's own welded vertices and hides its
  captured decorations. The original faceted earth sides follow the new rim.
- Raise, lower, smooth and flatten operate on the imported irregular topology.
  Height range is −1.5 to 24, across the original 28-unit chunk.
- Grass paints an independent density layer, with a full-chunk coverage action.
  Meadow adds mixed grass and flowers; individual flowers remain placeable.
  Mountain stamps expose base radius (1–12) and peak height (0.5–24); blank
  terrain blends to stone on high/steep faces and pale summits at high altitude.
  Editing the imported scene preserves its source vertex colors.
- Meadow painting uses deterministic cells across that chunk. Trees, grass and
  flowers use source meshes and materials; the rock is a small procedural mesh
  using the native surface shader. Plant positions follow the edited ground.
- Ponds flood connected native terrain triangles and clip their shoreline to
  the actual mesh. The shared flood algorithm refuses open basins and replacing
  a connected pond avoids duplicate water. Rendering uses the native lake shader,
  depth attributes and directional wind-fetch data.
- Build includes a Sky & weather foldout with golden hour, misty dawn, night,
  weather presets, time, clouds and mist, all driving the original scene.
  Original weather/time/atmosphere controls remain available. Weather and fog
  surface maps update after edits. Rain's ceiling follows tall hills; the display
  fog floor follows deep hollows. Terrain formation temporarily suspends picking.
- Undo/redo includes terrain, grass, meadow, objects, ponds and blank/source state.
  Undoing all edits restores the exact imported terrain/skirt mesh resources and
  the original surface-map bytes.
- Save/Open use `user://native-garden.json`. The native version-4 document records
  the source-topology fingerprint, complete authored content, camera and native
  weather/atmosphere state. Scalar simulation doubles use their exact IEEE bytes
  because JSON decimal decoding can round a final bit. Invalid documents are
  validated before replacement; saves use a sibling temporary file and rename.
  Version-3 documents migrate with an empty independent grass layer.
- `run-garden.command` reopens that save automatically. `--garden-file=/path/file.json`
  selects a separate save for a playtest. Direct fidelity launches stay on the
  reference scene until the user chooses Open.

## Automated evidence (2026-09-07)

The 52-test graphics suite passed after the tool additions. The targeted build
tool test passed again after review fixes for time-transition cancellation and
authored-content framing. The expanded control panel was inspected in a native
rendered screenshot.

`tests/test_native_build_tools.gd` checks one-dab grass visibility without flowers,
full coverage and undo, v3 migration and v4 roundtrip, malformed density rejection,
actual mouse-event mountain placement, bounds, precipitation ceiling, alpine
colors, camera framing, and native sky control/state synchronization.

`tests/test_native_chunk_editor.gd`, run with the Metal/Forward+ renderer, verifies:

1. Build retains original mesh, camera transform, environment and shader.
2. Native sculpting retains topology, colors, UVs and base-color attributes;
   shader growth heights follow edited geometry, and undo restores the source.
3. Event-time mouse rays place content without requiring a cached hover. Right
   drag remains available for orbiting, and releasing closes the sculpt stroke.
4. Starting flat, creating a hill/hollow, painting a meadow, placing all three
   object types, filling a connected pond and selecting native rain all work.
5. The rendered tree follows terrain edits. Pond vertices have a constant level
   and the shared weather map contains the authored water surface.
6. Terrain-formation picking guards, the maximum-height rain ceiling, deep-hollow
   fog integration and restored settings controls cover the review findings.
7. A save is opened in a fresh fidelity scene. World values, camera/environment
   state, shoreline vertices and map bytes match; saving again produces identical
   file bytes. Malformed terrain input leaves the open world unchanged.

The complete 51-script graphics suite ran: 50 passed initially; it exposed a
firefly visibility regression introduced by the blank-canvas path. After fixing
that regression, `test_fireflies.gd`, `test_fidelity.gd` and the full native garden
integration passed again. Logs/results are retained alongside this document.

The clean Inspect and newly entered Build PNGs are byte-identical, SHA-256
`2ae238eaa1948f9e4dbac5d7bb62303c3f25046e497add68ba21a6e396174c10`.
The paused scene and hidden brush/UI make this a direct renderer-preservation
check before editing, not a comparison of two approximately matched scenes.

The authored rain scene and fresh-scene reopen captures are also byte-identical,
SHA-256 `861ea2392c1862b46c0cd37b7f2711db7ce59763b0a30027d96d399882ec54a3`.

Representative native captures: `native-original.png`, `native-build.png`,
`native-sculpt.png`, `native-flat.png`, `native-flat-sculpt.png`,
`native-garden-rain.png`, and `native-garden-reopened.png`.

The separate Standards and Spec reviews found growth/picking disagreement,
precipitation ceiling and fog-floor bounds, stale restored UI controls, and
shared water-algorithm duplication. These were addressed and the relevant
integration regressions pass. Existing ObjectDB shutdown warnings also occur in
fidelity-only tests; the final native checks contain no script or renderer errors.

## Completion still requires hands-on verification

**Keep the goal active.** The native integration test hides controls for its
camera-ray checks and directly calls brush methods for sustained strokes. It is
strong evidence for the implementation, not a substitute for the entire visible
mouse/keyboard workflow. A manual native app launch succeeded, but computer use
reported that the Mac is locked. The user has been asked to unlock it.

Next: use the visible Build controls to author the whole loop, check layout and
brush responsiveness, save, close, reopen through `run-garden.command`, and save
again. Inspect the resulting native scene and verify that saved content and
framing survived. The dedicated manual app was closed after the locked-screen result; relaunch it
with the current code. It uses `/tmp/native-manual.json` so it
cannot overwrite the user's main garden.

The older `manual-garden.json` and `garden-*.png` files document a completed mouse
playtest of the separate prototype. They do **not** prove the clarified native
Build experience. Object selection/movement, rivers, imported custom assets and
Steam Workshop remain future work outside this requested garden loop.

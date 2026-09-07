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

## Demo-world authoring goal (in progress)

Goal: create the demo world from a blank chunk using the editor, including its
Bigfoot tree, mountain, waterfall and arches. The goal is not complete.

Implemented landmarks: Arch and Bigfoot tree palette entries reuse the source
geometry and native materials. Object size and rotation controls apply to these
and ordinary placed objects. Records persist through Save/Open and participate
in erase, undo and terrain grounding. R frames nested authored geometry.
Landmark bases anchor at the sampled center; level the foundation for a broad
arch on uneven terrain. The first authored Bigfoot tree anchors the existing encounter, including its
rotation and scale. B previews Bigfoot there; removing it restores the original
encounter anchor (hidden on a blank chunk).

Validation: 53 graphics tests pass. `test_native_landmarks.gd` also passed after
adding rotation-control, projected-framing, visible arch-base, and fresh-scene
save/reopen assertions. A rendered blank chunk with an authored mountain, arch,
and Bigfoot tree was inspected at `/tmp/native-landmarks.png`.

Waterfall now accepts two clicks: the lip and a lower landing. Its saved endpoint
record rebuilds the original ring shader and animated spray; a receiving pond
supplies the landing water height. Obstructed or submerged falls retain their
records but stop rendering until terrain/water edits or undo clear the path.
The original encounter reanchors to the first authored Bigfoot tree.

Remaining before completion: build and reopen a complete world through the
visible editor, inspect waterfall motion and pond contact in context, and correct
any usability or visual issues that this reveals. Existing imported demo water is
not evidence that blank-chunk waterfall authoring works.

Waterfall regression coverage (`test_native_falls.gd`): two camera-ray clicks,
original shader, pond landing, undo/redo, uphill and obstructed rejection,
obstruction removal, malformed endpoints, fresh-scene save/reopen, camera-aligned
spray under both display and native fog, and pixel changes while only flow time
advances. `/tmp/native-falls.png` is the inspected authored-waterfall render.

After these changes, all 54 graphics regression tests passed. The native-fog
waterfall run also passed separately. Full interactive demo-world proof remains
outstanding; this test result does not close the authoring goal.

## Visual correction after user review (in progress)

The user rejected the cone mountain, airborne waterfall arc, and full-chunk
blade coverage. The earlier interactive demo does not satisfy the goal.

Mountains now adapt the original `world.js` noise/spine/scarp approach into a
bounded ridge stamp with variation and rotation. Source palette bands supply
rock faces and snow. This adapts the core shape recipe; it does not port the
entire word/genome generator. Grass now paints ground color, using the original
noise-driven green patches. Blades is a separate local density brush. Meadow
retains its intentional mixed flowers and vegetation. Version 5 saves separate
ground and blades; version 4 migrates former grass vegetation into blades to
preserve saved scenes. The Blades-tool removal button clears those patches only.

The 55-test graphics suite passed, followed by targeted checks for painting on
the imported chunk, exact undo, and the refined green-patch render. The inspected
render is `/tmp/native-landmarks.png`. Waterfalls still use the rejected arcing
route and must be corrected to follow geology. Arch foundations on uneven ground
also need scrutiny in the next composition. Goal remains incomplete.

## Geological waterfall routing

The arcing route has now been replaced by a bounded downhill trace adapted from
`waterfall.js`: slope, momentum, and pull toward the chosen landing. Rings sample
the terrain and orient their cross-sections along the course. Width is limited
by nearby rock support. Water-level clamping applies only inside the receiving
pond, so a dry endpoint cannot create an imaginary lake across a depression.
Rendered segment interiors are sampled at 0.1-unit intervals; routes that cut
through rock or depart more than 0.25 units from their supporting surface are
rejected rather than bridged. The 32-ring shader capacity remains a limit, so
some complex routes require a different source/landing or terrain edits.

The 55-test graphics suite passed before review corrections. Targeted waterfall
checks then passed after adding dry-depression, first-width-sample, and segment
interior regressions, alongside visible motion and fresh-scene reopening.
The inspected waterfall render is `/tmp/native-falls.png`.

Remaining goal evidence: a new complete composition in the visible editor using
these corrected mountains, green ground and geology-following water; level
foundations for arches; save/reopen and visual inspection. The previous rejected
cone-and-arc demo is not completion evidence.

## Faceted turf correction

The manually authored `demo-ridge-world.json` demonstrates the corrected ridge,
geological waterfall, pond, two arches, tree grove and individual flowers with
zero blade coverage. It was created through the visible editor and reopened;
saving again preserved SHA-256
`7c4249ddb936a4dd23d65b547fac5259f5781bb24b1b3e17f7574b9b105f4726`.
A durable copy is in this directory. `demo-ridge-world.png` records the earlier
flat/blurry turf; `demo-turf-after.png` renders the same document after correction.

The user identified missing depth and blurry colors in the upper grassy layer.
The blank reset flattened the original raised rim, and editor palette samples
at individual vertices blended within each triangle. Ground now uses the source
terrain.js centroid palette and per-face shimmer. Blank chunks have a 1.2-unit
cut turf band beneath the editable surface, with the original earth skirt
compressed beneath it. The band follows painted coverage and uses the native
soil lighting shader. It does not change saved heights, ponds or object anchors;
it also does not add blade vegetation or introduce ground undulations.

Turf joins interpolate the actual rebuilt soil boundary, including its coarse
breakpoints and the finer terrain border points. The untouched imported world
retains its original meshes. Undo restores them exactly.

`test_native_turf.gd` first reproduced both missing depth and interpolated face
colors, then passed after correction. The 56-test graphics suite passed. After
review identified mismatched sampling at sculpted edges, a targeted regression
also passed with a narrow raised edge and lowered corner, checking both sides of
the shared boundary. The final native render and visible reopened editor were
inspected. This is a terrain-focused visual iteration; Bigfoot was set aside at
the user's request, and overall visual acceptance remains with the user.

## Fidelity rebuild benchmark: real foundation

The artificial 1.2-unit turf band above is superseded and removed. It compressed
the soil and did not reproduce fidelity's actual structure. Measurements of the
original scene show a 0.6 rim, near-edge median ground height 2.1361, and soil
bottom -4.7734. Recreating the whole fidelity scene from blank remains the goal.

The Ground tool now exposes elevation and relief and a Form ground foundation
button. It evaluates the original meadow, stamps and rolling-relief equations,
pins the sealed border to 0.6, and writes real editable vertex heights. The
original soil mesh remains exact when the rim is unchanged. Grass remains a
separate paint operation and adds no blade vegetation. This is the foundation
component, not a substitute for rebuilding the complete reference terrain.

`test_native_turf.gd` checks button dispatch, raised near-edge ground, original
soil bounds, absence of an added band or imported objects, facet colors, exact
JSON height roundtrip, adjustable relief/elevation and undo. It passes. Extracting
the shared foundation equations preserves the independent 10,000 Electron
height probes (maximum error 3.4e-12) and production bird-flight checks.
`foundation-proof.json` and `foundation-proof.png` were created by a graphics
harness invoking the editor actions, not by a manual UI reconstruction.

Remaining: source mountain/composition controls, full source asset/placement
coverage, complete water authoring, and an actual editor-built full world saved,
reopened and compared with fidelity at identical camera/lighting. Foundation
proof alone does not satisfy that benchmark.

The first foundation render also exposed erroneous rock coloring on the cut rim.
Face-slope classification now excludes that artificial boundary slope, matching
the source distinction between continuous ground and the lowered sealed border.
The focused test additionally verifies green rim colors and passes; the final
foundation render was inspected after this correction.

## Source range controls

Range exposes height, width, rotation and noise variation plus Form mountain
landscape. It evaluates the existing source continuous terrain plan (including
chute, receiving basin, stream beds and arch clearing) into editable heights;
it does not copy the imported terrain height buffer or reveal source scenery.
Default settings reconstruct the imported vertices within 9.5367432e-7 units.
This is the exported seed-7 plan made adjustable, not the entire word/genome
planning system.

`test_native_range.gd` passes: editor-button dispatch from blank, per-vertex
comparison against the independently imported mesh, hidden source content,
undo/redo, JSON roundtrip, and independent effects of all four controls.
`range-proof.json` is the saved generated scene. `range-generated.png` and
`range-control.png` use the same original camera and phase-0.4 lighting. They
were inspected: geometric silhouettes align, while material colors/snow bands
still differ and authored assets/water are incomplete. These are harness-driven
editor actions, not yet the final manual full-world reconstruction proof.

## Source palette reconstruction

`NativeTerrainPalette` evaluates the source noise seed, hue, cover offsets,
rock lift, snowline and rock-slope thresholds. Colors use Three.js-compatible HSL
operations on linear RGB and additive face shimmer. Grass is no longer based on
seed 7 with unshifted palette constants. A second discrepancy came from computing
centroids with float32 Vector3 arithmetic; scalar double-precision centroids now
match the source's JavaScript arithmetic before hashing.

`test_native_palette.gd` compares all generated grass face colors against the
independently imported CUSTOM0 base-color channel. Maximum channel error is
5.960464e-8. This proves the grass palette, not final terrain/material parity:
rock/snow classification still uses edited mesh slopes instead of the source
continuous sampler, and shoreline coloring remains outstanding with water.

The 58-test graphics run passed 57 tests; the remaining build-tools assertion
required summit red brightness above 0.25, which the source's darker rock colors
need not meet. It now checks warm rock or bright snow rather than green ground;
the targeted build-tools rerun passes with no engine errors. Review found no
concrete defect in the bounded foundation/range/palette changes, while retaining
the documented limits on full scene parity and varied water-course usability.

## Continuous slope coloring and recipe persistence

Version 6 saves an optional validated terrain_recipe alongside editable heights.
Foundation/range actions retain the source equation parameters and reconstruct
continuous slope samples at face centroids. Sculpted displacement gradients are
added to those samples, so later edits affect coloring without replacing the
source slope with triangle steepness. Legacy versions 3–5 retain their stored
heights and use mesh-based coloring without inventing a recipe.

Expanded `test_native_palette.gd`: all 328 alpine faces now match the imported
reference COLOR channel exactly; grass retains its 5.96e-8 channel tolerance.
Fresh data reopening preserves colors, malformed recipe rejection is atomic,
and lowering the summit changes colors with exact undo. Range, foundation and
legacy build-tool checks pass. This establishes alpine and base-grass coloring;
shoreline colors and complete asset/water authoring remain unfinished.

Review caught JSON decoder drift in non-default recipe doubles. Recipe scalar
parameters now use validated 16-character IEEE-754 encodings, as scene-state
scalars already do. The expanded palette test reopens a 0.7 height/width, 35-degree,
variation-7 range and confirms exact whole-document and color equality. It passes,
along with atomic rejection and sculpt/undo checks.

## Expanded source asset catalog

The Assets picker adds broadleaf trees, shrubs, reeds, bank grass, button/spike/
umbel flowers, logs, stumps, snags and mushrooms. Compound assets retain their
source mesh parts and materials, with the first source instance's tint as the
initial appearance. They use the existing size/rotation controls and placement,
erase, undo and save paths. This does not yet expose per-instance tint or
nonuniform transform variation needed for an exact reconstruction.

`test_native_asset_catalog.gd` passes all eleven kinds through picker selection
and actual camera-ray placement, checks source geometry/material/tint ownership,
and verifies save/reopen and erase/undo. `catalog-proof.json/png` were created
through harness-driven editor inputs and inspected. Their small-scale vegetation
matches the source mesh proportions. The shared garden scene and existing native
build tools also pass targeted regressions.

Remaining source assets include the original boulder variants and full placement
variation; water and final complete manual reconstruction remain outstanding.

## Source boulder variants

Assets now includes the four original mesh-4 through mesh-7 boulders. The catalog
supports static meshes as well as compound instanced vegetation. Boulder assets
retain captured basis proportions/orientation and the native material. Their
placement pivot is computed from transformed mesh vertices, rather than rotated
bounding-box corners, so the visible base meets the ground.

The expanded catalog test passes all fifteen kinds, including actual lowest-
vertex grounding for all boulders under user rotation/scale, camera-ray placement,
source mesh/material identity, saving/reopening, erase and undo. The updated
catalog-proof render was inspected with all four boulders visible.

Inventory for remaining reconstruction work: source scenery has 103 conifers,
4 broadleaves, 700 grass instances, 51 shrubs, 186 reeds, 53 bank tufts, 2015
flowers across four forms, 17 logs, 3 stumps, 8 snags and 34 mushrooms. Existing
uniform size/yaw and one default tint do not yet express every captured instance.
Full placement transforms/color variation and the object-count limit need work
before claiming full source authorability. Water remains unfinished.

## Exact placement poses

Reinspection corrected the earlier capacity concern: GardenData.MAX_OBJECTS is
already 20,000, enough for the reference inventory. No capacity change was needed.

Trees, flowers, rocks and catalog assets now expose independent width/height/
depth, forward/sideways tilt, and vertical offset. Non-default controls store an
exact float32 basis and float64 offset in a validated pose record. Rendering uses
that basis for every compound part. Legacy yaw/uniform-scale records remain
unchanged; arches and Bigfoot tree retain their existing controls.

`test_native_object_pose.gd` passes actual camera-ray placement, independent local
dimensions and both tilts, compound-part basis equality, vertical offset, exact
rendered-transform reopening, singular-basis atomic rejection and erase/undo.
The fifteen-kind catalog test also passes. These controls address transform
variation; individual color authoring, water and complete reconstruction remain.

## Per-placement color

Custom color is available for ordinary and catalog assets. Compound assets apply
it to foliage, flower heads or mushroom caps, retaining trunk/stem tints; single-
part props receive the tint directly. The selected sRGB color is converted to
linear RGB and stored as validated exact float32 bytes. Rendering assigns colors
per instance rather than sharing one tint across a whole batch.

`test_native_object_tint.gd` passes real picker-signal/camera-ray placement of two
differently colored trees, independent crown colors, retained trunk tints, exact
rendered-color reopening, malformed-color atomic rejection and erase/undo.
Catalog, shared garden scene and custom-pose targeted regressions also pass.
Full water authoring and the final complete editor reconstruction remain open.

## Authored lake footprint

Direct comparison first found 223 wet/dry disagreements between the native
triangle-flood pond and reference mesh-30 on a 0.1-unit sampling grid. Recipe
terrain now uses the source water.js 51-cell field, four-neighbor flood, interior
jitter and contour clipping. It evaluates continuous recipe heights plus sculpted
displacement, rather than copying reference lake geometry. Non-recipe gardens
retain their triangle-flood path.

`test_native_recipe_water.gd` creates the source range and an authored pond at
(5.729594349590496,-3.932306431478948), level 0.38. All 4,002 reference wet samples
match, with zero disagreements over the sampled area. It also verifies exact
surface reopening, drying a raised basin, and exact undo. Existing native falls
regressions pass. `pond-range-proof.json/png` records the harness-authored result;
the render was inspected. Footprint agreement does not yet establish water
material/attributes, shoreline coloring, stream or waterfall parity.

## Lake material and depth attributes

Authored ponds now duplicate mesh-30's source material settings rather than
constructing a default material with guessed swell/algae values. Recipe ponds
bake source-style per-face depth via the flooded field's bilinear sampler and
use depth-band face colors instead of a smooth green vertex gradient.

The expanded recipe-water regression retains footprint/persistence/edit checks,
verifies source material parameters, and compares depth on 282 matching lake-only
faces: maximum error 5.215406e-8. The initial all-face comparison exposed the
reference stream's contribution to the shared depth field (maximum mismatch
0.3619); that remains unimplemented until streams are authored. The lake-only
comparison explicitly excludes faces within 1.6 units of the source stream.
It must not be cited as full water-depth parity. Source-specific color-ramp/foam,
fetch attributes, stream integration and shoreline coloring remain outstanding.
The updated pond render was inspected. Shared garden and native-falls targeted
regressions pass.

## Authored lake fetch field

Recipe ponds now use water.js's eight directional dynamic-programming sweeps,
with zero at the final wet point and a nine-unit cap, followed by bilinear
sampling at each generated vertex. These populate CUSTOM0/CUSTOM1 directly.
Non-recipe ponds retain their existing fetch path.

The expanded recipe-water test compares all eight channels at 996 matching
reference vertices: maximum error 6.67572021e-6. Footprint, lake-only depth,
material, exact surface reopening and terrain-edit/undo checks continue to pass.
The pond proof render was refreshed. Full water parity still requires stream
integration, source-specific color/foam and shoreline treatment.

### Authored pond shoreline and bed coloring

NativeRecipeWater now exposes its flooded field separately from water mesh construction. Authored ponds contribute to a union wet mask and source-style two-pass signed shoreline distance field. Blank recipe terrain uses the source sand palette, slope cutoff, submerged-depth darkening and per-face shimmer at that shoreline. Dried-out ponds stop contributing; save/reopen and undo reconstruct the same colors.

`tests/test_native_shoreline.gd` passed: 257 terrain faces changed after pond placement; 185 lake bank/bed faces outside the stream corridor matched the imported fidelity RGB exactly (maximum error 0). Exact color reopen, dried basin and undo checks passed. `test_native_recipe_water.gd` retained its 4,002-sample footprint match, depth and fetch matches. `test_native_palette.gd` retained exact alpine and recipe roundtrip checks. Refreshed `pond-range-proof.png` using the existing editor-action harness; this is not the final manually authored full-world proof. Capture succeeded; the capture harness reported six ObjectDB instances leaked at shutdown.

Still incomplete: stream authoring and its shared shoreline/depth contribution, source water color/foam details, full population and final same-camera complete-scene comparison. The shoreline comparison deliberately excludes the stream corridor rather than claiming whole-world parity.

### Authored lake tint and source coordinate precision

Pond colors now use the source water gene's hue, tannin, silt and bloom through the shallow waterPaint/tintRamp calculation. Jitter and contour intersections retain the source's double-precision intermediate arithmetic until the final vertex packing. Previously the early Vector2 rounding changed hashed color-band selection even when the visible positions were nearly identical.

`test_native_recipe_water.gd` passed after this change: 271 lake-only non-impact-foam color faces match imported RGB exactly; 282 lake-only depth faces now match exactly; all eight fetch channels on 996 matching vertices now match exactly. Footprint remains 4,002 wet samples with zero disagreement; save/reopen, drying and undo checks pass. Refreshed the existing pond render harness. This verifies mesh inputs, not complete scene visual parity: stream contributions, impact foam, scenery and final full-world reconstruction remain outstanding.

### Bare-scene lake rendering control

Added `tools/capture_native_pond_compare.gd`. It constructs the blank/range/grass/pond editor state, fixes celestial phase to 0.4, pauses motion and hides UI. The `-- --imported-control` option replaces only the diagnostic water mesh and transform with the imported lake; it does not save that replacement as authored content. Both runs use the same authored terrain, material, camera and lighting setup.

Both captures succeeded (`pond-generated-control.png`, `pond-imported-control.png`). The imported lake also appears gray on the bare generated terrain. Therefore gray appearance alone is not evidence of an authored shader/material bug and does not justify retinting away from source values. The original mesh includes impact foam and stream-contributed water attributes absent from the authored pond; exact complete-image parity is not claimed. The capture helper still reports six ObjectDB instances at shutdown. This comparison is diagnostic evidence, not the final complete world built through editor controls.

### Native stream geometry port

Added `scripts/native_stream_geometry.gd`, a Godot implementation of source water.js `drawnLine` and `streamGeometry`. It consumes a course record, continuous terrain sampler and water ramp; it does not reuse the imported stream mesh. It retains double arithmetic through the bank fit, taper, curvature limit, mitre, depth, grade/bend smoothing and color calculations, then packs a renderable mesh with flow and growth channels.

`tests/test_native_stream_geometry.gd` compares the generated source-plan stream with imported mesh-38: all 816 vertices match exactly, as do depth, flow UVs, packed RGB and growth center/progress attributes (all maximum errors 0). The reference mesh is only the independent test oracle.

This is a construction module, not yet a completed editor stream feature. Still required: validated stream records, placement/route controls, save/reopen/undo integration, terrain carving, shared water/shore fields, and the full-world authoring proof. The existing point-to-point waterfall tool is unchanged.

### Stream editor placement and persistence

Range tools now include `Fill landscape streams`. The control generates the landscape's planned courses using its height, width and rotation, stores plain bounded stream records, and renders those records through NativeStreamGeometry with the source stream material. Reset clears them; undo/redo preserve them. Version 7 adds exact hex-double stream records and retains version 3–6 loading. Invalid stream documents are rejected before mutation.

`test_native_stream_editor.gd` passed: real button signal creates a rendered stream, undo removes it, redo restores the exact mesh arrays, JSON reopen restores the exact document and mesh, malformed/nonfinite course data rejects atomically, and v6 saves migrate with no streams. `test_native_build_tools.gd` passed with zero failures. `stream-range-proof.json/png` capture a saved range/pond/stream made through the editor-action harness (not a manual complete-scene reconstruction).

This control fills the range recipe's existing channels. Freeform course placement and carving are not implemented yet, and stream contributions to shared shore/depth/weather maps remain outstanding. Complete fidelity reconstruction still needs those integrations, waterfall work, scene population and the final saved/reopened comparison.

### Shared pond/stream depth and shoreline field

Authored streams now contribute source-style sampled width/depth stamps to lake depth and the shared wet mask. The signed-distance pass propagates the nearest water kind; terrain uses stream gravel, submerged darkening and the source grass override along low-elevation stream banks. Lake fetch still uses the individual lake mask, as the source does.

`test_native_recipe_water.gd -- --with-streams` passed across the previously excluded junction: all 332 matched lake depth faces and 321 non-impact-foam color faces have maximum error 0, as do eight fetch channels at 996 vertices. `test_native_shoreline.gd -- --with-streams` passed with all 3,872 terrain face colors matching the imported terrain exactly, plus exact save/reopen and undo. The whole-terrain comparison is now asserted. The pond-only shoreline regression still passes. Refreshed the saved `stream-range-proof` render.

This closes the source-plan terrain palette and pond/stream junction depth gaps. It does not prove complete-scene parity: freeform stream carving, stream weather-map integration, authored waterfall effects and complete scene population remain pending.

### Authored stream weather/surface maps

GardenSurfaceMap now samples generated stream triangles and their growth coordinates into the existing ground and stream textures during editor refresh. ReferenceGround reads the active material, so authored material overrides correctly identify flowing water. Highest-water selection preserves a pond where it covers a stream. No replacement texture breaks the rain/fog bindings.

`test_native_stream_surface_map.gd` passed against fidelity's original maps: 174 stream pixels, zero mask differences, exact flow/growth channels and exact water heights. Undo clears the authored stream map, redo restores it with the same texture object, and JSON reopen recreates the exact map bytes. This verifies the inputs consumed by weather/air shaders; it does not claim a new filmed weather comparison.

Still pending for the full benchmark: authored waterfall parity, remaining scene population, freeform stream carving, and the final complete saved/reopened scene comparison.

### Source waterfall course and ring placement

Added `native_fall_course.gd`: source continuous-height tracing, pool-lobe arrival test, short water-entry tail, channel room measurement, adaptive ring count and descent-weighted resampling. Point arithmetic stays double precision until a later renderer packs vertices. This is separate from the existing editor waterfall so an incomplete strand port does not replace working placement.

`tools/export_fall_course_fixture.mjs` extracts the current Electron tracer and resampler directly, runs analytic terrain cases with the original Three.js vectors, and records a source-fragment checksum. `test_native_fall_course.gd` passed all three fixtures, including 6/17/26-ring resampling: steep descent arrives in 27 stations, shallow apron is rejected in 18, closed pit is rejected after 203 including the source tail. Maximum coordinate error versus the independent JavaScript results is 0.

This proves tracing/resampling parity on those cases, not a rendered fidelity waterfall. Still needed: transported strand frames, terrain-constrained widths/thickness, aeration, editor persistence/placement integration, mist and impact foam, and the final populated-scene proof.

### Source waterfall strand geometry state

Added `native_fall_strand.gd`: transported frames, adaptive rings, room-limited width, thinning on steep drops, aeration over travel time, thickness/pinched inlet, surface-normal lift, impact and ledges. Its landscape builder distributes the source chute's strands and preserves the source fallback. Calculations use double-valued arrays until mesh packing.

Expanded the independent JavaScript fixture exporter to execute the original buildStrand body through its pre-mesh state, including a near-vertical wall case. `test_native_fall_strand.gd` passed slope/wall states with maximum error 0 and rejected both non-arriving cases. It also regenerated the actual seed-7 fidelity waterfall from ReferenceSourceGround: one strand matches the exported water-growth geometry state (centers, axes, widths, thickness, steepness, aeration, travel time and impact), maximum error approximately 1.79e-12. Course/resampling checks pass with the expanded fixture.

The visible editor waterfall is not replaced yet. Next required work is shader/mesh construction from this state, editable/saved placement, impact foam and mist, then complete scene population and final comparison.

### Regenerated waterfall renderer

Added `native_fall_renderer.gd`, which generates the 12-section strand mesh and feeds regenerated ring state into `reference_fall.gdshader`. Section whiteness and body whiteness are calculated from the source formulas. The mesh is generated from strand state; it is not the imported waterfall mesh.

`test_native_fall_renderer.gd` passed: 648 vertices, exact UV/face animation topology, and shader parameters matching the imported renderer within 1e-6 (reported aggregate error rounds to 0). `fall-renderer-proof.png` shows the regenerated waterfall on the editor-built range/pond/stream. This is a rendering harness proof only; the added fall is not yet saved as an editor record. Capture succeeded with the existing six-instance shutdown leak warning.

Still required: editor placement/persistence for this renderer, mist/impact foam integration, full scene population and final saved/reopened comparison.

### Saved landscape waterfall control

Range tools now include `Fill landscape waterfall`. The waterfall is regenerated from the terrain recipe and sculpt residual through NativeFallStrand/NativeFallRenderer. It follows the range transform and is represented by a version-8 boolean authoring choice, rather than storing or importing the rendered reference mesh. Reset/foundation formation clears it; version 3–7 saves continue to load with it disabled. Ambient water audio now recognizes this authored waterfall.

`test_native_fall_editor.gd` passed: button creates the fall, undo removes it, redo and JSON reopen restore the exact mesh, malformed flags reject atomically, and v7 migration works. The stream-editor persistence regression also passes. `fall-world-proof.json/png` were saved/captured through the range, stream and waterfall editor controls plus pond placement in the existing harness. This is an editor-action harness artifact, not the final manual populated-world proof.

Still pending: mist/impact foam, fuller waterfall placement controls and freeform stream carving, remaining scene population, and final whole-scene save/reopen comparison.

### Authored waterfall impact faces in the lake

Pond mesh coloring now reads regenerated waterfall impacts and uses the source flow-dependent impact radius. The impact positions follow the range transform. The renderer and foam calculation share the same strand builder; no reference impact positions are copied into the editor.

`test_native_recipe_water.gd -- --with-fall` passed with every authored lake triangle included: all 332 face colors (including the 11 formerly excluded foam faces) and depths match fidelity exactly; fetch still matches exactly at 996 vertices. Removing the waterfall clears its foam and undo restores exact colors. Saved/reopened pond surface, drying and undo checks remain passing. Refreshed `fall-world-proof.png` through the editor-action harness.

This is the lake's baked impact coloring. Animated impact rings/foam and airborne mist still require integration, alongside remaining scene population and the final complete saved/reopened comparison.

### Animated authored waterfall foam

NativeFallFoam now generates impact and ledge clusters from regenerated strand geometry using source foamCluster formulas. It reuses a reference icosahedron/material as the shape asset, scales geometry to each generated radius, and shares the existing fall_foam animation controller. GardenView rebuilds/removes these clusters with the saved waterfall and advances them with the scene's motion, pause, ice and growth state.

`test_native_fall_foam.gd` passed: seven generated blobs match reference geometry/anchors/gates within 1e-6; hidden/visible growth gates, bob/tumble movement, pause, undo removal and redo restoration work. This verifies generated state and lifecycle, not a synchronized pixel/film comparison of initial animation phase. Airborne mist and the final populated-scene comparison remain pending.

### Authored waterfall mist

Added `native_fall_mist.gd`: weighted plunge, ledge and veil emitters derived from regenerated strand state produce a deterministic particle recipe (origins, drift velocity, phase, size, rise) using the shared recipe hash. GardenView transforms the recipe through the range transform, splits it into batches of at most 64 particles, and renders each batch with the existing `studies/fall_mist.gd` layer bound to the scene's shared display-fog depth texture (or the original spray layer's fallback depth when fog is absent). Mist follows the saved waterfall flag; rebuild frees and recreates it, and it is gated on the same terrain/water growth thresholds as the foam.

`test_native_fall_mist.gd` passed (re-run September 7, 2026): 37 particles generated for the fidelity chute, maximum attribute error 0 against the exported `fall-mist.json` recipe, the mist material samples the same GPU depth texture as the shared compositor effect with no private fallback, undo removes the mist layer, and JSON reopen restores one layer with the expected particle count. Refreshed `fall-world-proof.png` through the editor-action harness; the capture helper still reports the six-instance shutdown leak, so this is not a clean leak check. Batch splitting above 64 particles is exercised by code path only; no scene in the suite exceeds one batch yet.

Still pending: scene population (trees, flowers, shrubs, rocks, arch, details), fuller waterfall/stream placement controls, and the final complete saved/reopened comparison.

### Populated landscape flora

Range tools now include `Populate landscape flora`. The source scene's placed instances are not imported: they are regenerated in `native_flora.gd`, a port of the Electron `foliage.js` `foliageJob` and `terrain.js` rim boulders, covering the mulberry-style RNG, V8 `Math.hypot`, THREE HSL colour math in linear space, the plot-space water field, the lattice-memoised site and flowering fields, and every scatter layer (conifers, grass tufts, broadleaves, shrubs, reeds, bank thickets, flower patches and meadow drift, cushions, logs, stumps, snags, mushrooms) plus the four rim boulders. The RNG draw order and the geometry-builder draws that must be skipped are recorded in the file's comments.

`fill_landscape_flora()` materialises the result as ordinary object records — catalog kinds, float32 `pose`, linear float32 `tint` — tagged `landscape:true`, so each instance stays individually erasable and reuses the existing version-8 persistence. Placements are generated in plot space and transformed by the range transform; boulders use an identity basis plus their pivot offset. The fill is atomic: it replaces only prior `landscape` records and restores the previous object list if any placement fails. `native_asset_catalog.gd` gained the `grass_tuft` and `daisy_flower` kinds, per-part `STEM_SCALE` corrections (spike 2.1, daisy 1.15) and a shared static `part_pose`/cached `pivots()`; `load_document` accepts the optional `landscape` bool.

`test_native_flora.gd` passed with 0 failures. Pressing the real button after range formation, the source pool pond and stream fill produced 3,178 records rendering 5,334 instances in 3,248 ms. Every batch matched `assets/zen_reference/scene.json` exactly in count: trunk 103, canopy 103, broadleaf 4 (+4 canopies), grass tuft 700, shrub 51, reeds 186, bank grass 53, flower heads and stems button 33 / spike 1,290 / umbel 182 / daisy 510, logs 17, stumps 3, snags 8, mushroom stems and caps 34, and one instance of each of the four boulders. Maximum colour error is 0 across every layer. Maximum transform error is 4.77e-7, on the spike flower stems, from the float32 stem-scale correction; the daisy stems are 2.38e-7 and the boulders 0.97–4.11e-7. Every other layer sits at 1.78e-15. All are inside the 1e-6 tolerance, which was not loosened. Undo removes every generated record and leaves no batches, redo restores identical instances, JSON reopen matches the saved document and rendering exactly, repopulating replaces rather than duplicates, and a malformed `landscape` flag rejects atomically.

The full 73-test suite was run sequentially for the first time since the water/pose work: all 73 pass. `fall-world-proof.json/png` were refreshed through the editor-action harness with the population press added; the saved document carries 3,178 landscape records. The capture helper still reports the six-instance shutdown leak, so this is not a clean leak check.

Known limits, not hidden: the editor's arch tool grounds its baked mesh at the terrain height under the AABB centre, so the arch cannot sit at its source position — that needs a pose/offset for landmarks or a landscape-arch fill. Wildlife (frogs, rings, birds) is not part of population and is still absent. Non-identity range transforms lose float exactness by design. Authored ponds flood as source lakes, with no spill promises and no pond-area cap. Bigfoot remains out of scope.

Still pending: the arch placement follow-up, wildlife, fuller waterfall/stream placement controls and freeform carving, and the final complete manually authored saved/reopened comparison.

### Real-time brush refresh

A drag calls `refresh()` up to thirty times a second and every call used to
rebuild the whole chunk from the records. On `fall-world-proof.json` (3,178
object records, 5,334 rendered instances, 3,872 terrain faces) that was 565 ms a
dab, so the brush moved in visible jumps. The rendered result is unchanged; only
the amount of work per dab is.

Nothing about the chunk's shape changes while sculpting except the height of the
vertices under the brush, so three kinds of saving apply. First, values that are
pure functions of the fixed geometry are computed once: the barycentric solution
for every sampled XZ point, each face's grass/rock/snow/shimmer palette entries
and rim flag, and the four sculpt-gradient probes a face reads. These keep the
original expressions — the same face is chosen in bucket order and the same
doubles are multiplied — so the palette, shoreline and flora comparisons still
report the same errors as before. Second, values that only depend on the recipe
survive an unchanged `_set_recipe`, which is what every sculpt undo restores: the
recipe's sampled heights and gradients, the water field's grid of unsculpted
heights (kept in doubles so adding the sculpt delta reproduces the original sum),
and a memo of `NativeTerrainRecipe.height` for the stream and waterfall samplers.
Third, the rebuilds themselves are scoped:

- `build_mesh` keeps its last arrays and recomputes only the faces whose bucket
  meets the changed region. The region is derived by diffing the current heights
  and cover against the arrays the cached build used, then grown by the largest
  face diagonal plus the 0.25 gradient offset and one meadow cell, which is the
  furthest a moved vertex can reach into another face's shading.
- The shoreline field is reused unless the edit lands on a cell that is wet,
  borders a wet cell, or seeds a pond. Heights elsewhere are read by the flood
  and discarded, so the field cannot move. When it is recomputed and comes out
  different, the whole mesh is rebuilt.
- `GardenView` keeps its batches and moves only the instances inside the region,
  re-sampling each from the same recipe the full rebuild used, so the meadow
  scatter keeps its seeds and every colour is untouched. Object records are
  tracked by a revision counter because serialising 3,000 of them costs more than
  the refresh. Stream geometry and the landscape waterfall record which terrain
  vertices they read through `sample`; identical inputs retrace an identical
  path, so those recorded heights say exactly when a retrace is needed however
  far the trace wandered. The waterfall trace is also memoised, since a rebuild
  asks for it once to render and once per pond for its impact foam.
- The surface map resamples only the pixels the edit can reach. Both overlays
  gained a clip rectangle, which is sound because each decides a pixel from that
  pixel's own ground value alone; `paint_streams` additionally skips pixels
  outside the rendered streams' bounds, where every sampler misses anyway.

`tests/test_native_refresh_incremental.gd` is the guard. On the populated demo
world it drives eight strokes — clear of the water, through the pond, along the
stream, under the waterfall's course, a wide smooth, ground cover, meadow and
erase — refreshing after every dab exactly as `_process` does, and compares the
terrain and skirt mesh arrays, every MultiMesh instance transform and colour, the
pond and stream and waterfall meshes, the landmark poses and both surface map
textures byte for byte against `force_refresh()`, which discards every cache and
rebuilds from the same records. It then undoes all eight strokes and asserts the
result is byte-identical to the world as opened, and that redo matches a full
rebuild too. It passed with 0 failures. Shrinking the face margin to zero or
disabling the wet-cell test makes it fail, so those two gates are load-bearing.

Measured with `tools/profile_refresh.gd` on the same world, before and after:

| | before | after |
|---|---|---|
| `build_mesh` (cold, full) | 315 ms | 132 ms |
| `GardenView.rebuild` (cold, full) | 246 ms | 52 ms |
| surface map height pass | 73 ms | 8 ms |
| `paint_streams` | 15 ms | 9 ms |
| one dab plus `refresh()` | 565 ms | 15 ms |
| undo on a sculpted chunk | 1,232 ms | 33 ms |
| undo of the first stroke on a pristine range | 1,232 ms | 100 ms |

The first stroke on a freshly formed landscape is the one slow case: it crosses
from "heights are identical to the recipe" to "sculpted", which every
recipe-derived cache has to notice, and undoing it crosses back. That is a
one-off per chunk, and it is the 100 ms row above rather than the 33 ms one.

Not addressed: a cover-painting dab still rebuilds the instance batches, because
changing a cell's density changes how many blades it scatters and therefore every
later instance index. Sculpting near water rebuilds the pond surface, the stream
geometry and the waterfall, which is correct but leaves those dabs at roughly
80 ms rather than 15 ms. The full 73-test suite was not re-run for this change;
the fifteen native editor scripts listed in the pond/stream/flora sections above
were, plus the new incremental test.

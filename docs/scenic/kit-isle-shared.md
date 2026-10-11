# Kit isle shared: one builder and one look for the hand-built sky isles

Branch `look/kit-isle-shared`, from main 94a4d1c0 with the four motif branches merged in (`look/motif-bell-spires`, `look/motif-cloister-tarn`, `look/motif-sundered-gorge`, `look/motif-colonnade-spine`). Not merged, not pushed.

The aqueduct isle and its four motifs now share one builder (`scripts/kit_isle/`, `studies/kit_isle.gd`), one ground and one rock. The isles' layouts did not change, and every route test passes.

## Run

The launchers, flags and scene picker entries are unchanged:

```sh
./run-aqueduct-isle.command        # or the picker: Ruins → Aqueduct isle
./run-bell-spires.command          # Ruins → Bell spires
./run-cloister-tarn.command        # Ruins → Cloister tarn
./run-sundered-gorge.command       # Ruins → Sundered gorge
./run-colonnade-spine.command      # Ruins → Colonnade spine
```

## What the user asked, and what changed

### 1. Ground: the edit chunks' look

**What the plate uses.** The plate's terrain (`assets/zen_reference/geometry.scn`, node `terrain`, roled by `scripts/scene_look.gd` `source_roles`) is `shaders/reference_surface.gdshader` with:

- `terrain_growth` on and `palette_role` 1, which turns on the calm grass field (`shaders/ground_look.gdshaderinc`);
- `flat_faces` and `wet_ground`.

Its faces carry the palette greens from `NativeTerrainPalette` (patch noise plus shimmer). The field pulls each grass face most of the way to one broad field of sunlit and deep patches. The light's ambient follows the smoothed ground, read from the plate's height map. The mesh is fine: `Plate.POINT_STEP` is 0.67 m.

The grass is the same as before. The kit isles already grew the plate catalog's `grass_tuft` and meadow flowers through `SkyIslets._plant_material`. The dense meadow grass is retired in the game too (`scripts/dense_grass.gd`).

**What the kit isles had.** The same shader, but with `flat_faces` alone and no `terrain_growth`. So there was no calm field: every 1–2 m face showed its own green and shimmer, which is the user's "noisy and geometric".

**Now** (`KitLook.ground_material`):

- **The plate's material settings.** `terrain_growth`, `palette_role` 1, `flat_faces`, `wet_ground`.
- **Smoothed normals.** Off the plate the height map has nothing for the isle, so the shader falls back to the mesh normal. `KitLook.GroundMesh` writes each vertex the area-weighted mean normal of the turf faces round it.
- **Averaged vertex colours.** Each vertex also gets the mean colour of the faces round it. A path now wears in softly instead of in hard brown triangles.
- **`facet_soft` 0.65.** The isle's faces are 1–2 m against the plate's 0.67 m, so its direct light also leans to the smoothed normal (the sky peaks' parameter). Without it, the isles read more faceted than the plate does.
- **Growth attributes.** `UV`/`UV2` are written for `terrain_growth`: UV.y 1 means grown, and UV2.y is the vertex's own height.

**Rock is split out of the ground.** Faces too steep for turf (past the palette's rock slope, or the colonnade's "flank" part) used to be ground faces painted the palette's pale rock. That was the colonnade's beige and the tarn's tan tiers. They now go to a separate rock mesh (`KitLand.surface`).

**Comparison.** `captures/kit-isle-shared/plate-alpine/` shows the plate in Alpine morning. Compare it with `compare-after/meadow-close.png` and `compare-before/meadow-close.png`.

### 2. Rock: the dark faceted islets

**What the islets use.** `scripts/sky_islets.gd` `_side_material` draws the islets' earth sides with `reference_surface` and `earth_sides`. The strata are recoloured by `scripts/rock_looks.gd` (basalt, slate, warm basalt; lifted and cooled), with `side_facets` 0.45 and `side_own`. The shader paints the bands by plate height, so the islets show a thin topsoil skin under the grass and then dark rock.

That height banding can't serve a kit isle, whose rims sit anywhere from 25 to 58 m.

**Now** (`KitLook.rock_material`, `KitLook.rock_tone`, `KitLook.RockMesh`):

- **The islets' own shading.** `earth_sides`, `side_facets` from `RockLooks.FACETS`, `side_own`.
- **Painted face by face** (`side_painted`, the way `scripts/sea_cliffs.gd` paints its walls).
- **Bands by depth under each face's own rim, not by world height.** Every rim, high or low, wears the same skin: from the top, topsoil (0.3 m), clay, sand, thin shale beds, then the rock in 1.35 m beds by world height. The beds wave a little. Hard beds use the paler core tones and soft beds the dark ones (`RockLooks.colour_of`, basalt).
- **Light variation.** Broad warm and cool patches. Faces lying back (ledges, steps) read 1.22× paler, so walkable ledges stand out.

**Where the rock applies:**

| Isle | Rock surfaces |
|---|---|
| All | Crags inside the ground; island sides and keels (`KitLand.ring_sides`) |
| Bell spires | The spires, in beds (their wide ledges are turf, in the ground material) |
| Sundered gorge | The gorge's sheer walls |
| Colonnade spine | The flanks and the keel |

**Kit stone stays kit stone.** Some solids are kit stone with a rock colour: the bell spires' stair corbels and the gorge's chimney pillar. They now take the islets' dark basalt tone (`CORBEL_ROCK`, `GORGE_ROCK`).

**What went:** the tarn's thick earth band, its tan quarry tiers, the colonnade's beige flanks, the brown banded spires, and the gorge's flat lit "cards".

### 3. The shared builder

| File | What it is |
|---|---|
| `scripts/kit_isle/kit_look.gd` (`KitLook`) | The ground and rock materials, the plate palette, `ground_tone` / `turf` (the turf's tone with wear and water), `rock_tone`, and `GroundMesh` / `RockMesh` (faces gathered, then drawn). |
| `scripts/kit_isle/kit_land.gd` (`KitLand`) | See the list below. |
| `scripts/kit_isle/kit_flora.gd` (`KitFlora`) | Grass and flowers (`grow`) and undergrowth (`undergrowth`) over a `Site`: `wear`, `wet`, `ray` (the rays' world y span) and `tufts`. `draw` makes tiled multimeshes: 24 m tiles for plants, 40 m for undergrowth. |
| `scripts/kit_isle/kit_life.gd` | The aqueduct isle's life, made general. Hooks: `make_birds`, `make_tokens`, `chaff_meadow` / `chaff_anchors`, `leaf_spots`, `ground_span`, `wind_box`, `ride_y`. It reads `scene.isle_top()` and `scene.flora_site()`. |
| `scripts/kit_isle/kit_birds.gd` | Songbirds. An isle answers `flock_specs()` and `spots(space)` (group name → candidate (x, z) points). `perches_from(space, candidates, ground_at, top)` finds the perches. |
| `scripts/kit_isle/kit_tokens.gd` | On-foot tokens. An isle answers `spots_for(isle)` with `{name, at, move}`. `under_lip` is a helper. |
| `scripts/kit_isle/deck_ground.gd` | The pilot's ground with live rope-bridge decks (`deck_at`) and hand ropes (`hold`). With `rest_decks` (bell spires), a resting deck that already stands as walk boxes sags by the sim's drop. |
| `studies/kit_isle.gd` | The base scene: everything that was generic in `studies/aqueduct_isle.gd`, plus hooks (below). |
| `scripts/ruin_kit.gd` `bridge_anchor(seed, weathered, width, spec)` | The one stone rope-bridge anchor. Coursed squared posts under a projecting course and a pyramid cap, a rope lashing band, and a dressed sill walked on a clean hull. `spec` sets `post_x`, `post_z`, `sill` / `sill_at`, a coursed `plinth`, or a coursed `head` block. It replaces `ruin_kit_belfry.gd` `bridge_anchor`, `RuinKit.rope_anchor` and `ruin_kit_cloister.gd` `abutment`. The posts collide as clean blocks up to their cap's top, because a cap's overhang caught the walker's shoulder. A fallen cap is drawn only. |

`KitLand` gives:

- outline helpers: `resample`, `blob`, `area`, `edge_distance`, `outward`;
- `wear_of(paths)`;
- `cliff_points(ground, box, rng, walled, foot_most, wobble, nudge)`;
- `Gather`: the outline, then `add_cliffs`, then the jittered `grid` with fine boxes;
- `surface(points, heights, poly, rng, tone, rocky, cliffy, steep)`, which returns the ground mesh, rock mesh, collided faces and cliff prisms;
- `draw`;
- `bodies(node, faces, prisms, together)`: trimesh plus prisms, never more than 2,048 shapes in one body, overflowing into `Cliffs0`, `Cliffs1`…;
- `turf_bodies`;
- `ring_sides` (sides and keel);
- `island(spec)`: the aqueduct and tarn island.

**`studies/kit_isle.gd` gives:**

- the character study's pilot, his wake and the deck ground;
- the look rig and presets;
- the plane with its bump and set-down; the rope bridges shudder as it passes;
- the rope-bridge tread on foot: weight, landings, a footfall a stride, and carry;
- the lodestone and its shard;
- flora, sky and life;
- captures.

**Hooks a motif answers:**

| Hook | What it gives |
|---|---|
| `_load_pack` | Its start, `lost`, `stations` |
| `_build_art` | Its land and ruins under `art`; each land registered with `add_turf(land, outline, cliffs)` |
| `isle_name` | The name for its log lines |
| `isle_top` | Its datum: the rays down and the plane's cloud floor |
| `isle_summit` | The air's summit |
| `flora_site`, `flora_seed` | Its ground for the plants |
| `lode_rest_at`, `lode_hint` | Where the lodestone rests, and the hint while it rests out of reach |
| `sky_script` | `studies/aqueduct_isle_sky.gd` or a subclass answering `plane_tokens()` / `token_source()` |
| `life_script` | A `kit_life.gd` subclass |
| `capture_look` | What a capture looks at when only `--at` is given |
| `plane_mask`, `_fly_tick`, `_shard_arch`, `_start_in_plane` | Optional: what the plane bumps off, the isle's own step each flown frame, whether the shard bears its arch, how `--fly` starts (the aqueduct isle's hall chain uses all four) |

**How a new motif is built:**

1. Write a `studies/<motif>_isle_art.gd`. Its ground function feeds `KitLand.Gather`, then `KitLand.cliff_points` for its steps, then `KitLand.surface`, `draw` and `bodies`. Use `KitLand.island(spec)` for plain islands, and `ring_sides` or your own sides drawn with a `KitLook.RockMesh`. Rock faces of any custom landform go through `RockMesh.add(tri, rim, toward, jitter)`, so they wear the islets' bands.
2. Write a `studies/<motif>_isle.gd` that extends `studies/kit_isle.gd` and answers the hooks. Call `add_turf` per land.
3. Write a `_life.gd` that extends `kit_life.gd`, with inner `kit_birds.gd` and `kit_tokens.gd` subclasses holding its spots. If it has plane tokens, add a sky subclass answering `plane_tokens()`.
4. Rope bridges: `Footbridge.live`, plus `RuinKit.bridge_anchor` at each end. The pilot's ground and tread come for free.

### Per isle

| Isle | What changed |
|---|---|
| Aqueduct isle | `aqueduct_isle.gd` is now a `kit_isle.gd` subclass (its station pack, art, stumps, lodestone). `aqueduct_isle_art.gd` `island` is `KitLand.island`; its own copies of cliff points, tone, sides, resample and the old static growth are gone. Flora is a thin wrapper over `KitFlora`. The undergrowth file is deleted. Life, birds and tokens are subclasses of the kit's. `floating_stones(seed, stones)` takes the stones as data. |
| Bell spires | Extends `kit_isle.gd`. The turf and isle sides use KitLand. The spires are drawn in the islets' rock, their wide ledges in turf, and they consume the same rng, so the spire hulls are unchanged. Its flora and undergrowth copies are deleted. Life, birds, tokens and sky are hook subclasses. Its `BridgeGround` is gone (`DeckGround.rest_decks`). The bell rings on landing as before. |
| Cloister tarn | `island` is `KitLand.island` (resample [100, 120, 32], hang, prisms apart). The tarn's own flora and undergrowth growers are gone (`flora_site`: bare = paths plus water, wet = the tarn, rays W+60 to W−12). TarnBirds, TarnTokens and TarnSky are hook subclasses. Its `BridgeGround`, tick and capture override are gone. Its abutments are the one anchor with a `head`. |
| Sundered gorge | Its island uses `Gather`, `surface` and `bodies`. Its walls are the islets' rock, still collided as drawn ("Sides"). Its cliff points and tone copies are gone. The flora file is deleted (`flora_site`: rays TOP+45 to TOP−18, 3 tufts/m²). `GorgeLife` holds `ray_span`. Its `DeckGround`, `decks` and the footfall tick moved to the kit; the footfall bounce is now every isle's. The rope anchor is the one anchor. |
| Colonnade spine | `spine_island` uses `KitLand.surface` (its flank faces are rock) and `bodies` (apart). Its sides are the islets' rock. The `use_paths` / `use_platforms` swaps of the aqueduct art's statics are gone: paths go through `KitLand.wear_of(Spine.paths())` and the stones through `Art.floating_stones(seed, Spine.platforms())`. Its `perches_from` copy is gone. |

The code shrank by about 2,450 lines across `studies/` and `scripts/` (4,336 added, 6,785 deleted, including the 3,643 lines of shared code).

## Layouts held

`tools/kit_isle_fingerprint.gd` checks what you stand on and bump. It opens an isle headless, casts about 62k rays straight down on a 0.5 m grid on every layer, and hashes every collision shape with its world points and layer, sorted, so a split into bodies doesn't count.

- `zsh tools/kit_isle_fingerprints.sh DIR` runs all five.
- `python3 tools/kit_isle_fp_check.py BASE NEW` compares two runs.

Results:

- **After the builder, life and scene refactor:** every isle's shapes were identical to the motif branches' and every ray within 1 mm, with one ray on an edge answering with another face's normal. Flora counts were identical too: aqueduct 8,592 tufts, bell 2,140, tarn 3,798, gorge 8,311, colonnade 2,751.
- **After the anchor unification:** only the anchors' shapes changed (posts and sill hulls); the rest of the layout is unchanged.
- **Since then:** the look changes moved nothing (checked against `captures/kit-isle-shared/fp-anchor`).

## Tests (headless)

| Test | Result |
|---|---|
| Import (`--headless --import`) | Clean |
| `test_aqueduct_isle.gd`, `_life`, `_look`, `_plane`, `_sky` | PASS. Some report PASS_WITH_KNOWN_ENGINE_ERROR: exit leaks. |
| `test_bell_spires_isle.gd`, `test_cloister_tarn_isle.gd`, `test_sundered_gorge_isle.gd`, `test_colonnade_spine_isle.gd` | PASS |
| `test_isle_lodestone.gd` | PASS (it reads the aqueduct scene's `LODE_PLATFORM`) |
| `test_ruin_kit.gd` | PASS (the anchor isn't in `PIECES`) |
| `test_scene_picker.gd`, `test_scene_picker_title.gd`, `test_scene_picker_entries.gd` | PASS, every isle entry free of script errors. One run of the entries test crashed at exit after "0 failures"; a rerun passed. `test_aqueduct_isle_look.gd` crashed the same way once on the unchanged merged base (in `sky_pierced.gd` teardown), so treat it as an existing flaky exit. |

The full suite was not run. Nothing was added to `tests/known_failures.txt`.

The one regression along the way: the colonnade's "second rope bridge back to the bench" route failed after the anchor change. The cap's overhang caught the walker sliding round a post. It was fixed by colliding the posts as clean blocks; no assertion was changed.

## Captures

All in `captures/kit-isle-shared/` (git-ignored):

| Folder | What |
|---|---|
| `before/<isle>/` | Every isle's views, taken from a clean export of the merged HEAD (`head-src/`) |
| `after/<isle>/` | The same views now |
| `compare-before/`, `compare-after/` | Close-ups: a far islet (`islet-close`, the rock's source), the aqueduct crags, keel and meadow, a bell spire, the gorge's wall |
| `plate-alpine/` | The plate's own ground in Alpine morning (`tools/capture_ground.gd --mood=alpine_morning`); `plate/` is its default look |
| `r1/`, `r2/` | Intermediate rounds |

**Scripts.** `tools/kit_isle_captures.sh OUT [isle…]` (bell spires now has `tools/bell_spires_captures.sh`) and `tools/kit_isle_compare_captures.sh OUT`.

## Perf

These are rendered captures on this Mac at 1440×900, Alpine morning, with the sky on, taken from the same views before (`before/`) and after (`after/`). The frame times swing a lot between runs and often clamp at 16.7 ms, so the draw calls are the reliable figure. The full per-view table is in `captures/kit-isle-shared/perf.md`.

| Isle | Mean draw calls, before → after | Mean primitives, before → after |
|---|---|---|
| aqueduct | 598 → 535 | 1.37M → 1.50M |
| bell | 624 → 595 | 0.88M → 0.90M |
| cloister | 661 → 624 | 1.27M → 1.33M |
| colonnade | 572 → 536 | 1.03M → 1.05M |
| gorge | 675 → 610 | 1.36M → 1.43M |

- **Draw calls are down 30–65 per view.** Most of it is the larger plant tiles.
- **Primitives are up 2–9%.** Larger tiles cull less finely.

- **Static triangles are unchanged** (aqueduct 303,691; bell 185,091; tarn 336,185; gorge 196,267; colonnade 302,981). The rock split adds one mesh per land.
- **Plant tiles are larger:**
  - grass and flowers: 16 m to 24 m tiles;
  - undergrowth: 40 m tiles.
  - On the tarn, the life drops from 199 to 136 surfaces and the flora from 89 to 55 batches.
- **Most draw calls are the shared sky** (far isles, clusters, airships: about 660 surfaces on the tarn, measured with `tools/kit_isle_instances.gd`), not the isle.
- **Colonnade.** Its 9.3k prisms and its build time are unchanged: the collision had to stay identical. Its prisms now sit in bodies of 2,048 rather than 2,000.

## What's weak

- **Sunlit rock reads mid-grey, not black.** A wall square to a low sun reads quite light (`compare-after/gorge-wall.png`); the far islets read the same in that light. Undersides in shade are near black, as the islets' are. A per-material base for the islets' keel mist (`earth_sides_base`) was not added: it only lightens the last 1.6 m.
- **Heightfield crags are fluted.** The cliff-point "mid" wobble makes thin sawtooth facets on tall heightfield faces (the tarn's tiers, the aqueduct's hill). That geometry is collided, so it was not touched. A drawn-only cliff mesh with broader facets over the same collision would read more like the islets' columns.
- **The keel shapes are still the old ring tapers,** not the islets' column-and-bulge walls (`SkyIslet._wall_rings`) or their faceted underside. The sides are drawn only on most isles, so the shapes could change freely next.
- **The far islets' own ground still has the old mosaic** (`SkyIslets._ground_material`, flat faces without `terrain_growth`). It now looks noisier than the kit isles beside it. Pointing it at `KitLook.ground_material` (with smoothed vertex normals) would match them.
- **Not shared yet:** the spire builder (`bell_spires_isle_art.gd` `spire_rock`, `cut_stair`, `stair_node`), the gorge's sheer sides and the colonnade's axis keel. Each now draws through `RockMesh`, but its geometry is its own.
- **The gorge's `GORGE_SHELTER` bounce is gone.** Its shaded wall reads dark navy, as the islets' shaded sides do.
- **Not checked rendered:** other looks than Alpine morning, and night.

## Remaining steps, in order

1. Have the user look at `after/` against `before/`, and at `compare-after/meadow-close.png` against `plate-alpine/`.
2. Move the sky islets' ground onto `KitLook.ground_material` so the whole sky reads the same.
3. Give the sides and keels the islets' column walls (drawn only).
4. Lift the spire builder and cut stairs into `scripts/kit_isle/`.
5. Optional perf: merge static kit pieces per isle (`RuinKit.merge`, keeping the collision), and LOD the far sky.

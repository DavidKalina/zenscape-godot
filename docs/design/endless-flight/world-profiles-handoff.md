# World profiles: one engine, many worlds (handoff)

This round adds the seam only. Endless flight is now one shared engine plus a world profile. `wilderness` is the default profile and gives exactly the world tagged `world-wilderness-v1` (a57c73d5). `--world=<id>` picks another profile. There is no new content: `test_dry` is a throwaway test profile that only proves the seam.

## The split

**Engine (shared, never forked).**
- `studies/endless_flight.gd` is the engine's scene driver and stays the game's scene. It runs the plane and flight (`scripts/sky_plane.gd`, manual landing, glide camera, speed feel), on foot (`scripts/endless/endless_walker.gd`), the HUD, and the harness hooks (`walk_ready`).
- Streaming: `land_stream.gd`, chunks, colliders.
- The native kernels and their GDScript fallbacks.
- The look's machinery: `endless_look.gd`, sky, clouds, light, fog, sea, and the shaders.
- The dressing machinery: grass, trees, birds, fish, traffic, arches.
- WorldScale stays the one source of sizes. The layout_overrides names did not change.

**World (profile).** `scripts/endless/world/world_profile.gd` is the base class, and each profile is a script under `scripts/endless/world/profiles/<id>.gd`. A profile has five tables:

| Table | What it holds | Who reads it |
|---|---|---|
| `land` | The land recipe, keyed as in `LandField.recipe_defaults()`. That covers continents (`continent_scale/swing/lift`, `lowland`), hills (`hill_scale/tall`), ranges (`range_scale/width/mask_scale/band`, `warp_scale/move`, `ridge_scale`, `peak_tall/scale`), meadows (`meadow_scale/band/keep/above`), valleys (`valley_scale/warp_scale/warp_move/swing/side/keep`) and `snow`. It also holds the knobs the flags already had: `mountains`, `peaks`, `valleys`, `carve*`, `rivers`, `river_*` and `ponds`. | `LandField._init`, which hands the table to `GDField` and to the native `configure` |
| `flora` | `forest` (the woods' share), `forest_meadows`, `tree_weights` (spruce variant weights; empty means HeroTrees.SPRUCE's), `grass` (tuft share), `flowers` | `land_trees.flags()`, `TreePlan.variant_weights()`, `endless_grass.setup` |
| `paint` | `mood`, `hour` (-1 means the mood's own), `ground` (endless_ground uniforms such as `wc_*`, `high_paint` and carpet tones), `sea` (endless_sea uniforms; rivers copy the sea's water), `globals` (shader globals set after the season reset) | `endless_look.setup`, `endless_grass.setup`, `endless_sea._init`, `endless_flight._ready` |
| `layers` | `trees`, `grass`, `birds`, `fish` (bools), `arches` (density), `traffic` (plane count; -1 means the engine's) | each layer's `flags()` / `wanted()` |
| `spawn` | `at` (xz), `alt`, `heading` (deg) | `endless_flight._ready` |

**Rule:** a profile only sets defaults. Every existing flag still overrides it (`--forest=`, `--no-rivers`, `--mood=`, `--ground-set=` and the rest), because each flag reader now starts from the profile's value instead of a literal.

`WorldProfile.current()` resolves `--world=` from the launch args and keeps the profile for that id. Because of that, every `Field.new(seed)` on any worker thread grows the same world without extra plumbing. This also covers tools that build fields themselves, such as `tools/land_hash.py -- --world=test_dry` and the parity drivers. `--world=res://path.gd` loads a throwaway profile script, for example one in scratch/.

## Native

- `ZenScapeLandField` is now **version 2**. The land recipe constants in `native/terrain_kernels/land_field.h` are now members, at wilderness's values. `configure` reads them from the knobs dictionary (`ZS_RECIPE` in `land_field_bind.h`), and a missing key keeps wilderness's value. GDScript `GDField` reads the same keys into `r_*` members. The `LandField` constants remain the documented defaults (`recipe_defaults()`).
- **Old libraries still work for wilderness.** `LandField.native_available(need)` accepts a version-1 library when the recipe is stock. Only a world with its own recipe needs version 2; on an old library that world falls back to GDScript and logs a warning. As a result, a Mac whose dylib has not been rebuilt still plays wilderness natively.
- Grass (`ZenScapeGrass`) and trees (`ZenScapeTrees`) needed no C++ change. Their per-world numbers already arrive through their `configure` dictionaries: `tufts` comes from the grass share, `flowers`, and `share`, `meadows` and `weights` for trees. The profile now feeds those dictionaries. Their deeper constants (tree FOREST/DENSE_AT/GROVE_AT, slot spacing, grass densities) are still hard-coded on both sides. When a world needs them, they would move into the config dictionaries the same way.
- Windows DLLs are rebuilt, both debug and release.
- **Mac:** rebuild the dylib for both targets (as in native-trees-handoff.md). Wilderness works without the rebuild. `--world=test_dry` and any future recipe world run their land in GDScript until it is rebuilt.
  ```
  python3 tools/build_native_kernels.py --godot /Applications/Godot.app/Contents/MacOS/Godot --godot-cpp <godot-cpp> --scons scons --arch universal --target template_debug
  python3 tools/build_native_kernels.py --godot /Applications/Godot.app/Contents/MacOS/Godot --godot-cpp <godot-cpp> --scons scons --arch universal --target template_release
  ```
  After rebuilding, compare `python3 tools/land_hash.py -- --world=test_dry` with `-- --world=test_dry --land-native=0`; the `exact` lines must match.

## Making a new world

1. Copy `scripts/endless/world/profiles/wilderness.gd` to `<id>.gd` and set `id` and `title`.
2. Change table values. `land` starts from `Field.recipe_defaults()`; overwrite keys with `land.merge({...}, true)` or `land.key = v`. Recipe keys and knob keys never share a name (`valleys` is the depth knob; `valley_scale` is the noise scale).
3. Play it with `--world=<id>`. Smoke it with `python tools/smoke.py studies/endless_flight.tscn -- --world=<id>`, and check native/GDScript parity with `tools/land_hash.py -- --world=<id>` with and without `--land-native=0`.
4. Keep the meadows-and-flats contract: a world that changes `meadow_*`, `valley_*` or `hill_*` still needs flats long enough to land on, close by.
5. New dressing (RuinKit halls, Sundered halls cut into ridges) is engine machinery: a new layer node in `endless_flight.gd`, gated by a new `layers` key (default off in the base class, so wilderness is unchanged), and asking `layer_at` per unit of work (below). Name its pieces through layout_overrides.

## Regions (how blending plugs in, not built)

The API is already in place: `world.at(x, z)` returns the profile holding a spot, `world.weights_at(x, z)` returns `{profile: weight}`, `world.layer_at(layer, x, z)` says whether a layer runs there, and `world.uniform` tells the engine whether it can skip all of these. A regions world extends WorldProfile, sets `uniform = false`, holds child profiles plus a region map (noise or Voronoi over xz), and answers those three calls.

- **Dressing layers by mask. Live now.** Grass asks per cell (`endless_grass._grow`), and trees ask per block and per far cell (`land_trees._commit`, which stands an empty block). A uniform world never makes these calls. Checked with a throwaway non-uniform profile (`scratch/world_profiles/regions_check.gd`: no trees or grass where x > 0): 0 tree blocks and 0 grass cells on the masked side, all on the other, 0 errors. Still to wire: arches. Their spots feed the tree plan (`arches_flat`), so a mask must apply in `ArchPlan` itself so the trees agree. Birds, fish and traffic are whole-layer today.
- **Land heights blend.** This happens inside `LandField`, not its callers. Build one impl (`GDField` or native) per child profile's `land`. In `sample`/`height`/`build_chunk`, look up `weights_at` per sample, skipping it where one region holds a whole chunk (test the chunk's corners first), and blend heights and meadow by weight. Native: either one `ZenScapeLandField` per region with GDScript blending (simplest), or a `configure_regions` that takes N recipes plus the region noise's parameters, so the blend runs in C++ with no per-sample GDScript. Keep the blend's own maths in both kernels, bit for bit.
- **Flora per spot.** Grass and trees already configure one native object per settings dictionary. A regions world keeps one `ZenScapeGrass`/`ZenScapeTrees` per child profile and picks it per cell or block with `at(cell centre)`. A cell on a border picks the profile with the highest weight, or dithers by weight per tuft with a hash.
- **Palette per spot.** Ground uniforms are per material. Either give each region its own ground material, chosen per chunk (land_stream `_build` picks the material), or bake a low-resolution region-weight texture the ground shader samples to mix two palettes. Sea and sky stay world-wide, or blend by the eye's `weights_at`.

## Proof (wilderness identical)

All comparisons are against `world-wilderness-v1`. The baseline was recorded before any edit, and again from a detached checkout of the tag (`.claude/worktrees/wp-baseline`, with its own v1 DLL built).

- **Hashes** from `scratch/world_profiles/identity.gd` through the real scene: a land grid of 14,400 heights and meadows, 4 chunk buffers (`build_chunk`), grass `grow_cell` buffers for 36 cells × 2 layers (about 620k instances), 16 tree blocks and 2 far cells (all buffers), and the flight's tree solids on an 80×80 grid of `top_at` after prime. It ran at seed 1 and at seed 7 `--at=2400,-1800`, each with native and with `--gdscript-kernels`. **All identical** to the tag.
- **`tools/land_hash.py`** (78,628 spots plus 6 chunks): seed 1 native, seed 1 GDScript, and seed 7 native. All `exact` hashes are unchanged (seed 1 `c515311f…`, seed 7 `cd244951…`).
- **Parity**, native against GDScript, through the scratch drivers. Trees (`trees_parity.gd`): 40/40 exact in both wilderness and test_dry, 0/2000 hash mismatches. Grass (`grass_parity.gd`): 1406/1406 parts exact in wilderness, 860/860 in test_dry. test_dry's land_hash is the same native and GDScript (`c3bfe25e…`).
- **Rendered stills** at 1440×900 (`captures/world-profiles/`, git-ignored):
  - Held views meadow_low, river, high and cruise (look_views.gd): 0, 3 (max 1/255), 0 and 0 differing pixels.
  - Live play frames, the default start and on foot: these differ from the tag only by run-to-run noise. Two tag runs differ from each other by the same amount: walker idle pose, and a tree edge as the plane moves.
- **Frame time**, real play loop, rendered, `--uncapped`, 20 s cruise then 20 s boost (fly_boost held), two runs each, tag vs now:
  - Cruise mean 10.73/10.84 ms (tag) vs 10.80/10.86 ms (now).
  - Boost mean 13.72/13.84 ms vs 13.77/13.84 ms.
  - p95 matches within 0.1 ms.
- **The GDScript land** is slightly slower: land_hash took 5.2 s at the tag and 5.4 s now. The cause is likely the recipe's member reads replacing constants, and the difference is near run noise.
- **Smoke**, headless, 400 frames, 0 errors each:
  - Default flying and `--on-foot`, each native and with `--gdscript-kernels`.
  - `--world=test_dry`: flying, `--on-foot`, and `--gdscript-kernels`.
  - The regions check profile, flying and on foot.
- **v1 library:** with the tag's v1 DLL swapped in, wilderness still grows natively. test_dry falls back to GDScript land with the same heights.

## test_dry (the test profile)

`scripts/endless/world/profiles/test_dry.gd` is marked as a test profile (`test = true`) and is not a world to play. It has:
- no rivers, ponds at 0.4, `hill_tall` 10 (a recipe number reaching the native field)
- forest 0.35, grass 0.8, no flowers, no fish
- desert_afternoon, wc_paint 0.6, warmer carpet tones, a zs_palette_grass tint, a sea shallow tint.

## Tests

Run in both trees on: the native_* tests, inland_recipe, lake_fill, plate_migration, threaded_*, forest_hold, world_scale_guard, landform_forest and aqueduct_isle_plane. Both give the same result: 17 pass and 3 fail, and the 3 failures are the known pre-existing ones (test_threaded_recipe, test_landform_forest, test_aqueduct_isle_plane). No test reads the profile yet. No existing test breaks. The full suite was not run.

## Left / notes

- A lock-in round could commit a test asserting that `wilderness` equals `recipe_defaults()` and that test_dry's land is identical native and GDScript (now proven by throwaway drivers only).
- Moving the arches into the regions mask (see above), and moving the deeper tree and grass constants into their config dictionaries, are left until a world needs them.
- Throwaway drivers (git-ignored) in `scratch/world_profiles/`: `identity.gd`, `run_identity.sh`, `seam_check.gd`, `regions_check.gd`, `perf.gd`, `onfoot_shot.gd`, `stills.sh`.

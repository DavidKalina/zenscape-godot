# Kit isle water: the edit chunks' water on the hand-built isles

Branch `look/kit-isle-water`, from main 459743f2. Not merged, not pushed.

The user, on the kit isles: "My only complaint is that the water looks terrible. We need to be using the water, if possible, that we have in the chunks that you edit, which is this beautiful kind of low poly water."

Every still water on the kit isles is now the edit chunks' own water: the plate's pond material on a fine sheet that carries the data it reads.

## Run

```sh
./run-cloister-tarn.command               # the tarn
./run-sundered-gorge.command              # the spring pool
./run-aqueduct-isle.command               # the channel on the aqueduct
./run-cloister-tarn.command --old-water   # any of them: the water as it was, for A/B
```

## What the plate's water is

The water you see in an edited chunk is the live water (`scripts/water_flow_view.gd`). Its still sheet comes from `ZenScapeWaterFlow::surface`:

- **A fine grid.** There is a vertex every 0.25 m (`water_flow.gd` CELL), and a quad is drawn where any corner is wet.
- **The bank.** A dry corner of a drawn quad stands at the level. Where its ground is barely above the level, it sits just under that ground, so the bank hides the water's edge.
- **The data on each vertex:**
  - COLOR: a depth palette;
  - UV.x: the distance to dry ground, for the shore foam;
  - UV2.x: the depth;
  - CUSTOM0/1: the fetch, open water in eight directions, which drives the chop.
- **The material.** It is a copy of the reference scene's pond material (`assets/zen_reference/geometry.scn` `mesh-30`, `shaders/lake_reference_water.gdshader`), set up with `shore_distance`, `live_level`, `depth_tint` and its tints, `bed_absorb` 2, `shallow_clear` 0.25, and a tea map.
- **The low-poly look.** The chop lifts each vertex with the wind and its gusts. The shader lights the moved faces as they stand (`dFdx`/`dFdy` face normals). A coarse fan has no vertices to stand that chop on.

The old isle water was the islets' 31-line `shaders/islet_pond.gdshader` on coarse fans (74 triangles for the whole tarn). The tarn's earlier try of the plate material read milky because its fan carried none of that data.

## The helper: `scripts/kit_isle/kit_water.gd` (`KitWater`)

```gdscript
var sheet: MeshInstance3D = KitWater.still({
	"level": 30.0,                              # the water's top (world y)
	"ground": func(x, z): return bed(x, z),     # the bed (world y)
	"rect": Rect2(...),                         # the box the grid is laid over (world x, z)
	"inside": func(p: Vector2): return on_land(p),  # optional: where water may stand
	"tea": 0.9,                                 # optional: 0 clear teal .. 1 a dark tarn
	"surround": Vector4(0.16, 0.2, 0.18, 0.37), # optional: walls round it (see below)
	"clear": 0.0,                               # optional: shallow_clear (m), 0.25 by default
	"falls": [Vector4(x, z, radius, strength)], # optional: churn where a fall lands in it
	"cell": 0.25, "name": "Tarn"})
```

**What it lays.** It lays the live water's still sheet over the ground function, with the same rules (grid, bank dip, the split along the lower diagonal) and the same per-vertex data (depth palette, shore run, depth, fetch).

- **The fetch** is swept per direction, capped at 9 m.
- **The shore run** is a chamfer distance.
- **The lip.** Where a wet cell borders a cell `inside` rejects, its vertex is moved onto the edge, found by bisection, plus 4 cm (`BRINK`). The sheet runs to the lip and the curtain fall's top takes it over.

**The material** (`KitWater.material(spec)`). It is the plate's pond material with the live still water's settings, let go of the plate as `SkyIslets._pond_material` lets it go:

- no planar mirror;
- no tea map over the plate's grid;
- no algae film (it is laid by world position);
- `depth_read` on: the bed behind each pixel is read from the depth buffer, as the lower world's ocean reads it. The colour deepens, the bed shows through the shallows and the lap follows the true bank pixel by pixel, much as under the plate's planar view.

`tea` is one cell of tea over everything.

**Placement.** Lay the sheet in the world's frame, or in a frame that is only translated, never rotated: the chop and the fetch read world axes.

**Other API:**

- `KitWater.arrays(spec)` returns the mesh arrays.
- `KitWater.old_water()` is the `--old-water` check.
- The sheet's meta holds `cells`, `vertices` and `triangles`.

**One shader change: `surround`.** It is a new uniform in `shaders/reference_water_body.gdshaderinc`, off at w 0, so every other water is unchanged. A reflected ray lower than the rim round the water (w, the sine of its elevation) takes the sky's light dimmed by rgb, as a mirror of dark walls would. Without it, the pale sky low on the horizon sheened the tarn grey where the plate's water mirrors its banks.

## Per isle

| Isle | Water now | Notes |
|---|---|---|
| Cloister tarn | The bowl and the spill channel to the lip (`TarnArt.water`): 6,036 wet cells, 12,652 triangles | `tea` 0.9: a near-black slate-blue tarn, umber over its shelf. `surround` (0.16, 0.2, 0.18) to about 22°: the arcades and crag. The `TarnSurface` collision (WATER_LAYER, the plane's skim) and the wading `pools()` are unchanged. |
| Sundered gorge | The spring pool and its outflow to the lip: 2,594 triangles | The plate's clear teal. The wading pool is unchanged. |
| Aqueduct isle | The channel on the deck, head to snap, to the parapets' inner faces: 1,190 triangles (`AqArt.channel_water`, added to `art` in the world's frame) | A 6 cm film. With the live water's clear shallows it all but vanished (darkened stone), so `clear` is 0 and the teal tint stays. Settled floor slabs show as slightly deeper patches. The wading pool is unchanged. |
| Bell spires, colonnade spine | No water | |

**What stays the islets' pond water.** The ruin kit's own water (`scripts/ruin_kit_aqueduct.gd` `_sheet`, `POND_SHADER`) is untouched. In the main sky world it draws:

- the pierced isle's aqueduct feed and run (`scripts/pierced_ruins.gd`);
- the Sundered halls' aqueduct (`scripts/sundered_build.gd`);
- the lodestone miniature;
- the ruin kit gallery.

So nothing in the game proper changes. The aqueduct isle's channel never used it: it had its own `shaders/aqueduct_channel.gdshader` film, which `--old-water` keeps.

**What was tried and dropped:**

- **The plate's moving water down the outflows and the channel** (`mesh-38`, the stream material, over water faster than 0.22 m/s). It keeps Godot's own sky specular, so out here it showed the sky's clouds as white blotches. Over the 6 cm channel it read as a pale teal slab. See `captures/kit-isle-water/r1`, `r2`.
- **The live falls' churn on the lip** (`fall_foam`). It drew white cloud-like patches on the water (`r4`). The plate's own edge falls put none on their lip. The option stays in the helper for a fall that lands in kit water.

## `--old-water`

`--old-water` draws:

- the tarn's and the gorge's old fans in the islets' pond water;
- the aqueduct's old running film.

Pass it to any launcher or capture script after `--`, for example `zsh tools/kit_isle_water_captures.sh DIR -- --old-water`.

## Captures

All captures are in `captures/kit-isle-water/` (git-ignored). They were taken at 1440×900 in Alpine morning.

| Folder | What |
|---|---|
| `plate/` | **The reference**: the plate's live pond (the test island), in the same look, from the shore and from skimming height, toward the sun and away (`tools/capture_plate_water.gd`). |
| `before/` | Each view with the old water. The tarn's `shore`, `skim`, `lip` and `high` were taken with `--old-water` (the same water as main) after their eyes moved. |
| `after/` | The same views now: `tarn-{shore,skim,gate,lip,high}`, `gorge-{shore,skim,lip,fall}`, `aqueduct-{deck,above,snap}` (`tools/kit_isle_water_captures.sh`). |
| `old-water/` | The A/B flag, four views. |
| `r1`–`r5`, `crops/` | Rounds along the way: `r1` without `surround`, `r2` with the moving sheet, `r4` with the lip churn, `crops/snap_top*` the channel from above. |
| `film/` | Films for the flicker check: `tarn-high-{new,old}.avi`, `tarn-far-new.avi`. |

**Toward a low sun the tarn sheens silver-grey.** The plate's water does the same in the same light (`plate/skim_sun.png`, `plate/shore_sun.png`). It comes from the material's broad specular (`lake_look.y` 0.86). On the plate the planar mirror's stronger fresnel hides more of it. Away from the sun the tarn is the dark slate-blue tarn (`after/tarn-shore.png`).

## Tests

These were run headless with `python3 tools/run_tests.py --tests ...`. The full suite was not run, and nothing was added to `tests/known_failures.txt`.

| Test | Result |
|---|---|
| Import (`--headless --import`) | Clean |
| `test_kit_water.gd` (new) | PASS |
| `test_cloister_tarn_isle.gd`, `test_sundered_gorge_isle.gd`, `test_bell_spires_isle.gd`, `test_colonnade_spine_isle.gd` | PASS |
| `test_aqueduct_isle.gd`, `_look`, `_life` | PASS |
| `test_aqueduct_isle_plane.gd`, `_sky` | PASS_WITH_KNOWN_ENGINE_ERROR (exit leak, as before) |
| `test_ruin_kit.gd` | PASS |
| `test_scene_picker_entries.gd` | PASS_WITH_KNOWN_ENGINE_ERROR (exit leak); 0 failures, every isle entry free of script errors |

The look itself is GPU-only and is unverified by tests; it was judged from the rendered captures.

## Cost

| What | Before → after |
|---|---|
| Triangles | Tarn 74 → 12,652; gorge 38 → 2,594; channel 60 → 1,190 |
| Draw calls | One mesh replaces one: unchanged, ±1 |
| Build | The tarn's sheet takes about 75 ms on the main thread at load, including the first read of the plate's material |

**Frame time.** Measured with `tools/kit_isle_water_cost.gd`: the water toggled on and off in place, 3 × 120 frames each, wall clock, vsync off, on this Mac. The viewport's GPU timer reads 0 on Metal. Toggling the old water reads −0.3 to −0.4 ms, which is the noise.

| View | Cost |
|---|---|
| Tarn, on foot by the gate (water fills about half the view) | +1.25 ms (+1.20 ms without `depth_read`, so it is the material's per-pixel lighting, not the bed read) |
| Tarn, skimming at 6 m | +0.39 ms |
| Gorge pool, on foot | +1.45 ms (noisy) |
| Channel, on the deck | +0.18 ms |

This is the plate's own per-pixel cost, which the plate pays too.

**Flicker.** `tools/water_flicker.sh` gives the mean grey-level change frame to frame over a patch of water, from films at a fixed 30 fps.

| Distance | New water | Old water | Grass |
|---|---|---|---|
| Tarn from 22 m | 0.60 | 0.65 | 0.27 |
| Tarn from about 90 m | 0.97 (worst 1.7) | | 0.22 |

The facets don't sparkle at a distance, but motion feel still wants a fly-through by eye.

## What's weak

- **No planar mirror.** The tarn mirrors the sky, and the walls only as a darker band (`surround`), not the arcades themselves. The plate mirrors its own land. The isle card calls the tarn "A mirror kept for no one".
- **The aqueduct channel no longer visibly runs along its length.** Only the wind's chop moves on it; the old film scrolled streaks. Seen from above, its settled slabs show as triangles of slightly deeper colour (`crops/snap_top.png`).
- **The tarn's shelf is a little milky green from the bank side.** The clear shallows show the turf bed.
- **Toward a low sun** the tarn reads silver-grey (see Captures).
- **The sheet is built on the main thread** (the tarn's about 75 ms) once at load.

## Next steps

1. **Have the user compare.** `after/` against `before/`, the tarn against `plate/`, and fly the tarn (`./run-cloister-tarn.command --fly`) and walk its shore for the motion. Flip `--old-water` for A/B.
2. **A planar view for the tarn.** This is the biggest remaining gap. `scripts/live_water_reflection.gd` is one view that follows a level, but its clip copies are tied to the chunk editor. A kit version would copy the isle's static meshes with the clip shader once.
3. **The sky islets' ponds.** In the game proper they already take the live still material when the editor is there (`SkyIslets._pond_material`), on their own sheets (`SkyIslet.water_arrays` rings, `IsletLake` 0.5 m grid): no bank dip, no `depth_read`, flat at the bank. In the kit isles' sky, without an editor, they fall back to `islet_pond`. They could take `KitWater.material` (the reference material read from `geometry.scn`, `depth_read`), and the lakes `KitWater.arrays`, for the same look on and off the plate.
4. **The ruin kit's water** (`Aqueduct._sheet`: the pierced isle, the Sundered halls, the gallery) could move onto `KitWater` with each piece's floor as its ground.
5. **Running water at lips and in the channel.** This needs the stream material without Godot's sky specular (SPECULAR 0 on the flowing path, or a kit wrapper shader).
6. **If the load ever hitches,** build the sheets on a worker (`scripts/background_work.gd`).

## Files

| File | What |
|---|---|
| `scripts/kit_isle/kit_water.gd` | The helper |
| `shaders/reference_water_body.gdshaderinc` | `surround` |
| `studies/cloister_tarn_isle_art.gd` | `water`, `on_mother`, TEA, SURROUND |
| `studies/cloister_tarn_isle.gd` | `_build_water`, `_old_water` |
| `studies/sundered_gorge_isle_art.gd` | `water`, `_old_sheet` |
| `studies/aqueduct_isle_art.gd` | `aqueduct` returns `water`; `channel_water` |
| `studies/aqueduct_isle.gd` | Adds the channel water to `art` |
| `tests/test_kit_water.gd` | The new test |
| `tools/kit_isle_water_captures.sh` | The views |
| `tools/capture_plate_water.gd` | The plate reference |
| `tools/kit_isle_water_probe.gd`, `.sh` | Every water mesh an isle draws, headless |
| `tools/kit_isle_water_cost.gd` | Frame cost of the water |
| `tools/water_flicker.sh` | Flicker from a film |

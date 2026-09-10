# Fire — design

Fire is the missing element. The diorama already has wetness, cold, snow,
wind, lightning, explosions, drop reactions, and a Bigfoot who reacts to
weather. Fire plugs into every one of those, so it makes the existing
simulation visibly deeper rather than wider. The fantasy: a lightning strike
or a dropped ember catches dry grass, the front races downwind, bushes and
canopies torch, trees are left as black snags in a field of ash, rain puts
it out, and over the next few minutes green returns.

This document is the contract between the sub-projects. Each section names
the owning script(s), the API other pieces may depend on, and what is out
of scope for the first pass.

## Ground rules (from the codebase map)

- Product stack only: `studies/diorama.gd` → `studies/fidelity_life.gd` →
  `studies/fidelity.gd`. Ignore the legacy toy garden (`garden_weather.gd`).
- No singletons. Subsystems are plain objects owned by `studies/fidelity.gd`,
  advanced in hand order from `_process` (`fidelity.gd:476-540`), and must
  freeze when `paused` while still republishing.
- Weather is global scalars in `studies/surface_weather.gd`:
  `ground_wet`, `foliage_wet`, `snow_cover`, `snow_phase`, `cold`, and
  rain in `_precipitation.state.x`. There is **no per-cell wetness map**.
- Wind: `LocalWindField.sample(position) -> Vector3` (m/s) on
  `scene._resident_wind.field`; fallback `_atmosphere._air_angle/_air_strength`.
- Lightning ground point: `scene._lightning.struck(point: Vector3)` signal
  (latch-and-consume pattern in `scripts/bigfoot_environment.gd:50-56`).
- Vegetation is per-instance records in `NativeTerrainData.objects`
  (`{id, asset, x, z, angle, scale, pose?, tint?, landscape?}`), rendered as
  one MultiMesh per part key in `scripts/garden_view.gd:213-304` with
  `use_colors` only. `use_custom_data` is not enabled on flora today.
- Ground cover is three `PackedFloat32Array`s on a 56×56 half-metre grid
  (`meadow`, `grass`, `blades`) plus `tint` (RGB + weight per cell,
  `scripts/native_terrain_tint.gd`). Explosions zero cover and call
  `erase_tint`; `paint_tint(center, radius, color, amount)` is the scorch brush.
- Deadwood already exists: `log`, `stump`, `snag` assets (palette role 4).
- No GPUParticles anywhere. Effects are MultiMesh quads + shaders + Tweens.
- Alpha-blended sprites **must** set `depth_draw_mode = DEPTH_DRAW_ALWAYS`
  or the Balanced fog composite hides them (`docs/garden/VALIDATION.md:110`).
  `blend_add` sprites (fireflies) are exempt. Glow/bloom is off under
  Balanced, so fire must read bright by albedo, not emission alone.
- Save: environment state goes through `scripts/native_garden_store.gd`.
  Adding to `FIELDS` invalidates old saves; use an optional sub-document
  with `document()/valid()/restore(value)` like `scripts/world_visuals.gd`.
  Per-object fields need a `NativeTerrainData` version bump with migration
  (`native_terrain_data.gd:958-1010`).
- Tests: `tests/test_*.gd` extends `SceneTree`, hand `tick()` loop, fake
  `World` node, run individually with `--headless --script`. Never run two
  Godot processes at once on this Mac (GPU lock). Docs live at
  `docs/fire/README.md` with prose, `## Implementation`, `## Verification`.

## 1. Simulation — `scripts/fire_field.gd` (`FireField`)

A `RefCounted`-style object created in `fidelity.gd` beside the other
subsystems and advanced right after `_lightning.advance` so a strike is
consumed the same frame.

**State.** One grid aligned to the meadow grid (`MEADOW_CELLS`, `MEADOW_STEP`).
Per cell, `PackedFloat32Array`s:

| array   | meaning |
|---------|---------|
| `fuel`  | 0..1, what can still burn here. Seeded from `max(grass, meadow, blades)` plus a canopy contribution from objects standing on the cell. |
| `heat`  | 0..1, accumulates from burning neighbours; ignites at threshold. |
| `burn`  | 0..1, burning intensity. Rises on ignition, decays as fuel is consumed. |
| `ash`   | 0..1, what burned. Drives the scorch look and regrowth. |

Water cells never burn (surface map alpha > ground height). Cells outside
the plot are inert.

**Setup.** `setup(data, wind_sampler, weather_sampler, water_sampler, rng_seed)`.
`wind_sampler(position: Vector3) -> Vector3` is m/s (`LocalWindField.sample`),
`weather_sampler() -> Dictionary` carries `ground_wet`/`snow_cover`/`rain`
(`studies/surface_weather.gd` plus `_precipitation.state.x`), and
`water_sampler(position: Vector3) -> bool` marks cells under water. All are
optional `Callable`s so the field runs headless in a test; `rng_seed` makes
ember spotting repeatable. `rebuild()` re-seeds fuel, canopy and the water
mask after a world change, and runs automatically when `objects_revision`
moves. Cells already alight keep the fuel they are burning.

**Tick.** Simulate at a fixed 8 Hz accumulator, not per frame. Each tick:

1. For every burning cell, push heat into the 8 neighbours. The push is
   scaled by `spread_rate * (1 + wind_bias)`, where `wind_bias` is the dot
   of the neighbour direction with `LocalWindField.sample(cell_center)`
   times `wind_scale`, clamped to `[-0.6, 2.0]`; diagonals are scaled by
   `1/sqrt(2)`. Un-ignited heat bleeds off at `heat_decay`. Measured with
   `spread_rate 0.30`, `wind_scale 0.18`, `heat_decay 0.50`: at 4 m/s the
   front runs 0.75 s/cell downwind and 2.81 s/cell upwind — 3.75× — and
   1.33 s/cell crosswind.
2. Suppression multiplies all heat transfer by
   `(1 - ground_wet) * (1 - snow_cover) * (1 - rain * 0.9)` and active
   burning decays faster in rain (`burn -= rain * 0.5 * dt`). It is a hard
   zero above `ground_wet 0.8` or `snow_cover 0.35`, which is what makes the
   section 6 "stalls" and "no spread" rows exact rather than merely slow.
3. A cell with `heat > 0.55` and `fuel > 0.05` ignites: `burn = 1`,
   `cell_ignited.emit(index, center)`.
4. A burning cell consumes fuel at `0.16/s` for pure grass and slower when
   canopy fuel is present, so a grass cell flares for ~6 s and a cell under
   a tree burns ~40 s. `ash += consumed`. When `fuel < 0.02`, `burn` fades
   out over 2 s and `cell_burned_out.emit(index)`.
5. Ember spotting: each tick, a burning cell with `burn > 0.7` in wind
   above 3 m/s has a small chance to add heat to a cell 3–8 cells downwind.
   The odds ramp in over the next 5 m/s, so a light breeze spots rarely and
   a gale spots often. This is what makes a fire jump a stream and feel
   alive; it is seeded, so tests are repeatable.
6. Regrowth: when no cell in a 3-cell radius is burning, `ash` decays at
   `1 / regrow_seconds` (default 240 s). Cover arrays lerp back toward the
   values remembered at burn time, and the tint layer lerps back from ash
   `#4a4643` to whatever colour the cell was painted before the fire; at
   `ash = 0` both are restored bit-exactly and the cell leaves the active
   list. Ground writes are batched once per advance, and the field writes the
   `tint` array per cell directly rather than through `paint_tint`, which is
   an O(grid) brush and would cost a full sweep per burning cell.

**Objects.** The field does not own object visuals; it owns their fire
state. `objects_state: Dictionary` id → `{burn: float, char: float}`.
An object ignites when the cell under its base ignites, or when a burning
object of a "tree" kind is within `1.5 * scale` metres (canopy-to-canopy).
Durations by kind:

| kind group | burn seconds | end state |
|---|---|---|
| grass_tuft, flowers, fern, reeds, bank_grass, mushroom | 4 | removed, ash on cell |
| shrub, cactus, leaf_bed | 12 | removed, ash |
| tree, layered_tree, redwood, broadleaf, bigfoot_tree | 40 | record swapped to `snag`, black tint, same pose/scale |
| log, stump, snag | 25 | stays, `char = 1` |
| rock, boulders, arch, waterfall, explosive | never | explosive detonates at `burn > 0.5` |

`kind` in every object signal is the **asset name** on the record
(`"tree"`, `"daisy_flower"`, …), not the group; `FireField.group_of(asset)`
maps an asset to its row above. The snag swap goes through a new
`NativeTerrainData.replace_object_asset(id, asset, tint)` — `update_object`
refuses asset changes and drops `landscape`, which the swap must keep.

Signals: `cell_ignited(index, center)`, `cell_burned_out(index)`,
`object_ignited(id, kind, position)`, `object_charring(id, char)`,
`object_burned_out(id, kind, position)`,
`explosive_triggered(id, position)`, `fire_started(position)`,
`fire_extinguished()`, `stroke_started()`, `stroke_ended()`.
The field never calls the explosives system itself: an explosive whose
`burn` passes 0.5 emits `explosive_triggered` and is left on the record for
the explosives owner to detonate.

**Ignition API.** `ignite(position: Vector3, radius := 0.6, strength := 1.0)`
adds heat in the radius. Everyone (lightning, explosives, torch tool,
tests) calls this and nothing else. The struck cell always takes the full
strength however the point sits inside it, and the rim thins out over the
outer half of the radius. Wetness gates ignition too, so a strike into a
soaked meadow fizzles.

**Queries.** `active() -> bool`, `burning_cells() -> PackedInt32Array`,
`cell_center(index) -> Vector3`, `cell_at(position) -> int`,
`burning_objects() -> Dictionary` (id → `{burn, char, kind, position}`),
`ash_center() -> Vector3`, and `total_intensity() -> float` for `zs_fire`.

**Undo policy.** Fire is a simulation, not a stroke. When the first cell
ignites while no fire is active the field emits `stroke_started`; when the
last cell dies it emits `stroke_ended` alongside `fire_extinguished`. The
integration layer wraps those in one editor stroke labelled `"fire"`, like
`"explosion"` today. The field never touches the editor itself.

**Persistence.** Optional `"fire"` sub-document with the usual
`document()/valid(value)/restore(value)` trio. It is **sparse**: hex-encoded
float32 runs over the active cell list (fuel/heat/burn/ash) and over the
remembered cells (`grass`, `meadow`, `blades` and the four tint channels),
plus the live object state as hex float64. Fuel elsewhere is re-seeded from
the cover arrays on restore, so an unlit meadow costs nothing to save. An
inert field documents as `{}` and a save with no `"fire"` key restores to an
inert field. Per-object `char` is **not** stored on the record; the field
owns it, which avoids the terrain-data version bump. Snag swaps are ordinary
record edits and save normally.

**Performance.** 3136 cells × a few floats at 8 Hz is negligible. Keep
a `_burning: PackedInt32Array` active list so idle frames cost nothing.

## 2. The burnt look — `garden_view.gd`, `reference_surface.gdshader`, `layered_canopy_surface.gdshader`

**Per-instance char.** Enable `use_custom_data = true` on every flora batch
in `garden_view._rebuild_instances`. `INSTANCE_CUSTOM.r = char`,
`.g = burn` (live flame heat on the mesh), `.b/.a` reserved. Add
`set_object_fire(id, char, burn)` to `GardenView` which writes custom data
for all parts of that record via `_sources`, no rebuild.

**`zs_char_paint`** in a new `shaders/reference_char.gdshaderinc`, modelled
on `reference_autumn.gdshaderinc`:

- `char` 0 → 0.5: leaves brown and curl (reuse the wet droop path in the
  vertex stage, exaggerated), colour heads toward `#3a2a1e`.
- `char` 0.5 → 1: canopy thins to skeleton. For `layered_canopy_surface`
  drive `leaf_thinness`; for `reference_surface` use alpha scissor on a
  hash of `VERTEX` so leaves vanish in clumps. Colour ends at charcoal
  `#141210` with roughness 1.
- `burn` adds an ember glow at the leaf edges: emission `#ff6a1a` scaled
  by `burn * (0.6 + 0.4 * flicker)`, flicker from `TIME` and instance hash.
  Bright enough by albedo to read under Balanced.

Insert the block after the snow block (`reference_surface.gdshader:144`,
`layered_canopy_surface.gdshader:146`). Snow on a charred tree should still
work; order: palette → autumn → char → wet → snow.

**Ground.** The field paints scorch through existing data:
`paint_tint(center, MEADOW_STEP, black, ash)` per burned cell, and cover
arrays go to zero while burning. Ash colour is `#4a4643` at `ash = 1`
fading to earth as regrowth runs. Regrowth writes the cover arrays back
and erases the tint over the same curve so grass visibly reclaims ash.
The editor's `objects_revision` / `content.revision` already invalidates
the mesh; batch the writes per simulation tick, not per cell.

**Snag swap.** On `object_burned_out` for a tree kind, `garden_view` is not
involved; the field edits the record in `NativeTerrainData` (asset →
`snag`, tint → charcoal, `landscape` preserved) and the normal rebuild
runs. The swap plays no drop reaction.

## 3. Flames, smoke, embers, ash — `scripts/fire_effects.gd` (`FireEffects`)

Owned by `fidelity.gd`, fed by `FireField` signals and a per-frame view of
the active cell list. Everything is MultiMesh + shader, capped.

- **Flames** `shaders/fire_flame.gdshader`: one MultiMesh of up to 384
  billboard quads, `blend_add`, `depth_draw_never` (add-blend survives the
  fog composite). Per-instance custom data `(phase, scale, lean_x, lean_z)`.
  Vertex stage: lick upward with two sines, lean with local wind. Fragment:
  scrolling noise masked by a teardrop, colour ramp black → red → orange →
  pale yellow core. Assign quads to the hottest cells first; an object with
  `burn > 0` gets flames along its part bounds, not just its base.
- **Smoke** `shaders/fire_smoke.gdshader`: up to 256 alpha-blended quads,
  **`DEPTH_DRAW_ALWAYS`**, soft grey ramp, rise at 1.2 m/s, advect with
  wind, grow and fade over 6 s. Smoke continues from ash cells at low
  density for 20 s after burnout so a burnt field smoulders.
- **Embers**: up to 128 add-blend points, spawned from cells with
  `burn > 0.7`, carried by wind with gravity, 2–4 s life. Purely visual;
  spotting is handled in the field so effects never affect simulation.
- **Ash fall**: reuse the precipitation sprite approach as a light grey
  drift downwind of large fires (more than 40 burning cells). Optional in
  the first pass.
- **Light**: a pool of four `OmniLight3D` assigned to the four largest
  fire clusters, orange, flicker on a 7–11 Hz noise, range 6 m. Zero-cost
  when no fire.
- **Camera**: `scene._tremor.add(0.15)` when a tree torches.

## 4. Ignition and integration

- **Lightning**: connect `_lightning.struck` → `fire_field.ignite(point, 0.8, 1.0)`.
  A strike into wet ground still hisses and smokes for a second (effects
  only) but does not catch. Storms ship with rain, so most strikes fizzle
  and the dry ones become events.
- **Explosives**: at the end of `native_explosives.detonate`, call
  `ignite(origin, blast_radius * 1.2, 1.0)`. Debris `RigidBody3D` parts
  that are trees can spawn a flame quad until they settle (optional).
- **Ember tool**: a new `"ember"` asset in the palette, Place row, glyph 🔥,
  no persistent record: it is a "special" like `fireflies`, and dropping it
  calls `ignite` at the drop point and plays a small puff. Use the
  `_take_special/_place_special` path in `native_build_palette.gd:1330`.
- **Water puts it out**: cells whose surface-map water level is above the
  ground are inert; the field reads `scene._precipitation.ground_texture`
  once per rebuild, not per tick.
- **Wiring**: `fidelity.gd` creates `_fire_field` and `_fire_effects`,
  advances them after lightning and before Bigfoot, and registers a
  `zs_fire` global (total burning intensity 0..1) for future shader use
  (sky tint from a big fire is a later pass).
- **Docs**: `docs/fire/README.md` in the house format, plus
  `tools/film_fire.gd` producing a strip of stills: ignition, downwind
  front, torching tree, rain extinguish, ash, regrowth.

## 5. Bigfoot — `scripts/bigfoot_environment.gd`, `creature_brain.gd`

There is no flee behaviour in the repo today. This is the one genuinely
new creature verb.

- **Flee** (new): on `fire_started` within 14 m, or any burning cell within
  6 m, cancel everything (`routine.cancel("fire")`), `_begin("startle")`,
  then pick a navigation node that maximises distance from the nearest
  burning cell weighted by upwind direction, and route there via
  `navigation.path`. Locomotion tempo 1.4. Re-evaluate every 2 s while any
  fire is within 10 m.
- **Watch**: once safe, turn to face the fire and hold an alert pose
  (reuse the rainbow "horizon" watch with the head tracking the nearest
  flame). Emoji bubble 😨 then 😮.
- **Curiosity**: 30 s after `fire_extinguished`, if the burnt area is
  within his roam, `brain.investigate(ash_center)` and play a new short
  "warm hands" clip at the smoulder: crouch, palms out, two-second hold,
  one slow shake of the head. This is the payoff scene.
- **Temper**: a fire within 4 m of his rest spot or his hugged tree calls
  `temper.provoke(0.6)`.
- **Coat**: skip singeing in the first pass. Ash dusting reuses
  `bigfoot_wetness` darkening with a grey tint when he walks on ash cells,
  if cheap; otherwise later.

## 6. Timing and tuning targets

| thing | target |
|---|---|
| grass front speed, dry, 4 m/s wind | ~1 cell / 0.8 s downwind, ~1 cell / 3 s upwind |
| grass front speed, ground_wet 0.5 | half that; stalls above 0.8 |
| snow_cover 0.5 | no spread |
| tree torch to snag | 40 s |
| full extinguish under rain 1.0 | under 12 s |
| smoulder smoke after burnout | 20 s |
| regrowth to full green | 240 s, tunable in Settings later |

## 7. Out of scope for the first pass

Fire on Bigfoot's coat, fire spreading through water-borne debris,
sky/fog tinting from smoke, a campfire object, a water bucket tool, fire
sound beyond crackle, seasonal fuel dryness (autumn should burn hotter;
that is a one-line multiplier for pass two).

## 8. Sub-projects and order

Phase 1, alone: **A. Simulation** (`FireField`, tests, persistence). It
defines the API every other piece consumes. Small and fast.

Phase 2, in parallel worktrees against A's interface:

- **B. Burnt look**: custom data plumbing, char shader include, ground
  scorch and regrowth writes, snag swap. Test: ignite, tick, assert custom
  data and record swap; film strip.
- **C. Fire effects**: flames, smoke, embers, lights, crackle audio, tremor.
  Film clip.
- **D. Ignition and integration**: lightning, explosives, ember tool,
  fidelity wiring, undo stroke, `zs_fire`, docs README, `tools/film_fire.gd`.
- **E. Bigfoot**: flee, watch, curiosity, warm hands, temper. Test with the
  fake `World` in `tests/test_bigfoot_environment.gd` style.

Merge order: A, D, B, C, E. D touches `fidelity.gd`; B touches
`garden_view.gd` and the surface shaders; C is additive; E touches
`bigfoot_environment.gd` and `creature_brain.gd`. No two worktrees should
edit the same file.

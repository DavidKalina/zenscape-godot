# Shared world variety

The accepted visual-lab features are now available through the production editor
and title generator. Original native landscapes and trees remain available.

- **Landscapes → Wild landscapes:** all fifteen inland compositions, four mountain
  archetypes, crest/valley profiles, six habitats, seed, height and breadth.
- **Scene colors & atmosphere → Atmosphere:** living fog density/height, peak cloud
  density/altitude, and clean/layered/weathered rock faces with detail strength.
  Both cloud layers travel with the shared wind; zero density disables a layer.
- **Miniatures:** layered tree and cactus are additional placeable catalog assets.
  Woodland generation mixes original conifers/broadleaves with layered trees.
- **Title:** retains native formations and adds tall massifs, twin peaks, Nahanni-style
  valleys, desert monuments, salt basins and desert mountains with curated moods.
  Valley cameras sweep along the opening instead of orbiting behind the walls.

## Persistence and generation

`NativeTerrainRecipe` accepts a bounded `inland` document containing generator
version 3, seed, composition, archetype, landform, biome, relief and breadth.
Floating-point controls use the existing exact-double encoding. Geometry, surface
queries and water planning share the same replayed heightfield. Existing sculpted
heights, placed assets and water remain ordinary editable native records.
Generation uses the cooperative frame budget and existing undo/favorites path.

`world_visuals` is an optional, validated scene-state section. Older saves default
to disabled living fog/peak clouds and clean rock. Saved worlds retain all new
controls. Terrain height limits now allow 64 units, with stream headwaters up to
66; existing native formation output is unchanged.

The visual lab remains available for comparisons. Production modules and materials
are independent of the lab scene inheritance chain. Full volumetric effects use
Godot Forward+; dense fog and vegetation still warrant profiling on target hardware.

## Validation

- 45 JSON recipe round trips across every composition at maximum relief.
- 500 seeded cinematic title selections with validated recipes.
- Native full save/load of massif, valley and salt-basin worlds, sculpted heights,
  layered-tree placements, fog/cloud/rock settings, wind movement and fog reach.
- Older scene-state compatibility; diorama lifecycle, native landscape presets,
  favorites and scene-look regression tests.
- Native title captures in `docs/visual-lab/integration/` via
  `tools/capture_integrated_worlds.gd`.

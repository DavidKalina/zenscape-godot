# Inhabited landscape generation: first pass

Choose **Regrow landscape** in the cozy flow (or carry Bigfoot to an edge).
New procedural worlds use inland recipe version 4. Existing saved version 3
worlds retain their terrain, water and planting until explicitly regenerated.
The curated landscape gallery and fidelity scene are unchanged.

Version 4 gives mountain and massif compositions lower foreground slopes while
retaining their rear peaks. Three seeded clearings are selected against the
terrain and final water courses, separated by at least five world units. Small
terraces blend into the surrounding ground; tree trunks stay out of their
centers. Each clearing receives a log or rock focal point, a patch targeting 28
biome-specific small details, and fine ground cover where appropriate. Water,
salt and steep-ground exclusions still apply. The middle remains available for
Bigfoot and player-built objects.

Before regrowth selects a recipe, a 21 × 21 grid samples dry ground with a slope
no greater than 0.65. The acceptance targets are 28% usable ground, 18% in one
connected region, and three planned clearings. Up to eight candidates retain
the chosen family while varying seed and gradually softening relief. A gentle
meadow/foothill fallback avoids accepting a weak candidate after that budget.
Candidate scoring runs on a worker; scene changes and planting stay on the
existing frame-budgeted path.

These are geometric checks, not a complete aesthetic score or a guarantee that
all three clearings share a navigation route. Planted props can still obstruct
some ground; Bigfoot's existing navigation system remains authoritative. This
pass creates richer pockets from the existing asset vocabulary. It does not yet
compose distinct activities, bridges, caves, or new water features per clearing.

Validation:

- `tests/test_inland_places.gd`: 100 seeds meet the ground targets; deterministic
  layouts, JSON recipe roundtrip, downhill water records, six habitat/terrain
  fixtures with detail in every clearing, save/reload and worker equivalence.
- `tests/test_cozy_world_generator.gd`: 100 repeatable draws retain 14 composition
  families, eight landform profiles, six weather types and 100 unique palettes.
- `tests/test_inland_recipe.gd`: 45 exact recipe replay cases.
- `tests/test_cozy_worlds.gd`: 34 checks covering real regrowth, carry, Undo/Redo,
  and reopening generated terrain, palette and weather.
- `tools/capture_inland_places.gd`: paired version 3/4 Forward+ renders of massif,
  foothills and valley, saved under `/private/tmp/zenscape-places`.

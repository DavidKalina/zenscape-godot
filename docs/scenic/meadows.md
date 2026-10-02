# Meadows: five meadow types

Branch `beautification`. The user had made mountains with waterfalls and trees, but no meadow. The goal is a few meadow types that look beautiful on their own and mix with the other landscapes. After the first stills the user asked for much denser meadows: "Wizard of Oz poppy field" carpets of colour, not scattered specks.

Code: `scripts/meadow_types.gd`. Tests: `tests/test_meadow_types.gd` and `tests/test_meadow_lands_scene.gd`.

## How a player makes one

1. On the title, open New world.
2. Pick the **Meadow** row in the Land list. A **Kind** field appears under the list: Wildflower, Sunflower, Dandelion, Cosmos or Alpine. Click a kind, or press Left and Right while the name field is not focused. Up and Down still move between land rows, and the Meadow row remembers the last kind picked.
3. The backdrop previews the meadow live. Roll changes the seed. Begin makes the world.

Each kind is its own land id (`wildflowers`, `sunflowers`, `dandelions`, `cosmos`, `alpine_meadow`) in `scripts/world_library.gd` `LANDS`, grouped under `GROUPS.meadow`. `scripts/world_lands.gd` forms each one as a generated inland world with the meadow type in its recipe, then applies the type's mood. The library stores the land id, so a world rebuilds as the same meadow.

Once it exists, a meadow world is an ordinary world. You sculpt, pour water and paint forest on it like any other:

- **Emergence** grows the type's own flowers on new meadow ground (`scripts/emergence.gd` `_shrub_kind`). Raise a hill in a cosmos field and cosmos come up on it.
- **The meadow brush** paints in the type's own flower colours (`scripts/meadow_brush.gd`).
- **The badge** names the type, for example "Cosmos field and woodland · Meadow".

## The types

| Type | Land | Flowers (drift weights) | Ground and grass | Neighbours |
| --- | --- | --- | --- | --- |
| Wildflower meadow | basin with a central pond | oxeye daisy 1, buttercup 1, poppy 0.8, cosmos 0.35, lupine 0.35 | warm green, a little straw | wetland ring by the pond, woodland on the shaded side, 6 lone trees |
| Sunflower field | flat meadow (relief 0.55–0.75) | sunflower in rows 0.95 m apart, faces turned toward the noon sun's side; a few buttercups and daisies | warm green-gold, 14% straw patches, a quarter of tufts straw | a copse on the high ground, 3 lone trees |
| Dandelion meadow | rounder meadow hills | dandelion 1, seed clock 0.6 (interleaved, 30% companion share), buttercup, daisy | lush green, no straw, short tufts | woodland on the shaded side, 4 lone trees |
| Cosmos field | broad meadow sweeps | cosmos in pink, magenta and cream-white drifts (one colour each), a few daisies | sage green, some straw | a few trees on the high ground |
| Alpine meadow | mountain range with tarn and fall | buttercup 1, lupine 0.7, daisy 0.55, dandelion 0.25, at 0.65–1.05 of their height, mixing 30% | short green, stones scattered | alpine ground and snow above, woodland on the shaded side, no lone trees |

Mixing follows `scripts/biome_blend.gd`. Each neighbour claims its share of the land by one rule: moist, high or facing the shade. The rules apply in order and a later one wins, so alpine wins over woodland on the alpine meadow's heights. A moist neighbour is dropped on land without water.

## Composition

All of it is position hashes and seeded noise, so nothing draws from the planting stream:

- **Drifts of one kind.** A cellular noise gives each drift its kind. A small domain warp makes neighbouring drifts interleave over about half a metre instead of meeting on a line. Each type has a companion share (`mix`) for the odd other kind inside a drift. Cosmos colour also follows the drift: one colour per drift.
- **Soft edges and gaps.** A slow presence noise sets how much of a drift stands at a point. Flowers thin with presence to the power 1.2 toward the edge and leave grass between drifts. A few strays stand alone in that grass. Drifts run to the plate's rim: they thin out between `RIM` 10.9 and 11.85 m on a rounded square, and the candidate lattice reaches `REACH` 11.9 m. Before, they stopped at 9.5–11.4 m and left the outer third plain green.
- **Carpets.** Candidates sit on a 0.2 m jittered lattice, 25 per m². At a drift's heart, every candidate of a head 0.16 m wide or narrower is kept. Wider heads keep (0.16/head)² of them, so heads nearly touch; a key's `pack` overrides that (sunflowers keep 0.42). The ground under a drift is painted toward the flower's colour (`wash`) at a heavier weight (`carpet`).
- **The wash supports, never stands in.** Under thin drifts of low flowers the wash read as a flat yellow stain from the diorama camera. Now it follows the flowers that actually stand at a point (presence^1.2 × density × packing), so it fades before they do and never runs past them. A fine noise feathers its edge. A low kind that hides little ground washes it less, by its key's `cover` (buttercup 0.65, dandelion 0.7, seed clock 0.6), at both colour and weight.
- **Layered heights.** Each kind keeps its own height: dandelion 0.26 m, buttercup 0.38 m, daisy 0.57 m, cosmos 0.94 m, sunflower 1.83 m. Alpine flowers stand at 0.65–1.05 of that.
- **Sunflowers stand in rows and face one way.** They grow only on rows across the field (`rows`: 0.95 m apart, 0.2 of each wide), with a weak green-gold wash. With `face` on, every row-planted head turns to `SUN_FACE` ±0.4 rad, the noon sun's side of the plate, which is also the side the diorama camera starts on. The head faces up and out at about 45°, so from above or at an angle the field reads as gold faces, not stalks.
- **No stubble.** A typed meadow clears the standing blades and tuft flowers that `inland_landscape.gd` lays round its clearings. Its grass is painted ground plus a few tufts in the gaps, which is the settled look. Clearings get the type's flowers instead of the old four.

## The flower kit's keys

The parallel flower kit adds `oxeye_daisy`, `buttercup`, `dandelion`, `dandelion_clock`, `cosmos`, `sunflower`, `poppy` and `lupine`. Every placement goes through one table, `FLOWER_KEYS` in `scripts/meadow_types.gd`:

- `asset(kind)` returns the kit's key as soon as `NativeTerrainData.ASSETS` lists it. Until then it returns the entry's `fallback` (`daisy_flower`, `button_flower`, `umbel_flower` or `spike_flower`).
- A stand-in is stretched by a pose to the kind's `height` and `head`. `FALLBACK_FORMS` holds the stand-ins' own measured top and head width. Its head is tinted with the entry's `tints`.
- The kit's own meshes are placed at size 1 times the type's size range, untinted, because a kit tint multiplies petals only. To tint a kit kind anyway (for example cosmos colour drifts), set `"tint_real": true` on its entry.
- So merging the kit needs no change here, as long as the kit adds its keys to `NativeTerrainData.ASSETS` and `NativeAssetCatalog.PARTS`. The heights in the table are already the kit's.

## Saves

- New types sit behind a new recipe key: `"meadow": "<type>"` on an inland recipe whose biome is `meadow`. `NativeTerrainRecipe.valid` accepts it (known types only), and the codec keeps it as a string.
- Recipes without the key dress byte-for-byte as before. `tests/test_meadow_types.gd` checks objects, grass, meadow, blades and painted-ground digests against the commit before this work (b1e74ec) for 13 cases: six generated seeds, two without a blend, one without variety, the misty isle, and three formation presets.
- The emergence and clearing code paths keep their random draw order for untyped worlds.

## Cost

Measured headless (dummy renderer) at seeds 11, 2024 and 777 with `tools/probe_meadow_digests.gd -- types`. The test's seed is 2081.

| Type | Records | Flowers (seed 2081) | Dressing time (main thread, under the frame budget) |
| --- | --- | --- | --- |
| Wildflower | ~3,000–3,900 | 3,393 | 340–415 ms |
| Sunflower | ~700–1,700 | 1,491 | 180–230 ms |
| Dandelion | ~3,100–4,400 | 4,243 | 275–320 ms |
| Cosmos | ~2,300–3,250 | 3,114 | 225–270 ms |
| Alpine | ~1,200–1,800 | 1,700 | 300–340 ms |

- Planning the recipe (building the land once to place the neighbours) takes 80–90 ms.
- Forming a meadow land in the full scene takes 1.1–1.8 s headless. The existing lands take 0.44–0.63 s.
- A full view refresh (what a stroke triggers) takes 50–145 ms headless on a meadow world.
- Each flower is two instances, stem and head. A dense wildflower or dandelion world draws about 7,000–8,500 flower instances.
- With the kit's 200–510-triangle plants, that is roughly 0.7–2 M triangles for the flowers on the densest types.

**Flagged:**

- Rendered frame cost, before and after the distance thinning and far detail, is in docs/scenic/flowers.md, Cost. The record counts above predate the coverage to the rim, which adds roughly a fifth. Every flower batch is still one MultiMesh over the whole plate; thinning happens in the material.
- If the kit's triangles prove too costly on the Mac, the levers are `spacing` (0.2 m) and `PACK_HEAD` (0.16 m) in `meadow_types.gd`.
- Placement itself is fine in GDScript: the cheap noise tests run first and most candidates fall in the grass.
- The view rebuilds the whole plate on every stroke, so a stroke on a meadow world costs about twice what it does on a forest world. An incremental (per-region) instance rebuild would fix that. Native code is not needed for placement.

## How to look at each type

Rendered stills need a window. Always pass `--no-title`.

```sh
Godot --windowed --path . --resolution 1280x720 -s res://tools/still_meadows.gd -- --no-title [--lands=sunflowers,cosmos] [--seed=meadow-lark-2081] [--views=diorama,near]
```

- This saves `captures/meadows/<land>-<seed>-<view>.png`: the diorama overview and a nearer, lower view. The stills behind this note use seed text `meadow-lark-2081`.
- Headless top-down maps of the composition, with habitats, water, painted ground and every record as a dot: `godot --headless --path . -s res://tools/map_meadows.gd -- [--types=cosmos] [--seed=2081]` saves `captures/meadows/map-<type>-<seed>.png`.
- In the game, use New world → Meadow → a kind with any seed. Seed text `meadow-lark-2081` reproduces the stills.

## The look, 2026-10-02

After the flower kit came in, a critique of the stills found: drifts stopping two metres short of the rim; the wash under thin buttercup, dandelion and alpine drifts reading as a flat stain; the sunflower field reading as dark leafy clumps on straw (small dark drooping heads, sparse rows); alpine flowers tiny and patchy; lupines reading blue; white cosmos going cool blue in shade. What changed for each is above (Composition, the table) and in docs/scenic/flowers.md (the sunflower head; lupine variants `7b4cc6` and `9c48b8` with paler tips `d4bfe6`; cosmos white `fcefe2`; dandelion gold `ffd024`). Stills from seed `meadow-lark-2081` are in `captures/meadows-v2/` on the machine that made them.

Still not right:

- The dandelion meadow reads as green with gold and white specks from the diorama camera, not a carpet. With the stain gone, the low heads alone cannot carry the colour at 20 m.
- The alpine meadow stays patchy: the mountain, tarn and slopes over 0.75 leave its meadow in pockets, and the flowers are small by nature.
- Cosmos and wildflower drifts are thinner past 14 m than before (distance thinning), with the grown heads holding most of the cover. Near the camera they are as dense as before.
- In the wildflower meadow, ground left between drifts and the woodland edge is still plain green on some seeds.

## Unverified

- The stills and films were taken at 1280×720 and 3024×1898 on one Mac. Other GPUs, and the frame cost while sculpting a meadow (a full instance rebuild per stroke), were not measured.
- Only seed `meadow-lark-2081` was looked at rendered after the 2026-10-02 changes.
- The sunflowers' facing assumes the default sun ring yaw (`SUN_FACE`); a world whose light is turned another way would show them facing off the sun.

## With the flower kit

The kit (docs/scenic/flowers.md) is in `NativeTerrainData.ASSETS` and `NativeAssetCatalog.PARTS`, so `asset()` places its own keys and `form()` takes their size as it is. Kit flowers place untinted, except `tint_real` kinds (cosmos, lupine): their `tints` are the kit's own petal variants, one per drift, and GardenView draws such a tint as that variant (`MeadowFlowerMesh.instance_color`: a white instance colour whose alpha names the variant), so discs and stems keep their colours. `washes` gives the ground under each colour's drift (`wash_of`).

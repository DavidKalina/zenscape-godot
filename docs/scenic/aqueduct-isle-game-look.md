# Aqueduct isle: the game's look

Branch `look/aqueduct-isle-game-look` (from main 03a54e73). Not merged, not pushed.

The user's ask: the isle's grass looked flat, with no animated grass and no flowers, and its light looked flat beside the game's. They wanted the game's grass, flowers and light, and the look presets from edit mode, so the isle can be tried in each.

## Run

```sh
./run-aqueduct-isle.command                      # opens in Alpine morning
./run-aqueduct-isle.command --look=first_snow    # or any preset id
```

- **L** goes to the next look preset and **Shift+L** to the previous one. They come in the look editor's order (`SceneLookPresets.PRESETS`, all 18). The preset's name and description show at the top for about 2 s.
- **`--look=<id>`** (or **`--preset=<id>`**) starts in that preset. An unknown id warns and falls back to Alpine morning.
- **`--look=x,y,z`** (three numbers) is still the capture's look-at point, so `tools/aqueduct_isle_captures.sh` works unchanged.
- **`--no-flora`** leaves the grass and flowers out, to compare cost.
- **B** still sends a gust front, now through the game's air.
- The other keys are unchanged: R, F1, F2, F5 to F8, Esc.

## Why the grass was flat

The ground has the game's material (`reference_surface.gdshader`, `palette_role` 1, the plate palette in face colours), but that is only the painted ground. In the game, the swaying grass on islands is a separate instanced layer: the plate catalog's `grass_tuft` and the meadow flower meshes, placed as records by `GardenInstanceSamples.add_item` and drawn as multimeshes with the catalog's plant materials (`SkyIslets._plant_material`). The plant shader sways those meshes with the wind globals and parts them with the pilot's wake.

The isle never grew that layer:
- **Round 3.** It was ported on `park/aqueduct-isle-3-flora` but parked when the user put the grass on hold.
- **Round 4.** It kept `Art.growth` instead: faceted static tufts and prism flowers baked into one mesh, with no sway shader. Those were the flat grass.

## What changed

### 1. Grass and flowers (`studies/aqueduct_isle_flora.gd`, new)

- **Source.** This is round 3's parked port, re-fitted to round 4's hill. It uses the game's own path: catalog records go through `GardenInstanceSamples.add_item`, are drawn as catalog multimeshes, and use `SkyIslets._plant_material`.
- **Placement.**
  - A ray must land on an island's or islet's own ground body (`Body`), so nothing grows on stone, walls, stairs, kerbs, boulders or the station's boxes. Four probes 0.25 m round the root must also land on that ground.
  - The face must not be steeper than 0.85 × the palette's rock slope, so crag faces stay bare. Grass does grow on the tiers, ledges and slopes.
  - The worn paths' middles stay bare (wear above 0.5), and grass thins toward their edges. Grass also keeps 0.5 m in from the rims.
- **Grass.** Tufts of 0.85 to 1.45× size grow in noise drifts, at up to 4.6 tries per m² and at least 35 % between drifts. That gives **8,592 tufts**.
- **Flowers.** They follow the game's `alpine` meadow type (`MeadowTypes`), using its drifts, its kind per drift with a companion, its colour variants and sizes. Only 16 % of the type's packing is kept, plus rare strays, so they read as wildflowers in the grass, not a carpet. That gives **481 flowers**: buttercup, lupine, oxeye daisy and dandelion. They use the kit's own flower meshes.
- **Tiles.** The plants are drawn in 16 m tiles (131 multimeshes), so each tile is culled on its own. Grass fades out from 95 m and flowers from 65 m, each over a 15 m margin. The plants cast no shadows.
- **Motion.** The pilot's wake (`scripts/pilot_wake.gd`) hangs on the figure, as on the game's walker. The plants sway with the game's air (below).
- **Removed.** The static `Art.growth` tufts and flowers are gone from the isle. The stumps' little tufts and the kit's own moss and ivy stay. `Art.growth` itself is still in the art file, unused.

### 2. Light, sky, air and weather (`studies/aqueduct_isle.gd`)

The study now builds the game scene's look rig in the order `studies/fidelity.gd` builds it:

- **Lighting and sky.** `LandscapeLighting` and `Celestial` on a still clock. A change to the scene look sets the exposure as the game's `_update_scene_look` does.
- **Air.** `studies/atmosphere.gd` gives the wind, the breathing breeze, the gust fronts, mist and haze. It has no valley fog volume, because that fog is the plate's.
- **Weather.** `studies/precipitation.gd` gives the weather, the cloud cover and the surface weather (autumn, cold, snow cover, wet).
- **Rendered only.**
  - `studies/display_fog.gd`: the game's screen-space air (aerial perspective, surface haze, grade and light shafts). Its valley march is off (`air_steps` 0), because it only covers a box round the plate at the world's middle.
  - The look pass and the 1080p cap.
- **Old setup replaced.** These replace the study's frozen-noon `GAME_LOOK`, its paused celestial and its own gust-front loop. Each frame runs the game's order: weather, air (gust fronts bounded round the camera as before), sky, screen air, look pass.
- **Headless too.** The rig runs headless as well, minus the look pass and screen air, so presets can be tested.

### 3. The presets

- **How they apply.** `apply_look(id)` calls the game's own `SceneLookPresets.apply(self, id)`, as the look editor's preset buttons do. That sets the scene look's colours (grass, foliage, rock, earth, water, sky), the weather, the hour, the wind, mist, haze and rays, the cloud cover and the surface weather.
- **Following the preset.** Grass, flowers and ground follow the palette and the seasons as in the game. First snow lays snow on the turf and grass, and night presets put the sun down.
- **Ruin stone.** Its material is unchanged (eroded basalt). It reads differently per preset only through the light.

## Checks (headless)

- **Import check.** Clean.
- **`tests/test_aqueduct_isle.gd`.** PASS, 40 checks, unchanged. The routes, replays and stair checks all hold, because the plants have no collision.
- **`tests/test_ruin_kit.gd`.** PASS.
- **`tests/test_aqueduct_isle_look.gd` (new).** PASS, 19 checks:
  - tuft and flower counts, the triangle budget, catalog multimeshes with the plant shader and range fade, tiling;
  - no plant on a path middle, a crag face or anything standing;
  - the wake;
  - all 18 presets apply and read back (`SceneLookPresets.matches`);
  - First snow's snow cover and Nordic night's sun;
  - L and Shift+L order, an unknown id, the name toast.
- **Not run.** The full suite, per instructions. Nothing was added to `tests/known_failures.txt`.

## Cost

| | Before | After |
|---|---|---|
| Static triangles (`triangles(art)`) | ~435k | **304k** (static tufts and flowers gone) |
| Instanced plant triangles (all) | — | **813k** (8,592 tufts × 80 tris; flowers 184–272 tris) |
| Multimeshes | — | 131 (16 m tiles) |
| Grow time | — | ~0.3–0.6 s after the pilot is ready |

**Measured on this Mac, rendered at 1440×900 with vsync off, on-foot ledge view.**

| | With plants | `--no-flora` |
|---|---|---|
| Frame time | 17.7 ms | 16.7 ms |
| Draw calls | 169 | 88 |
| Primitives drawn | 1.27M | 0.65M |

The no-plants figure looks pinned at 60 Hz, so the plants' true cost is about 1 ms or less. That is fine for an RTX 3070. Cutting `TUFTS` or `GRASS_RANGE` in the flora file trims it.

The `--capture` run now prints the frame time, draw calls and primitives. Metal reports no GPU timer, so this is wall-clock time.

## Captures

These are in `captures/aqueduct-look/r1/` in this worktree (git-ignored). Re-take them with `zsh tools/aqueduct_look_captures.sh DIR [preset ...]` (new).

- `southwest-<preset>.png` and `onfoot-<preset>.png` for `alpine_morning`, `rosewater_dusk`, `first_snow` and `nordic_night`.
- `onfoot-alpine.png` is the first, sparser grass pass (2.4/m²). `onfoot-alpine-2.png` is the final density.

## Open issues

- **No falling rain, snow or leaves.** The game's particles live on the plate's ground map (±26 m round the world's middle). The surface weather (snow cover, wet, autumn) works, but nothing falls on the isle. Falling leaves are hidden. Particles that follow the camera would fix this.
- **No valley mist.** The ground mist that pools in hollows is the plate's march, so it is off here. Misty presets (Enchanted forest, Halloween hollow) read through haze only, so they are lighter than in the game.
- **Crags read near black in daylight against the light.** This shows in Alpine morning's south-west view (round 4's note was the opposite: too pale). That is the game's lighting on `CRAG_SHADE` rock. Lifting `CRAG_SHADE` or adding bounce would help.
- **Rosewater dusk warms all the stone** toward sandstone, from low sun on the eroded basalt. The material is unchanged, but the stone reads less basalt in that preset.
- **First snow's sky is heavy grey** (its 0.59 cloud), as in the game.
- **No undergrowth.** The parked branch's ferns, shrubs and mushrooms at the ruins' feet were not brought over. They would be easy to add to the flora file.
- **Flowers are hard to see from the high on-foot camera.** That fits the "not a carpet" brief. Raise `FLOWER_SHARE` for more.

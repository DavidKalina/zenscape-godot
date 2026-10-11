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

## Flying the plane on the isle

Branch `study/aqueduct-isle-plane`: this look branch plus `feature/knife-drift` (knife edge + turn = drift, docs/design/knife-drift.md). Not merged, not pushed.

### Run

```sh
./run-aqueduct-isle.command              # on foot; press F to fly
./run-aqueduct-isle.command --fly        # start in the plane
./run-aqueduct-isle.command --fly --drift=1.5 --look=rosewater_dusk
```

### The switch: F (pad Y)

**Replaced (2026-10-10):** the kit isles now land by hand under the game's
rules, with a parked plane you walk back to. See docs/design/manual-landing.md,
"Kit isles". What follows is the old switch, for reference.

- **On foot, F** puts you in the game's plane (`scripts/sky_plane.gd`, `scripts/plane_figure.gd`, the chase camera `scripts/glide_camera.gd`). It is already flying at cruise, 5 m ahead of the pilot along the view and 3 m up (raised in 2 m steps if that is in stone). No runway.
- **In the plane, F** puts you back on foot. You land on the nearest open turf within 40 m of the plane (rings round it, nearest first; walkable faces only, with room to stand), facing the way you flew. If none is found, you go back to where you last stood.
- **Setting down:** skim the turf (or a stone top) with Shift (Brake) held under 9.5 m/s for 0.5 s, and the pilot steps out there.
- **R** in the plane puts you on foot at the start, as before.
- F and pad Y were free on foot. In the game, F/Y is also the plane's land key.

### Plane controls (the game's)

A D bank and turn. W S pitch (W nose down). The mouse steers. Space boosts and Shift brakes. Hold Q E (LB RB) for the knife edge, and add A D to drift. Tap Q Q or E E quickly, or click, for a barrel roll. Hold the right mouse button, or push the right stick, to look round, and R3 resets the camera. Esc frees the mouse. A hint at the bottom shows these, with the speed and the bump count. On foot it shows `F (pad Y) fly the plane from here · R3 camera back behind`.

### The camera: right stick and R3

- **The right stick looks round in both modes.** On foot it orbits the pilot camera (the character study's, unchanged). In the plane it swings the chase camera round the plane, as the game's does: 2.4 rad/s at full push, and when you let go the view holds 2.5 s, then eases back behind (the game's STICK_LOOK and PLANE_LINGER). The right mouse button held does the same with the mouse.
- **Why it did nothing in the plane:** the study read the pad's look actions only on foot. Its fly input never read them and never called the chase camera's `turn`, so the free look stayed at zero. Holding the right mouse button only froze it. On foot the stick already worked (checked headless).
- **R3 resets the camera** (the `camera_reset` action in `scripts/pad.gd`). On foot it puts the camera behind the pilot at the default pitch, and the distance springs back by itself. In the plane it lets go of the free look, so the camera swings straight back behind. In the game R3 is Overview when building and the chase/first-person toggle when flying. Neither is wired here, and this study has no first-person view, so R3 takes nothing away. The game itself is unchanged.

### Key clashes checked

- L / Shift+L (presets) and B (gust) work in both modes.
- Shift+L in the plane also brakes for that moment, which is harmless.
- T, F1, F2 and F5 to F8 are on-foot keys and do nothing in the plane. Esc frees the mouse in both modes.
- No X eject, C camera or V step-out here. Those belong to the game's wanderer.

### Collision

The game's plane skims its heightfield and bumps off the ruins' layer (`scripts/ruin_bump.gd`). Here:

- **Turf (islands' and islets' ground bodies):** these bodies also sit on layer 12 (`TURF_LAYER`, 1 << 11). The plane's ground callable rays down onto them, so the plane skims the turf the way the game's plane skims ground: 0.9 m over it, with drag and the nose eased level. The flora and the pilot are unaffected.
- **Everything else that stands, plus the turf's sides and keels:** this includes the kit's stone hulls, the station's invisible boxes, walls, arches, the aqueduct, the circle, floating stones and stumps. The plane uses the ruin kit gallery's bump and recover: a wing-wide box turned with its bank and roll, so a knife edge slips through gaps level wings won't. On contact it is put back out along the face, its heading turned along it and its pitch eased, and it keeps 55 % of its speed. It never crashes. If the plane's turn would put a wing back into the face, it is pushed out along the face.
- **Upward faces** (normal y > 0.6: the rubble, stairs, ramps, wall and channel tops) are ridden over, lifted clear by up to 1.2 m, rather than bumped.
- Below the isle, the game's cloud cushion lifts the plane from 50 m under the turf. The sky ceiling is the game's (95 m).
- **No collision:** grass and flowers (as in the game), the aqueduct's water, and the ivy and moss. Thin pieces with no collider are flown through.
- The chase camera is kept out of solids by a point test. Inside concave turf meshes that test does not detect solid, so the camera can dip into an island's side in a tight pass.

### Checks (headless)

- Import check: clean.
- test_aqueduct_isle: PASS.
- test_aqueduct_isle_look: PASS.
- test_knife_drift: PASS.
- test_sky_plane: PASS.
- **`tests/test_aqueduct_isle_plane.gd` (new): PASS, 31 checks.**
  - Boarding: you board ahead of and above the pilot at cruise, the plane has the drift (strength 1), and the drift tightens with its nose slip and gives the release boost.
  - Collision: flown into the hill walls, the plane bumps and flies on and is never left in stone. Nosed down, it skims the turf and never goes into it.
  - Camera: the right stick (actions pressed as the pad would) orbits the camera on foot and swings the chase camera round the plane. The look holds after you let go, then swings back. R3 resets it in both modes.
  - Back on foot: F puts the pilot on the turf by the plane, walking. Braking on the turf sets him down. R returns him to the start.
- One rendered capture (`--fly --capture`) showed the biplane, with the pilot in it, under the chase camera.
- **Not run:** the full suite.

### Open

- With `--fly` the plane takes the start's facing, which runs off the isle's edge. Turn back to reach the ruins.
- The pilot's grass wake does not follow the plane when it skims. The ruin growth is still stirred by the plane.
- The plane flies in still air: the game's jets and thermals are not here. The isle's wind, gusts and look still run while flying.

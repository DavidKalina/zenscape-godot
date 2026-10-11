# Consolidation audit: one game path

Audited 2026-10-10 on `main` at c53f5aff. This was a read-only audit: no code
changed. Line counts are `wc -l` of `.gd` files. "Static closure" means every
script reachable through `preload`, `load("res://…")`, `extends` and
`class_name` from a scene (worked out with a throwaway script). "Live nodes" means
the node scripts actually standing after 400 headless frames of each scene.

## Summary

**Recommendation: direction A.** Make the aqueduct and kit isle path the game, and
port the main game's sky features into it.

The reasons, in plain words:

- **The kit isles don't touch the terrain editor at all.** `kit_isle.gd`,
  `character_study.gd`, the five isles and `scripts/kit_isle/*` have zero
  runtime references to `_chunk_editor`, `wanderer_eye` or `SkyIslands`. The
  main game's flight and on-foot code is built on the editable plate: 364
  `_chunk_editor` references across 67 files. In `wanderer_eye.gd` alone there
  are 64 `editor.` uses and 72 `islands.` uses.
- **Most of what you want to keep is already shared code.** The cloud sea
  (`look_pass.gd` → `sky_sea.gd` + `cloud_volume.gd`), the CPU biplanes
  (`sky_traffic.gd`), the night styles (`look_pass.gd`), and the islets,
  clusters, airships and collectibles already run in the aqueduct. What's
  missing is mostly how they're wired: the cumulus towers, cloud tearing and
  drifting clouds are created inside `SkyIslands`, and the clock, seasons and
  weather drift live in `studies/fidelity.gd`. Moving those into the kit sky is
  medium work. Each piece is a self-contained node or RefCounted.
- **Direction B can't hide the builder.** In the main scene the plate is the
  world's anchor. The pilot is parented to `editor.terrain`
  (`wanderer_eye.gd:633`). `SkyIslands` takes its palette and flora from the
  editor (`sky_islands.gd:200,230-231`). The look pass reads the editor for
  ridges and the near sea (`look_pass.gd:211,256`). So B would also mean
  re-teaching `wanderer_eye`'s on-foot, flight and landing code to stand on
  physics ground instead of the heightfield. That is the riskiest file in the
  repo.

**What the user's guesses got right and wrong:**

- **CPU traffic:** right. Four piloted biplanes fly in the aqueduct sky
  (`studies/aqueduct_isle_sky.gd:372-402`, `IsleTraffic extends SkyTraffic`).
  They don't fly through clouds there, because the cloud hooks aren't wired.
- **The cumulus sea:** partly right. The aqueduct has the cloud sea under the
  isles, but only in rendered runs: the near sea's heaps are drawn in the
  volumetric cloud volume, over the dome's painted sea. It has **no towering
  cumulus** (cumulus life), **no drifting clouds** and **no cloud tearing**.
  `look_pass.gd:264-271` hands the cloud volume `wanderer.islands`, and the kit
  scene has no `wanderer`, so the volume gets no towers and no wakes
  (`cloud_volume.gd:144-145`).
- **Sky seasons and weather:** not in the kit. Its clock is stopped
  (`kit_isle.gd:399`, `_celestial.cycling = false`), so there's no day and
  night. Each look preset pins one hour and one weather. Nothing publishes
  `zs_sky_season`, and rain and snow never fall, because precipitation is set
  up with no ground (`kit_isle.gd:409-418`). There's no lightning either.

**One thing to decide now.** The hand-landing port that's in flight
(`feature/kit-isle-hand-landing`, 124e1547) adds the **skydive canopy** to the
kit when you walk off an isle. It preloads `sky_dive.gd`, `canopy_figure.gd`
and `dive_camera.gd`. Skydiving is on your drop list, so either accept the
canopy as the "fell off the edge" safety net or ask for a plain respawn instead.

**Streaming, in plain words.** The main game builds the islands around you while
you fly: up to 9 baked "chunk" copies of fresh plains (`sky_islands.gd` CAP),
new ones conjured ahead when you wander or fall (`sky_cells.gd`), and cumulus
towers built within range and dropped behind you (`sky_towers.gd`
BUILD/FORGET). Each is made on a worker thread and placed into the scene one
piece per frame within a 4 ms budget (`sky_commits.gd`). There's also a disk
cache for mountain skylines (`sky_cache.gd`) and a loading veil
(`sky_reveal.gd`). The aqueduct already uses the worker and budget part for its
17 far isles, 6 clusters and pierced isle. But nothing streams *out*: the
whole set stays for the session (`docs/scenic/aqueduct-isle-sky.md:73-75`).
One kit isle on its own doesn't need more. A world of several *kit* isles
would, because one isle costs about 7 s from launch to walking headless (300k
triangles of art, flora grown in 539 ms, life in 432 ms, on the main thread).
A one-isle default can ship without streaming. A multi-isle world needs a
round of its own.

## 1. The front door

### What it depends on today

| Piece | Where | What it assumes |
|---|---|---|
| Project main scene | `project.godot:14` `run/main_scene="res://studies/cozy_worlds.tscn"` | the main game |
| Title screen | `scripts/title_screen.gd` (273 lines, a standalone `Control` with `add_action`, `present`) | nothing scene-specific; but it is created and wired by `studies/diorama.gd:335` and `studies/cozy_worlds.gd` (`_retitle_menu`, `_run_title` :282) |
| Title background | `scripts/title_showcase.gd`, `cozy_worlds.gd:280-310` | forms a generated heightfield world and orbits it |
| Loading veil | `scripts/title_loading.gd` (73 lines, standalone) | created by `diorama.gd:39` and `cozy_worlds.gd:132,139,198,262,283,745` |
| Whether the title shows | `cozy_worlds.gd:273-278` `_title_wanted`: off with `--no-title`, `--resume`, `--generated`, `--seed`, `--atlas`, `--verify-desktop-build` | |
| Scene picker | `scripts/scene_catalog.gd` (113), `scripts/scene_picker.gd` (261); opened only from the title's quiet "Scenes" (`cozy_worlds.gd:329-349`) | 5 of its 30 entries open `cozy_worlds.tscn` (game_world, moments_world, manual_landing_world, sundered_hall, and the title itself) |
| Way back | `scripts/scene_return.gd:18` returns to `application/run/main_scene` | follows the main scene automatically |
| Launch flags | `scripts/launch_args.gd:51` adds `--no-title` to picked scenes | |
| Export entry test | `tests/test_export_entry.gd:9-13` fails unless the main scene **is** `cozy_worlds.tscn`, then sets `places_path` and runs the check | |
| Packaged self-check | `scripts/desktop_build_check.gd` (241), triggered by `--verify-desktop-build` in `diorama.gd:102-103` | native kernel and mesh equivalence (scene-independent); then waits for `shell_ready`, checks `hand_only`/creation shell, photo mode, main menu, audio teardown |
| CI | `.github/workflows/desktop.yml`: import, `test_threaded_mesh`, `test_export_entry`, export, `tools/verify_desktop_export.py` | `verify_desktop_export.py:45-48` requires the markers `PASS: packaged photo mode` and `PASS: packaged hand scheme, photo and main menu` |
| Export presets | `export_presets.cfg` (`all_resources`, includes `assets/**/*.json`, `studies/character_runs/*.json`) | nothing to change; kit scenes already ship |
| Settings | `diorama.gd:345-400`: quality tier, cloud style, night style, planet; `scripts/sound_settings.gd` | only in the main game; the kit reads the saved choices from `user://look.cfg` but has no UI |
| Pause / quit | `scripts/pause_panel.gd` (446, world-copy rows) | main only; in the kit, Esc just frees the mouse |

### What pointing them at the aqueduct needs (one round, M)

1. A game scene for the front door, say `studies/zenscape.tscn`. It hosts the
   aqueduct (or extends `aqueduct_isle.gd`) with a "titled" mode: the camera
   orbits the isle, `title_screen.gd` sits on top with Play, Scenes, Settings
   and Quit, and `title_loading.gd` covers the build until `ready_to_walk`
   (`kit_isle.gd:313`). Both Controls are reusable as they stand.
2. `project.godot` main scene → the new scene. `scene_return.gd` follows by
   itself.
3. A catalog entry "Builder (old game)" → `cozy_worlds.tscn` with `--resume`,
   so the builder and saves stay reachable from Scenes. The five
   `cozy_worlds` entries keep working; they just aren't the default any more.
4. `test_export_entry.gd`: expect the new main scene. `desktop_build_check.gd`:
   keep the kernel and mesh part, and replace the shell, photo and hand checks
   with kit checks: walking reached, title present, the plane boards and
   flies, clean teardown. Update the marker strings in
   `verify_desktop_export.py:45-48` to match. The native kernel stays needed:
   the kit's flora and islets still read `NativeTerrainData`
   (`meadow_types.gd:250,405`).
5. A pause panel for the kit: Resume, Settings (quality, clouds, night,
   planet, sound), Return to title and Quit, reusing `pause_panel.gd` without
   its world-copy well. Gate the study's dev keys out of release builds:
   F1 numbers, F2 feel, the recorder, B gust, R reset (`kit_isle.gd:33-40`).
   This can be its own small round if round 1 gets big.

## 2. The keep list, feature by feature

Kit status: **full**, **partly**, or **no**. Sizes: S is under a day of agent
work, M is one round, L is more than one round.

### Cumulus cloud sea, cumulus life and the volumetric clouds

| | |
|---|---|
| Lives now | Near sea `scripts/sky_sea.gd` (237), cloud volume `scripts/cloud_volume.gd` + `cloud_volume_effect.gd` (695), both made by `scripts/look_pass.gd:59-65`. Towers `scripts/sky_towers.gd` + `sky_tower.gd` (713) and drifting clouds `sky_clouds.gd` + `sky_cloud.gd` (1,075), made inside `SkyIslands.setup` (`sky_islands.gd:227,239`) |
| Kit has it | **Partly.** The sea and the volume come through LookPass (`kit_isle.gd:419-421`), **rendered only**: headless skips LookPass, so headless tests can't see it. No towers and no drifting clouds: `look_pass.gd:266` reads `_scene.get("wanderer")`, null in the kit |
| Port to kit (A) | **M.** Add `SkyTowers` and `SkyClouds` to `aqueduct_isle_sky.gd`. Towers need a `cells` with `origin` (the kit already makes a `SkyCells` for its tokens, `aqueduct_isle_sky.gd:607`). Their placement is static (`SkyTowers.spot`, `sky_towers.gd:334-346`) and reads `SkyWorld.ring_on()`/`layout()`, which would run the peak ring's layout. Give it a hand-placed spot list for the kit. `SkyClouds.build(slots)` is portable but calls `SkyPeaks.blocks`/`SkyTowers.blocks` (`sky_clouds.gd:73`). Add a host hook in `look_pass.gd:256-271`: ask the scene for `sky_towers`/`sky_wakes` rather than `wanderer.islands` |
| Direction B | Already there |

### CPU plane traffic

| | |
|---|---|
| Lives now | `scripts/sky_traffic.gd` (355), 4 piloted biplanes (`COUNT`, :27) |
| Kit has it | **Full**, apart from clouds: `aqueduct_isle_sky.gd:372-402` (`IsleTraffic` laps the clusters and buzzes the near isles, `--no-traffic`). Probe: 4 `plane_pilot.gd` nodes live. `cloud_near`/`cloud_depth` aren't set (`sky_traffic.gd:108-112`), so they never fly through a cloud |
| Port to kit (A) | **S**, after the clouds: set `cloud_near`/`cloud_depth` as `sky_islands.gd:220-221` does |
| Direction B | Already there |

### Cloud tearing

| | |
|---|---|
| Lives now | `scripts/cloud_wakes.gd` (246). Fed by `SkyIslands.wake` (the eye's plane) and `_tear` (traffic → wakes → puffs and towers), `sky_islands.gd:1248-1274`; the cloud volume reads `wakes.near_box` for the sea (`cloud_volume.gd:301-304`) |
| Kit has it | **No** |
| Port to kit (A) | **S–M**, with the clouds round: a `CloudWakes` node in the kit sky, a `trace` per frame from `kit_isle.fly_step` (`kit_isle.gd:929`) and one per traffic plane, then hand the wakes to the volume through the same host hook. `tests/test_cloud_wakes.gd` is already scene-free |
| Direction B | Already there |

### Sky seasons and sky weather

| | |
|---|---|
| Lives now | Clock: `scripts/world_clock.gd` (277), attached in `fidelity.gd:200-201`. Weather drift: `scripts/weather_scheduler.gd` (423) + `scripts/living_weather.gd` (253), driven by `fidelity.gd:635-647`. Seasons: `fidelity.gd:666-689` `_apply_season` publishes `zs_season` and `zs_sky_season` (the sea's grade, `shaders/sky_season.gdshaderinc`; the peaks' snowline goes with the ring). Lightning: `studies/lightning.gd` (173, `fidelity.gd:228-230`), whose flash the cloud volume shows (`cloud_volume.gd:91,323`). Rain and snow: `studies/precipitation.gd` over the plate's ground map |
| Kit has it | **No.** Still clock (`kit_isle.gd:399`). Weather is fixed per look preset (`scene_look_presets.gd:71-91` sets `cycling:false`, the phase and the weather). No `zs_sky_season` publisher. No lightning node (`_lightning` absent, so `cloud_volume.lightning` is null). Precipitation has `NoGround` (`kit_isle.gd:415,437-438`), so no particles |
| Port to kit (A) | **M–L**, one round. (1) Move `_apply_season` and the drift step out of `fidelity.gd` into a small reusable node (about 120 lines) used by both scenes. (2) Attach a `WorldClock`, set `cycling = true`, and make the look presets **overrides** of the live sky, not the default. (3) `living_weather.gd:20-21` preloads `cozy_world_generator.gd` and `desert_landscape.gd` for its odds: lift those tables into constants. (4) Lightning wants a `height_at` ground clamped to the plate (`lightning.gd:50`): give it a ray-down adaptor round the isle. (5) Rain and snow round the eye without the plate's map is the biggest unknown here (M by itself; it's GPU-only, so a headless run can't verify it) |
| Direction B | Already there |

### Night styles

| | |
|---|---|
| Lives now | `look_pass.gd:36-42` (four styles, kept in `user://look.cfg`), `shaders/night_sky.gdshaderinc` |
| Kit has it | **Partly.** LookPass publishes the style in rendered runs, and a style picked in the main game carries over. But night only shows on the night presets (`nordic_night`, `moonlit_stillness`, `halloween_hollow`), because the clock is still, and there's no settings UI to choose a style |
| Port to kit (A) | **S** once the clock and the settings exist (rounds 1 and 4) |
| Direction B | Already there |

### Already in the kit, absent or partial in the main scene

| Feature | Kit | Main scene | Direction B would need |
|---|---|---|---|
| Isle lock and card | full: `scripts/isle_lock.gd` (123), `isle_splash.gd` (307), `kit_isle.gd:840-910` | no | port the lock and framing into `wanderer_eye` flight, plus an isle registry (M) |
| Lodestone and hall chain | full on the aqueduct: `lodestone.gd`, `studies/aqueduct_isle_chain.gd` (410), hall_* scripts (about 2,600); lodestone only on the motif isles | Sundered hall motif only (`--motif=sundered`) | M: the chain is anchored to `SkySea` constants and the isle's own frame |
| Collectibles | full: hand-laid lines in `aqueduct_isle_sky.gd:605-623` + `kit_tokens.gd` | full (seeded) | already there; the kit's hand lines would need placing |
| Rope bridges | full: `rope_bridge.gd`, `rope_bridge_sim.gd`, `kit_isle/deck_ground.gd` | cluster bridges + footbridge decks | physics decks under the heightfield walker (M) |
| Kit flora and life | full: `kit_flora.gd`, `kit_life.gd`, `kit_birds.gd` (about 1,400) over a ray `Site` | plate flora and habitat | portable (S), but needs the isle's turf bodies |
| Look presets (L) | full: `kit_isle.gd:445-457` | via the scene look editor and moods | already there |
| Far isles, clusters, airships, serpent | full: `aqueduct_isle_sky.gd` | seeded equivalents; no serpent | serpent S, rest there |
| Hand landing | **coming** (`feature/kit-isle-hand-landing` 124e1547: +846 lines in `kit_isle.gd`, `tests/test_kit_isle_landing.gd`) | default (a793e8a9) | — |

### Drops in the kit (tidy-ups for direction A)

- **Sky folk:** `sky_folk.gd` isn't in the kit, but its figure is. The probe
  found 11 `islander_figure.gd` nodes: the clusters' folk
  (`cluster_dresser.gd:402`) and the airship crews (`sky_airship.gd:998`).
  Dropping the folk means a dresser flag. The crews are your call. S.
- **The peak ring:** not built in the kit, but 13 kit-reachable scripts call
  `SkyWorld` statics (`look_pass.gd:225,276`, `sky_clusters`, `sky_pierced`,
  `sky_towers`, `sky_cells`, `sky_collectibles`, …). `SkyWorld.ring` defaults
  to `true` (`sky_world.gd:115`). Before deleting `sky_world.gd`, set the ring
  off for the kit and cut those calls. S–M.
- **Claiming, the lower world, the glider:** not in the kit. Nothing to do.
- **Skydiving:** not in the kit today, but it arrives with the hand-landing
  port (the canopy on walking off an isle). See the summary.

## 3. What direction B would take

The task: the main scene hosts hand-built isles with physics ground, the kit
look, and the kit's on-foot and plane feel.

**The ground model is the core problem.** Both paths share one character
controller, `scripts/pilot_motor.gd` (1,548 lines), but they answer its
ground questions differently:

- **Kit:** `scripts/pilot_physics_ground.gd` (210) answers ground, slide,
  ledge and water from physics raycasts (`character_study.gd:701-703,771`).
- **Main:** `wanderer_eye.gd` answers from the heightfield.
  - `_ground` → `editor.data.ground_height` (:676-682)
  - `_clamped` → `editor.data.nearest_land` and the plate reach (:687-699)
  - `_motor_ground` → `SolidProps` tops plus the heightfield (:1114-1119)
  - footbridge decks from `Footbridge.decks(editor.data)` (:684-685)
  - islet "perch" mode on `shape.ground_at`: 121 `perch` references
  - flight solids from `islands.body`/`_height` and the plate's crown list
    (:1610-1633)

  The figure itself is a child of `editor.terrain` and lives in plate-local
  coordinates (:629-650).

**Work B needs, roughly:**

| Step | Coupling | Size |
|---|---|---|
| Split each kit isle into an "isle" node (art, turf, flora site, lodestone, tokens) apart from the study scene, which owns the camera, pilot and look rig. The art builders are already static (`aqueduct_isle_art.gd` has no `study.` references), but `kit_isle.gd`/`aqueduct_isle.gd` mix the isle and the player | none to main | M–L (A needs this too, but only for a multi-isle world) |
| A new sky kind in `SkyIslands` for kit isles (placed, collided, kept out of the cells and towers keep-outs). `SkyIslands.setup` needs `scene._chunk_editor` (:200) | heightfield, editor | M |
| A physics-ground mode in `wanderer_eye` for on-foot on kit isles, next to plate mode and perch mode: a third ground model in a 3,123-line file; the figure re-parented off `editor.terrain` | wanderer_eye, heightfield | L |
| Flight: the kit's shape-query bump, turf skim and set-down (`kit_isle.gd:1001-1090`) merged into `_advance_flight`/`_solid`/`_fly_ground` (:1473-1633); hand landing over physics instead of the heightfield strip | wanderer_eye | L |
| Lock, card, lodestone and hall chain driven by `wanderer_eye` and the main camera rig | wanderer_eye, cozy_worlds | M |
| Hiding the builder: the plate can't simply go. The look pass (`look_pass.gd:211-214,255-256`), `sky_haze.gd:155`, `SkyIslands` palettes, the camera rig, photo and watch mode all read it. The main scene would boot the plate, editor and habitat in the background: 151 live node scripts against the kit's 50 | heightfield, editor, cozy_worlds | L |
| Then delete or flag off claim, ring, lower world, folk, skydive and glider inside `wanderer_eye` and `sky_islands`: 129 dive/canopy, 42 glider, 26 lower and 20 claim references in `wanderer_eye.gd` alone | wanderer_eye | M–L |

**B totals roughly four L rounds**, nearly all inside `wanderer_eye.gd`,
`sky_islands.gd` and the `fidelity`/`diorama`/`cozy_worlds` chain (3,397
lines). Those are the files the kit path never needs. **A totals about two M
rounds plus one M–L round** to reach parity on the keep list, and it touches
mostly code the kit already runs.

## 4. The codebase in three parts

Context: `scripts/` + `studies/` hold 538 `.gd` files, 197,754 lines. Tests
hold 291 files, 44,524 lines.

**Static closures:**

- **Kit scenes (all five):** 549 files, 140,902 lines.
- **`cozy_worlds.tscn`:** 722 files, 192,875 lines.
- **Overlap:** every kit-reachable file is also main-reachable. Only 139
  `.gd` files (51,970 lines) are reachable from the main scene alone.

**Why the kit closure is so big:** constant references. For example
`sky_sea.gd` → `sky_islands.gd`, `kit_flora.gd` → `meadow_types.gd` →
`inland_world.gd`, `look_pass.gd` → `sky_world.gd`, and seven scripts
(`songbirds`, `genesis_canvas`, `land_life`, …) → `native_chunk_editor.gd`.
Cutting those four hubs only drops the kit closure to 491 files and 127,487
lines.

**What actually runs:** 50 node scripts are live in the aqueduct, against 151
in the main game. **So deleting needs untangling first.** Delete a "main-only"
hub file outright and the kit stops parsing.

### A. Shared, needed by the kit path (must survive)

| Group | Files | Lines |
|---|---|---|
| Kit path itself | `studies/kit_isle.gd`, `character_study.gd`, `studies/*_isle*.gd`, `scripts/kit_isle/*` | 14,396 (+846 with hand landing) |
| Pilot | `pilot_*.gd`, `wanderer_steps.gd`, `pad.gd`, `character_recording.gd` | 4,513 |
| Plane | `sky_plane`, `plane_figure`, `plane_pilot`, `glide_camera`, `glide_air`, `stone_plane_figure`, `nose_compass`, `manual_landing`, `plane_landing`, `plane_strip`, `wheel_spray` | 4,693 |
| Look rig | `landscape_lighting`, `studies/celestial`, `atmosphere`, `precipitation`, `display_fog`, `surface_weather`, `lightning`; `look_pass`, `scene_look`, `scene_look_presets`, `render_resolution`, `sky_objects` | 2,461 |
| Clouds | `sky_sea`, `cloud_volume*`, `sky_towers`, `sky_tower`, `cloud_wakes`, `sky_clouds`, `sky_cloud`, `cumulus_noise`, `sky_motes` | 3,107 |
| Time and weather (to port) | `world_clock`, `weather_scheduler`, `living_weather`, `studies/lightning` | 1,126 |
| Sky content | `sky_islets`, `sky_islet`, `sky_clusters`, `cluster_*`, `sky_pierced`, `pierced_*`, `sky_airship`, `airship_*`, `sky_traffic`, `sky_ambient_life`, `sky_commits`, `far_trees`, `rock_looks`, `cabin`, `islander_figure`, `person_kit`, `rune_serpent`, `sky_cells`, `sky_currents`, `islet_stream`, `islet_lake`, `sky_fall_thread` | 15,941 |
| Collectibles | `sky_collectibles`, `collectible_lines`, `collectibles_hud`, `glyph_*`, `moments_hud` | 2,173 |
| Ruin kit and loop | `ruin_*`, `rope_bridge*`, `lodestone*`, `hall_*`, `isle_lock`, `isle_splash`, `sundered_*` | 13,307 |
| Flora and small life | `meadow_types`, `grass_tuft_mesh`, `meadow_flower_mesh`, `garden_instance_samples`, `undergrowth_mesh`, `life_butterflies`, `songbird_body`, `fireflies`, `falling_leaves`, `wind_*`, `breeze_ribbons`, `seeded_variety`, `facet_mesh` | 5,877 |
| Front door (moves to the kit) | `title_screen`, `title_loading`, `scene_picker`, `scene_catalog`, `scene_return`, `hud_linen`, `launch_args`, `pause_panel`, `sound_settings`, `desktop_build_check` | 1,812 |
| Shared only through constants (untangle before deleting) | `sky_islands`, `sky_world`, `native_chunk_editor`, `inland_world`, `genesis_canvas`, `cozy_world_generator`, `plate` | 8,030 |
| Native terrain data and kernel | `native_terrain_data.gd` (2,056) and `native/terrain_kernels` | stays: flora and islets read it, and CI checks the kernel |

Total about **75,000 lines** that the kit path needs or will need, before the
constant-only group.

### B. Main-game-only, can go once the keep features are ported

Each line can only go once its code no longer reaches the kit through constants
(see the last row of part A).

| Group | Files | Lines | Notes |
|---|---|---|---|
| Claiming | `sky_islands.gd` (claim, chunks, world shift) | 1,360 | hub: `sky_sea.gd` references it |
| Peak ring | `sky_world`, `sky_peaks`, `sky_peak`, `sky_ring`, `sky_cache`, `sky_reveal`, `mountain_spire` | 6,444 | 13 kit-reachable callers of `SkyWorld` statics |
| Wonders already off | `sky_pillar*`, `sky_tepui*`, `sky_forest_isle*` | 5,499 | |
| Lower world | `sky_below`, `sky_archipelago`, `islet_lod`, `sky_haze`, `landform_preview` | 1,568 | |
| Sky folk | `sky_folk`, `sky_homes` | 339 | `cluster_dresser` and `sky_airship` read `SkyFolk.SCARVES` |
| Skydive and glider | `sky_dive`, `canopy_figure`, `dive_camera`, `sky_glide`, `glider_figure`, `glide_vapour` | 1,791 | **the first three come back with the hand-landing port** |
| Main pilot and flight glue | `wanderer_eye.gd` | 3,123 | `sky_flight.gd` (184) too |
| Habitat, audio, photo, watch | `fidelity_habitat`, `ambient_audio`, `nature_audio`, `thunder_audio`, `photo_mode`, `watch_mode`, `camera_rig`, `pad_input`, … (the 139-file main-only closure, 51,970 lines, also covers these) | | the kit has no ambient soundscape and no photo mode: not on the keep list, but you'd notice the quiet |

### C. Main-game-only, hidden behind a flag (the builder and saves)

All of this keeps working as the "Builder (old game)" scene-picker entry:

| Group | Lines |
|---|---|
| Main scene chain: `studies/fidelity.gd`, `fidelity_life.gd`, `diorama.gd`, `cozy_worlds.gd` | 3,397 |
| Editor and terrain: the `native_*` scripts (47 files) | 13,584 |
| Tools, hand and shell: brushes, landforms, `hand_*`, `clay_tools/*`, `land_clay`, `lantern_*`, `creation_*`, `genesis_*`, `edge_spring`, `diorama_flip`, `tool_*`, `god_hand`, `materials_tray`, `command_palette`, `mountain_*`, `*_builds`, `terrain_*`, … | about 26,000 |
| Saves and worlds: `world_session`, `world_library`, `world_title`, `new_world_panel`, `cozy_regrowth`, `plate_migration`, `chunk_atlas*`, `landscape_favorites` | 3,722 |
| Inland generation: `inland_*`, `cozy_world_generator`, `plate*`, `island_*` | 2,497 |

Hiding the builder costs only the catalog entry. Removing it later is the
deferred "old-flag refactor".

### Tests and tools

- 25 tests reference `cozy_worlds`. 88 tests instantiate a main-chain scene
  (`cozy_worlds`, `diorama` or `fidelity`).
- 24 of those 88 cover keep features and need **re-homing** onto the kit host,
  not deleting: `test_cloud_volume`, `test_sky_sea`, `test_night_styles`,
  `test_sky_seasons`, `test_weather_drift`, `test_weather_profiles`,
  `test_rainbow_weather`, `test_shroud_weather`, `test_lightning`,
  `test_season_scene`, `test_cozy_atmosphere`, `test_scene_look_render`, and
  others.
- Scene-free tests that carry over as they are: `test_cloud_wakes`,
  `test_weather_scheduler`. `test_sky_cumulus` and `test_sky_traffic` build a
  `SkyIslands`.
- Tests that only exercise parts being deleted: `test_skydive`,
  `test_sky_glide`, `test_lower_world`, `test_sky_folk`, `test_sky_peaks`,
  `test_sky_peak_look`, `test_sky_summits`, `test_sky_world`,
  `test_sky_layout`, `test_sky_cache`, `test_sky_reveal`, `test_sky_swap`,
  `test_sky_painted_ridges`, `test_sky_sea_peaks`, `test_sky_pillars`,
  `test_sky_tepui`, `test_sky_forest_isles`, `test_sky_chunk_popin`,
  `test_tools_after_claim`, `test_sky_streaming_budget` (part).
- The builder tests (`test_native_*`, `test_hand_*`, `test_worlds_flow`, …)
  stay while the builder is hidden.
- The kit has 15 tests (`test_aqueduct_isle*`, the four motif isles,
  `test_isle_lock`, `test_isle_lodestone`, `test_isle_hall_chain`,
  `test_kit_water`, `test_rope_bridge`), plus `test_kit_isle_landing` coming.
- Tools: 158 files under `tools/` reference `cozy_worlds` (157 in `tools/`,
  1 in `tools/landscapes/`); 20 reference the kit isles. Most `cozy_worlds`
  tools are one-off probes and captures: leave them until the deletion round,
  then delete by grep.

## 5. Recommendation and rounds

**Go with A.** Each round below fits one fresh agent. The order is chosen so the
default is playable after round 1 and gains features with each round after.

| Round | What | Size | You lose in the default until it's done |
|---|---|---|---|
| 0 (running) | Hand landing in the kit (`feature/kit-isle-hand-landing`). **Merge it before round 1**: it adds 846 lines to `kit_isle.gd`, which every later round edits | — | — |
| 1 | Front door: new main scene with the title over the aqueduct, loading veil, Scenes with a "Builder (old game)" entry, `test_export_entry` + `desktop_build_check` + CI markers rewritten | M | the builder, Your worlds and saves leave the default (still in Scenes). Until round 2: no pause, no settings and no quit menu in the game. The title background becomes the aqueduct, not a generated world |
| 2 | Pause, settings (quality, clouds, night, planet, sound) and quit for the kit; dev keys gated out of release | S–M | — |
| 3 | Clouds: towers (cumulus life), drifting clouds, tearing, traffic through clouds, LookPass/CloudVolume host hook | M | until done: no towers and no tearing (those are GPU-only, so headless can't verify them: report them unverified and the user checks a rendered run) |
| 4 | Time and weather: live clock (day and night), seasons into the sky, weather drift, lightning in the cloud volume, look presets as overrides; rain and snow round the eye as a stretch | M–L | until done: no day/night cycle, no seasons, no drifting weather. Night styles show only on the night presets |
| 5 | Drop-list tidy in the kit: dresser folk off (crews: your call), `SkyWorld` ring off for the kit and its static calls cut, the canopy decision acted on | S | — |
| 6 (decide) | Several kit isles in one sky: split isle from study, place the five isles in one frame, build each on a worker within `SkyCommits`, drop far ones (this is "streaming" for the kit) | L | nothing; until then each isle is its own scene |
| 7 (later) | Deletion: untangle the constant hubs (`sky_sea`→`sky_islands`, `look_pass`→`sky_world`, `meadow_types`→`inland_world`, the seven → `native_chunk_editor`), then remove claim, ring, lower world, folk, glider (and skydive, if dropped) from the main path with their tests and tools. Keep the builder running behind its flag | M–L | inside the hidden builder: chunk claiming, the ring, `--below` and the glider |

### Risks

1. **`kit_isle.gd` becomes the new god file.** It's 1,473 lines now, about
   2,300 with hand landing, and rounds 1–4 add to it. Put new systems in their
   own scripts, as `scripts/kit_isle/*` already does: a sky-weather node, a
   cloud host and the title host. Don't grow the base class.
2. **Parallel edits.** Rounds 1–4 and the hand-landing branch all edit
   `kit_isle.gd` and `aqueduct_isle_sky.gd`. Run them one after another, not
   side by side.
3. **GPU-only checks.** The cloud sea, the volume, towers, tearing and night
   styles only exist in rendered kit runs: LookPass is built only when
   `DisplayServer` isn't headless (`kit_isle.gd:384,419`). Report those checks
   as unverified headless and ask for a rendered look.
4. **The static web.** `SkyWorld.ring` defaults to on. Code built for the main
   world (`SkyTowers.spot`, `SkyClouds.build`) calls `SkyWorld.layout()` and
   `SkyPeaks.blocks`. Ported naively, the peak ring's layout runs in the kit
   anyway.
5. **Look presets against the live sky.** Today a preset pins the hour and the
   weather. With a running clock, the presets need clear override semantics, or
   the drift fights them.
6. **The canopy.** The hand-landing port brings back the skydive pieces you
   want gone.
7. **Persistence.** The kit saves nothing: tokens and the lodestone reset every
   run. Fine while saves are hidden, but the default experience has no
   progress until saves come back.
8. **Startup.** About 7 s headless to walking. Fine for one isle behind a
   veil. Round 6 is where it matters.

### Why not B

B keeps the sky features where they are, but it has to drag hand-built,
physics-ground isles and their feel through `wanderer_eye.gd` (3,123 lines)
and the plate-anchored main scene. It also can't actually take the builder out
of the default, because the plate is what everything stands on. It's the same
amount of new behaviour, plus a third ground model in the most coupled file,
plus a 151-node boot behind a scene that should feel light.

## Round 1 done

Branch `consolidate/front-door`, off `main` 440a405d. Not merged, not pushed.

### What changed

- **The front door.** `studies/zenscape.tscn` is `run/main_scene` now. Its
  script, `studies/zenscape.gd` (about 60 lines), extends
  `aqueduct_isle.gd`, so every aqueduct flag works on it. The work lives in
  `scripts/kit_isle/front_door.gd`, the scene's first child, which processes
  after the scene each frame so it has the camera last. It runs in this order:
  1. The loading veil (`title_loading.gd`, "The isle is rising out of the
     clouds") goes up. The scene waits two frames so the veil draws, with
     process and input off, then builds.
  2. On the new `isle_ready` signal (the end of `kit_isle._ready`, with
     `isle_up`), the pilot stands where he'd land hopping out of the parked
     plane (`_hop_spot`), facing it.
  3. The original `title_screen.gd` comes up over the isle, unchanged: the
     wordmark, the tagline and the linen card. The card holds **Begin** ("On
     foot by your plane"), then **Scenes** and **Quit**, both quiet along its
     foot. The camera orbits the isle's art bounds at the old title's polar
     and speed (`diorama.gd _frame_title`).
  4. While the title is up, the scene is `scripted` (the pilot holds still
     and the mouse stays free), its own CanvasLayers are hidden, and
     `_unhandled_input` is blocked. The look, sky, life and traffic keep going.
  5. Begin fades the card, puts the HUD back, unscripts the pilot, captures
     the mouse, and eases the camera from the orbit to the walker's camera
     over 1.8 s.
- **When the title shows.** It shows when the scene is the current scene.
  These skip it: `--no-title`, `--fly`, `--near-ring`, `--place=`,
  `--capture=`, and the `no_title` meta. The `title` meta forces it, for
  tests. A start that skips the title still gets the veil when it's the
  current scene and not a capture. `run-aqueduct-isle.command` opens
  `aqueduct_isle.tscn` itself and hasn't changed.
- **Scenes.** `scene_catalog.gd` has a new first entry, **Builder (old
  game)**: `cozy_worlds.tscn` with `"own_title": true`.
  `launch_args.open_scene(tree, scene, args, own_title)` leaves `--no-title`
  out for an entry like that, so the old game opens on its own title, with
  Continue, Your worlds, Build this world, a quiet plain and every save.
  Holding Esc there (`scene_return.gd`) comes back to the front door.
  `title_scene` follows the main scene. The other 29 entries haven't changed.
- **Packaging and CI.** `test_export_entry.gd` expects
  `studies/zenscape.tscn`. It sets the `title` meta, because the scene isn't
  current in that test. `desktop_build_check.gd` keeps the kernel and mesh
  part, then branches on `scene.front_door`. The front door's walk is: the
  title over the isle, Begin in reach, the pilot held by the parked plane,
  the camera orbiting, Begin, by the plane, the plane boards and climbs 4 m,
  then the scene is freed and its audio released. The old cozy walk stays
  for `cozy_worlds`. `zenscape.gd` runs the check on
  `--verify-desktop-build`, through the title. The new markers
  (`verify_desktop_export.py`) are `PASS: packaged front door title over the
  isle` and `PASS: packaged walk, plane and teardown`. `export_presets.cfg`
  and `desktop.yml` didn't need changes.
- **New files and docs.** `tests/test_front_door.gd` is new, plus a check in
  `test_scene_picker.gd` that an `own_title` entry opens without
  `--no-title`. The new launcher is `run-zenscape.command`, which opens the
  main scene. The README's Play section and `docs/design/scene-picker.md`
  are updated.
- `kit_isle.gd` grew 8 lines: the signal, `isle_up` and the emit.

### Corrections to section 1

- Before this round, **4** of **29** catalog entries opened `cozy_worlds`,
  not 5 of 30. The title itself had no entry. Now it's 5 of 30.
- `cozy_worlds.gd`'s Scenes button sits before Settings. The front door has
  no Settings, so its Scenes sits before Quit.

### Tests (headless, `tools/run_tests.py --tests ...`)

All 14 pass: `test_front_door`, `test_export_entry`, `test_scene_picker`,
`test_scene_picker_entries`, `test_scene_picker_title`,
`test_title_resolution`, `test_title_showcase`, `test_world_title`, the five
`test_aqueduct_isle*` tests and `test_kit_isle_landing`. Seven of them are
`pass_with_known_engine_error` (`exit_leak`). `test_scene_picker_entries`
didn't crash at exit in this run. It still opens the builder entry with
`--no-title`, because it adds that flag to every entry, so the builder's own
title is covered only by `test_scene_picker_title`, which still drives the
old game's title.

### What's left, and gotchas

- **CI will see `ERROR:` lines (open).** At exit the aqueduct leaks 2 to 10
  DummyShader RIDs. The count changes from run to run and appears on `main`
  in any headless aqueduct run. `desktop.yml` greps `menu-test.log` for
  `ERROR:`, and `verify_desktop_export.py` fails on any `ERROR:`, so the
  leak line will likely turn the Windows job red now that the main scene is
  the isle. I haven't confirmed that on CI. Clearing the kit's obvious static
  material caches made no difference, and neither did `--no-life`,
  `--no-flora`, `--no-traffic` or `--no-chain`. The count varies, which
  points at timing (workers, or something freed after the RenderingServer).
  The old cozy check printed `ERROR: Resumed function '_bake_underside()'
  after await` (`diorama_flip.gd:1036`) on main locally, so it wasn't clean
  either. Round 2 should track the leak down rather than loosen the grep.
- **Round 2 (pause, settings, quit) is still needed.** In the game, Esc only
  frees the mouse. There's no way back to the title except quitting. Scene
  return is active only after a picked scene. The front door has no Settings.
  The F1/F2/F5-F8/B/R dev keys still work in the default game.
- **The tagline still reads "A little wilderness, made by you".** It's left
  as the user's title had it. Whether it fits the isle is the user's call.
- **R respawns at the rubble slope's foot**, the station start, not by the
  plane.
- **Untested visually.** The orbit framing (distance 1.35 times the art's
  half-span, at least 70 m, lifted 6 m) and whether the card hides the isle
  have only been checked by numbers. Look at a rendered run with no
  `--no-title` before tuning anything.
- **Startup.** The isle comes up in about 14 s headless with the suite in
  parallel, and in about 7 s alone. All of it is under the veil.
- Any later kit isle can use the same front door. Give it a scene script
  like `zenscape.gd`: the `FrontDoor` child, `open(self)`, the two-frame
  wait and the input gate.

## Round 2 done

Branch `consolidate/pause-settings`, off `consolidate/front-door` f696ce83.
Not merged, not pushed.

### What the player sees

- **Pause.** In the game (after Begin, or with `--no-title`), Esc or the
  pad's Menu pauses the tree (`get_tree().paused`) under a linen sheet in
  the old pause panel's look (scrim, cloth, Newsreader rows, dashed seam):
  "Paused" over the isle's name, then **Resume** (its key reads Esc, or pad B
  with the pad in hand), **Back to the plane** (only on foot or under the
  canopy), **Settings**, **Scenes** (when the picker is offered), a seam,
  **Back to the title** and **Quit**, and an italic line under them: "The
  isle starts afresh from the title." Up and down (arrows, D-pad, stick)
  step the rows, Enter, a click or pad A presses, Esc or pad B backs out one
  level, and Menu resumes from anywhere. The mouse is freed while paused and
  captured again on Resume if it was before.
- **Settings**, from the pause and as a quiet **Settings** on the title's
  card (between Scenes and Quit; the card stays minimal): Look (Visual
  quality, Render resolution, Clouds, Night sky, Planet in the night sky),
  Sound (Volume, "Steps, tokens and life" on the Genesis bus, Mute all
  sound), Controls (Controller vibration). Each row is a choice,
  "‹ Balanced ›", stepped by left and right, a press, or a click on its ‹.
  It saves and applies the moment it steps.
- **R** on foot (or under the canopy) is the same as Back to the plane: you
  stand beside the parked plane where a hop out of it lands, facing it
  (`kit_isle._return_to_plane`, now public as `zenscape.back_to_plane`).
  The plane never moves, which keeps to the hand landing's rule
  (docs/design/manual-landing.md: you board to fly, nothing summons it). In
  the plane, R isn't a player key and the pause doesn't offer the row.
- **Back to the title** reloads the main scene on the command line's flags,
  minus the ones that skip the title. That's `front_door.title_args()`,
  which also drops `--fly`, `--near-ring`, `--place=` and `--capture=`. The
  isle comes up again under the veil, because the kit saves nothing.
- **Pad prompts follow the device in the game now.** The kit never called
  `Pad.note`, so its prompts never switched. The pause host connects the
  root window's input to `Pad.note`, as the old game's `pad_input.gd` does.

### Where it lives (none of it in kit_isle.gd)

- `scripts/kit_isle/menu_sheet.gd` is the shared linen sheet: rows,
  choices, groups, the seam, the hint line (a `pad_prompt.gd` Label), and
  keys, mouse and pad navigation. It runs while paused.
- `scripts/kit_isle/pause_menu.gd` is the pause's rows and signals.
  `scripts/kit_isle/settings_menu.gd` is the settings sheet.
- `scripts/kit_isle/pause_host.gd` does the pausing and wiring, and is
  `zenscape.gd`'s `pause` child. It won't open under the title, before
  `walk_ready`, or while the study's recording-name panel is up.
- `scripts/kit_isle/game_settings.gd` is the model. It keeps everything
  where the old game kept it, through the same pieces, so a choice holds
  in both games: `look.cfg` (LookPass's `clouds`/`night`/`sky` keys and
  savers, render_resolution's `[display] max_lines`), `sound.cfg`
  (genesis_audio's keys, applied with `apply_settings`) and `pad.cfg`.
  Visual quality had no saved value in the old game, so it's new: `[quality]
  tier`, Balanced (the kit's tier) until the player chooses. The isle reads
  clouds, night, planet and the cap itself as it's built. `apply_start`
  applies the sound, vibration and tier on `isle_ready`. The paths are vars,
  so tests write elsewhere.
- `scripts/kit_isle/dev_keys.gd` gates the developer keys the way the
  picker's IN_RELEASE pattern does, but off in release: `const IN_RELEASE :=
  false`, the project setting `zenscape/dev/dev_keys`, `--dev-keys`,
  `--no-dev-keys`, and `as_release` for tests. The gated keys are F1, F2,
  F3, F5-F8, the station keys 0-9 - = [ ] \, L and Shift+L, and B on foot,
  plus F1, R, L and B in the plane. In a release build `strip_captures`
  takes `--capture=`, `--capture-seq=`, `--capture-wait=`, `--capture-high`,
  `--at=` and `--card-hold` out of the flags before the isle reads them.
  Editor and debug runs (run-zenscape.command included) keep them all.
  `zenscape.gd`'s `_unhandled_input` does the filtering.

### The CI exit leak: found and fixed

There were two separate teardown leaks, both in the aqueduct's sky.

1. **`N RID allocations of type ...DummyShader... leaked at exit`** (every
   headless run, N 1-4). I bisected by flags and then by code: `--no-sky`
   was clean, `--no-far-isles` was clean, the lone far isles alone leaked,
   making but never standing them was clean, standing them without
   `SkyIslets._fall` was clean, and inside `_fall` the leak came with the
   single line `drops.process_material = _drop_material`. That's one static
   `ParticleProcessMaterial` handed to every islet fall's GPUParticles3D.
   Giving each fall its own `.duplicate()`, made as it stands, leaves
   nothing. Checked over about 15 runs: the front door straight in and
   titled, the aqueduct isle, early quits, the packaged self-check
   (`--verify-desktop-build`) and `test_export_entry` exactly as CI runs it.
   Before the fix, `test_export_entry`'s log had `ERROR: 4 RID allocations
   ... DummyShader` and failed CI's grep; after it, the log has no `ERROR:`.
   The copies share the one generated shader, so nothing changes on screen.
   **What's not proven** is the engine mechanism. The leaked count isn't one
   per fall: even one fall leaked 1-4 shaders, and a minimal repro outside
   the game doesn't leak. The likeliest cause is godot#124183: the dummy
   renderer's shader and material RID owners aren't thread-safe, so
   allocations racing on workers corrupt the count. It's fixed in 4.8 by
   godot#121958. If a stray `DummyShader` count ever shows up on CI again,
   look for materials made or first used on workers, or move to 4.8.
2. **4276 objects, 13 Jolt bodies and 2087 shapes leaked**, seen once in
   the runner under load. `SkyPierced._forget` freed the worker-built ruins
   tree only when the lid hadn't stood. The pierced isle stands its parts a
   frame at a time, within the sky's budget (`SkyCommits`). Freed between
   its lid and its ruins (the packaged check frees the scene a few seconds
   in, and a slow runner gets there sooner), the ruins tree was orphaned.
   Now any ruins without a parent are freed. `tests/test_isle_teardown.gd`
   frees the scene at exactly that moment: it fails on the old code and
   passes now.

Neither the grep nor `known_failures.txt` changed. **Not confirmed on the
Windows CI runner itself** (nothing was pushed).

### Tests (headless, `tools/run_tests.py --tests ...`)

New: `test_game_pause` (pause, keys and pad, prompts, settings and scenes
round trips, Menu, R and the row back to the plane, no row in the plane,
back to the title), `test_game_settings` (kept sound applied at start, the
title card's Settings, volume, mute, vibration and resolution applied and
kept, the look's choices kept under the old keys, read back), `test_dev_keys`
(the gate, capture flags stripped as release, keys dead as release on foot
and in the plane, alive in debug), `test_isle_teardown`. All pass. So do
the import check, `test_front_door` (now 4 card buttons), `test_export_entry`,
the three `test_scene_picker*`, the five `test_aqueduct_isle*`,
`test_kit_isle_landing`, `test_gamepad`, `test_gamepad_screens`,
`test_title_resolution`, `test_title_showcase` and `test_world_title`.
In the first batch, `test_export_entry` failed once with leak 2 above. After
that fix the 20-test batch ran clean: 20 passed and none
`pass_with_known_engine_error`, where round 1 had seven `exit_leak`s. The
full suite wasn't run.

### Unverified (needs a rendered run)

- How the sheets look: their size on the screen, the linen, the glyph chips
  and whether the settings sheet fits on a small window. Everything was
  checked headless by numbers only.
- Live look changes. Headless has no look pass, so quality, clouds, night
  and planet were only checked as saved. In a rendered run they go through
  `LookPass.apply_tier` and its `set_*` setters, and the tier is applied at
  start.
- MetalFX or FSR scaling with a real GPU (the scale value is checked).
- Pausing with the plane's engine sound running (its generator just
  starves) and paused shader time (the clouds and water still move under
  the scrim).

### For round 3 (clouds)

- Hook the cloud host into `game_settings.gd` if the clouds get a new
  setting (a row in `ENTRIES`, a case in `index_of` and `choose`).
- `pause_host.can_pause` is the place to block the pause in a set piece.
- Whatever is built on a worker and stood a frame at a time needs freeing
  when it never stands, as `_forget` now does for the pierced ruins. Check
  the cumulus and tearing ports for the same pattern, and run them through
  `test_isle_teardown`'s kind of check. Keep handing each particle system
  its own ParticleProcessMaterial copy, too.

## Round 3 done

Branch `consolidate/clouds`, off `consolidate/pause-settings` 6df85518.
Not merged, not pushed.

### What the player sees (rendered only; see Unverified)

- **Towering cumulus round the aqueduct.** There are four towers
  (`KitClouds.TOWERS`):
  - **The home tower**, 790 m south of the isle at (-100, 750), over open
    sea. It's the one in sight from the isle's top and from the title's
    orbit. It begins rising out of the cloud sea about 10 s after the isle
    comes up (the old home tower's `RISE_SOON`), so you can watch it climb
    over the first five minutes.
  - **Three more** at 1.2 to 1.3 km: west (-1100, 400), east (1350, -200)
    and north-north-west (-600, -1000). Each starts at a different point in
    its life.

  Each tower lives the old game's life: it rests 2 minutes, rises 5,
  stands 14 and wanes 3, then rises again. Towers never drift. They're
  drawn by the unified cloud volume, which now gets them, as one body with
  the sea. They aren't solid: fly in and the view goes white (the volume's
  own fog), the wind muffles, and you come out the far side.
- **Drifting clouds.** The old game's 70 small cloud heaps (924 puffs) ride
  the breeze across the isles' field, between y -35 and 95. That's the
  height you fly at. None is laid on the isle, on an isle or in a tower.
  They thin away over the four places nearest the eye (the isle, far
  isles, clusters, the pierced isle), and the field re-centres as you fly
  away.
- **Cloud tearing.** Your plane and all four CPU planes tear a tunnel
  through any puff or tower they fly through. It opens, widens, holds 7 s
  and heals over 22 s. Tufts are dragged out after the plane, with a burst
  on the way out.
- **The CPU planes fly through clouds.** About 30% of their goals are now a
  pass through the nearest drifting cloud, the same share as the old game.
  Look at them over the near isles. They also tear the home tower if a lap
  takes them through it.
- **The plane's wind muffles in cloud** (`GlideAir.advance`'s cloud term),
  as in the old game.
- **Settings > Clouds** changes what it changed in the old game: the sea's
  style, which the volume also shades the towers in. Visual quality sets
  the volume's tier. There's no new setting.

### Where it lives

- `scripts/cloud_host.gd` is **the seam**. A cloud host has `towers`,
  `clouds` and `wakes`, and answers `in_cloud`, `cloud_body` and
  `cloud_near`. The rules are statics on it (`veil_of`, `body_of`,
  `nearest_of`, `tear_into`), and both hosts use them. It's also a node
  for a sky laid by hand: `setup(spots, slots, blocked)`, then `step(delta,
  eye, time, fliers)` each frame, `hook(traffic)` and `flush()`.
- `LookPass.cloud_host()` / `LookPass.host_of(scene)`: the scene's
  `cloud_host()` if it has one, else the old `wanderer.islands`. The near
  sea and `CloudVolume.update(camera, sea, host, ...)` both take it.
  `SkyIslands` is still the old game's host, and its node tree is
  unchanged. Its `in_cloud`, `cloud_body`, `_tear` and `cloud_near` now
  call the statics.
- `SkyTowers.fixed`: hand-laid spots. Spot i stands in for cell (i, 0), so
  its life, shape and key work as before (spot 0 is the home life). With
  `fixed` set it never reads `spot`, so the peak ring and its layout never
  run (the test checks `SkyWorld._layout` stays empty). `keeps(home,
  margin)` is the instance form of `blocks`.
- `SkyClouds.build(slots, blocked)`: the callable replaces the
  `SkyPeaks`/`SkyTowers`/`SkyForestIsles` checks. The rng sequence is
  unchanged, so the old game lays the same clouds.
- `SkyTraffic._through_cloud(plane)` is factored out of `_choose`.
  `IsleTraffic._choose` is now 30% cloud, 35% buzz and the rest laps.
- `scripts/kit_isle/kit_clouds.gd` is the kit's host (it extends
  cloud_host). It knows TOWERS and drops any spot that would stand within
  340 m (the old `SkyTowers.KEEP`) of the lock ring's widest ring, an isle,
  a cluster, the pierced isle, or the line from the isle through the
  chain's ring and 1.5 km on (`clear_of_play`). So another kit isle's sky
  never stands a tower in its way. The aqueduct keeps all four, the
  closest 401 m clear. The kit has no thermals (no currents). It runs its
  own `_process` after the traffic.
- `studies/aqueduct_isle_sky.gd` grew by about 30 lines: the `clouds` var,
  `--no-sky-clouds`, `_build_clouds` and the IsleTraffic split.
- `studies/kit_isle.gd` grew by 8 lines: `cloud_host()` and the wind
  muffle in `fly_step`.

### Cost (headless, this Mac, from `tests/test_kit_clouds.gd`)

- **A frame of the clouds:** 145 to 240 µs on the main thread (mean of
  9,000 steps; the higher figure is with other tests running alongside). That's the towers' lives, the puffs' screens, keeps and
  follow, five fliers traced, and the tunnels handed on. It's the same
  work and the same counts as the old game: 4 towers marched (the old
  game's ring shows its home tower plus 3 at about 2.2 km), 70 clouds and
  4 CPU planes.
- **A tower's stage pair:** 185 to 245 ms to bake, on a worker. The rising
  stands a new pair about every 7.5 s.
- **Standing up on the main thread:** 13 to 16 stand-ups while the towers
  came in and went through their lives, a mean of 370 to 850 µs. All of them sit
  inside `SkyCommits`' 4 ms budget rule, and none piled onto another. The
  first one, 5 to 10.6 ms headless, makes the shared cumulus noise texture. In a
  rendered run the near sea has usually made that already.
- **Not measurable headless:** the volume's GPU march with towers in it.
  It's capped at 4 towers (`CloudVolume.TOWERS`), as in the old game.

### Tests (headless, `tools/run_tests.py --tests ...`)

New: `test_kit_clouds`. It checks the host and the seam (the kit's, the
old game's through its wanderer, and none). The cloud volume reads the
host. Placement is clear of everything, bad spots are dropped and no ring
layout runs. The towers are built on workers and live: about to rise,
rising, standing, waning, then rising again, never drifting and out of
step. The puffs are laid clear and drift. Traffic passes through clouds,
goes in and tears. The player's plane tears a puff (puffs given the
tunnel, tufts) and a tower (its shader's wakes), and the volume marches
both. Freeing the scene mid-bake leaves nothing. The cost lines above are
printed by it.

Results:

- **Pass:** the import check, `test_kit_clouds` (17 to 22 s alone),
  round 2's set (`test_front_door`, `test_export_entry`, the three
  `test_scene_picker*`, the five `test_aqueduct_isle*`,
  `test_kit_isle_landing`, `test_game_pause`, `test_game_settings` and
  `test_isle_teardown`), the old game's `test_cloud_styles`,
  `test_cloud_volume`, `test_cloud_wakes` and `test_sky_traffic`, and the
  other kit isles' tests, whose skies now carry the clouds too
  (`test_bell_spires_isle`, `test_cloister_tarn_isle`,
  `test_colonnade_spine_isle`, `test_sundered_gorge_isle`,
  `test_isle_lock`, `test_isle_lodestone`, `test_isle_hall_chain` and
  `test_kit_water`). `test_cloud_view_from_above` is gpu-tagged, so it's
  skipped headless.
- **`test_sky_cumulus`** fails one check, "And the streaks thicken into the
  cloud's wisps" (`GlideAir._shown`). It fails the same way on the base
  commit 6df85518, so it isn't from this round. It isn't in
  known_failures.
- **`test_aqueduct_isle_life` is flaky.** On the branch: 1 of 3 runs
  failed, each failure on a different check (a gust ribbon dipped under
  the isle, songbirds coming home). On the base: 1 of 3 failed (a leaf off
  the turf). It depends on timing.
- **`test_cloud_volume`** came back `pass_with_known_engine_error`
  (exit_leak) once in a run alongside other tests. It did the same in the
  first base batch. It runs the old `diorama.tscn`.

### Unverified (needs a rendered run)

- Everything visual: the towers in the volume, their rising and waning,
  the puffs, the tunnels and tufts, the fog inside a tower, how the home
  tower frames from the isle and the title, and the style setting on the
  towers.
- The GPU cost of marching four towers over the kit's look.

### For round 4 (time and weather)

- The towers read the sky through the volume (`celestial`): sun, moon,
  night and `cloud`. A running clock should light them with no change
  here. The lightning hook is `cloud_volume.lightning =
  _scene.get("_lightning")`: give the kit a `_lightning` and the volume
  flashes in its towers.
- The towers' clock (`SkyTowers.clock`) is its own, not the day's.
  Seasons or weather that want fewer or taller towers should go through
  KitClouds (TOWERS, or a `pinned` age), not through `SkyWorld`.
- The puffs don't follow the sea's style or the weather (they didn't in
  the old game either). `SkyClouds` has no weather input.
- `kit_clouds.gd` is the place for a kit cloud setting if one is wanted
  (wire it through `game_settings.gd` as the Round 2 note says).

## Round 4 done

Branch `consolidate/time-weather`, off `main` 471e2249. Not merged, not
pushed.

### What the player sees (rendered only for the look; see Unverified)

- **A live sky.** The game opens on it (L's first entry, "Live sky"):
  Alpine morning's colours over a turning day. A day is 8 minutes (the old
  game's 480 s, golden hour and dusk lingering as there). The sun sets,
  the night look comes in and the **night style** chosen in Settings shows,
  the moon waxes over an 8-day month, and on a clear winter night the
  aurora may burn. The isle's life already read the daylight (fireflies,
  birds roosting), so it follows.
- **Seasons.** The year is the old game's: 28 world days, a season about an
  hour of play. A session **opens in the real date's season** (1 March
  opens spring, so mid October is autumn) and turns on from there. The
  season goes into the sky (`zs_sky_season`: the cloud sea's and the cloud
  volume's grade), the plants (`zs_season`: blossom, leaf fall, straw) and
  the ground (gold through autumn, cold through winter).
- **Weather drift.** The old scheduler's seasonal table: summer afternoon
  thunder, dawn mist after rain, snow only toward winter, a gold sky in
  autumn. A bright sky holds three to four minutes, rain a minute or two,
  a storm one to two. Each change eases in over about half a minute, as
  the old game's living weather does, keeping the start look's air. The
  season owns the gold whatever the sky.
- **Lightning in the cloud volume.** In a storm, strikes come every 5 to 30
  s. They are flashes inside the nearest standing cumulus tower (its near
  side), flashes in the cloud sea 160 to 700 m off, or bolts from a drifting
  cloud down into the sea, lighting the sea where they land. Never on an
  isle. Each has thunder a few seconds after (sound paced at 160 m/s). The
  volume shows a flash 6 times the plate's (`VOLUME_GAIN`).
- **Look presets are overrides.** L (or `--look=`) **holds** the sky in
  that preset: its hour, its weather, its season (snow is winter, gold is
  autumn, the rest spring or summer), the drift off, and its ground exactly
  as the editor sets it. **Live sky** gives the sky back, turning from the
  hour it was held at. In release builds L is a dev key, so players always
  get the live sky.
- **Settings > Look** has two new rows: **Day and night** (A day in 8
  minutes, A day in 24 minutes, Held) and **Weather** (Drifting, Still),
  kept in `user://look.cfg` under `[time]`.
- **Not done (the stretch):** rain and snow round the player. The kit sky
  rains and snows only as cloud, wet ground and cold, as before.

**To watch it fast:** `-- --no-title --day-length=60` (a day a minute),
`--hour=17.5` (straight to dusk), `--season=winter` (or spring, summer,
autumn, 0..1), `--year-days=4`, `--weather=storm` (lightning within
seconds), `--weather-hour=2` (drift ten times faster), `--weather-seed=N`.
Dev keys (debug and editor runs): **F9** next quarter day, **F10** next
weather (Shift+F10 drift on or off), **F11** next season (the plants
glide there), **F12** a strike now; a toast shows the clock, season and
weather. **Off:** `--still-sky` (held in Alpine morning, as before round
4), `--still-weather`. Captures hold their look unless `--live-sky`.

### Where it lives

- `scripts/kit_isle/kit_weather.gd` (new, about 450 lines) is the kit's
  host, the scene's `weather` child. It holds the `WorldClock` attached to
  the celestial rig, a `WeatherScheduler`, the shared calendar, the
  `Lightning` node (also the scene's `_lightning`, which
  `look_pass.gd:283` already hands the cloud volume) and the thunder. It
  also holds the hold and live semantics (`show_look`, `_hold`,
  `_go_live`), the settings hooks (`choose_day`, `choose_drift`; flags
  win) and the storm's aim (`strike`). It steps first in the look
  (`step`, as fidelity steps its clock first). The scheduler runs on hours
  of its own (20 s each), drawn for the clock's hour, so the weather
  drifts while the day holds.
- `scripts/sky_calendar.gd` (new, shared): fidelity's season state and
  rules, lifted out unchanged. Fidelity's old fields (`_season_shown`,
  `sky_season_published`, `season_glide`, …) are now forwarding properties,
  so `mood_look`, `hand_reach`, `spin_time`, `void_snap` and the tests are
  untouched.
- `scripts/living_weather.gd`: owns the generator's weather odds (the
  generator reads them from it, so the drift no longer preloads the
  generator), and its sky ease is a static, `ease_toward`, which the kit
  reuses.
- `studies/lightning.gd`: adds `strike_through` (a bolt sized to its drop),
  `flash_in` (no bolt), `aim` (a sky picks where its storm strikes),
  `sound_speed` and `volume_gain`. The plate's strikes keep the same
  random draws. Also a real fix: a pulse's time is a 32-bit `Vector2`, so
  minutes into a session a strike's first frame showed no flash
  (`PULSE_SLACK`).
- `scripts/cloud_volume.gd`: scales the flash by `volume_gain`.
  `weather_scheduler.gd`: `hour_of_day` (off by default).
- `studies/kit_isle.gd` grew by about 20 lines: the `weather` and
  `_lightning` vars, its setup in `_build_light`, `apply_look` going
  through `weather.show_look`, Live sky in `_look_ids`, `weather.step` in
  `_advance_look`, and the F9-F12 keys. `dev_keys.gd` gates F9-F12 on foot
  and in the plane. `game_settings.gd` has the two rows and applies them
  at the start.

### Cost (headless, this Mac, measured under heavy load from other agents)

- **A frame of time and weather:** 14 to 22 µs on the main thread (mean of
  3,000 steps: the clock, the drift, the year and the storm), from
  `tests/test_kit_time_weather.gd`.
- **A bolt:** 0.7 ms to build its tubes on the main thread, once a strike,
  every 5 to 30 s in a storm. Flashes in towers or the sea build nothing.
- **Not measurable headless:** the cloud volume's flash, which is one more
  term already in the march.

### Tests (headless, `tools/run_tests.py --tests ...`)

New: `test_kit_time_weather` (about 50 s alone, 100 s under load):

- It opens live, attached and turning from `--hour` in `--season`'s
  quarter, the ground in autumn gold at once, the sky's and the plants'
  seasons published, the start look's pins handed to the drift, and the
  easing.
- The date season. Day into night (sun down, night look in) and back.
- F11 to winter with the plants gliding, then winter in the sky and on
  the ground. The year turning with the days.
- The drift: at least three skies, eased, the season keeping the gold,
  drawn for the clock's hour, and holding when told.
- Presets hold the hour, the season and their own ground (First snow,
  Copper autumn). Live sky resumes from the held hour, and L and Shift+L
  go round it.
- The storm: tower, sea and bolt strikes, never on the isle, thunder, no
  downburst, and the cloud volume's flash parameter with the gain.
- The settings rows apply and keep. A `--still-sky --day-length=30` start
  is held, and the flag beats the settings.

`test_aqueduct_isle_look` now expects the live opening, not the still
Alpine morning (an intended change, not a looser check).

Results:

- **Pass:** the import check, `test_kit_time_weather`, and every round
  1–3 test: `test_front_door`, `test_game_pause`, `test_game_settings`,
  `test_dev_keys`, `test_isle_teardown`, `test_kit_clouds`, the three
  `test_scene_picker*`, `test_export_entry` and `test_kit_isle_landing`.
- **Also pass:** the five `test_aqueduct_isle*`, the other kit isles'
  (`test_bell_spires_isle`, `test_cloister_tarn_isle`,
  `test_colonnade_spine_isle`, `test_sundered_gorge_isle`,
  `test_isle_lock`, `test_isle_lodestone`, `test_kit_water`,
  `test_rune_serpent`), and the old game's `test_lightning`,
  `test_sky_seasons`, `test_weather_drift`, `test_weather_scheduler`,
  `test_season_scene`, `test_world_clock_scene`, `test_world_clock`,
  `test_first_steps`, `test_worlds_flow` and `test_cloud_volume`.
- **`test_isle_hall_chain`** (serial, a frame budget) failed twice under
  load: 15.8 ms and 24 ms, with worker builds of 4 to 8 s against base's
  2 s. It then passed twice on the branch, alternating with base: 1.8 and
  1.5 ms against base's 1.2 and 1.1 ms. Load-affected; rerun later on a
  quiet machine.
- `test_cloud_volume` came back `pass_with_known_engine_error` (exit_leak)
  once, as round 3 saw on base. The full suite wasn't run.

### Unverified (needs a rendered run)

- Everything visual:
  - the night styles at night on the isle
  - the season grade on the cloud sea and the volume
  - the plants' seasons on the kit flora (straw grass in winter, blossom
    in spring)
  - the drift's transitions and the ground's gold, cold and wet over the
    ruin kit's stone
  - how the flashes read inside a tower and in the sea, and whether
    `VOLUME_GAIN` 6 is too much or too little
  - the bolts' size and width at range (0.055 m × drop/20 for the core)
- The thunder's loudness.
- Whether an 8-minute day with about 2 minutes of night suits flying. The
  24-minute setting is the alternative.

### Decisions for the user

- The default is a **turning day of 8 minutes** and a **turning year
  opening on the real date's season**. The old game pinned each world's
  season instead. `--season=` or F11 shows others.
- The kit drifts on the **scheduler's seasonal table**, which has storms,
  not on living weather's climate odds, which have none. That's so
  lightning happens.
- A held preset owns its ground and **pins the season** it was drawn for.

### For round 5 (drop-list tidy)

- Nothing here touches the drop list. `living_weather.gd` still preloads
  `desert_landscape.gd` for `KINDS` (main-only climate detection). Cut it
  with the constant hubs in round 7.
- Rain and snow round the eye, if wanted: `precipitation.gd`'s particles
  sit in a plate-sized box at the world's origin, and the shader hides
  every drop with no ground map under it (`reference_precipitation.
  gdshader:61`). It needs a moving centre uniform and a ray-baked height
  map round the eye, which is shader work and GPU-only to verify. M.
- `KitWeather.YEAR_DAYS`, `DAY_SECONDS` and the strike shares are the
  tuning knobs once the user has looked at a rendered run.

## Round 5 done

Branch `consolidate/drop-tidy`, off main 471e2249. Not merged, not pushed.

### What the player sees

- **No sky folk on the cluster isles.** The lantern bearers and the fishers
  on the docks are gone from every cluster in the kit's sky. Their
  features are still drawn from the rng, so the clusters lay out exactly as
  before; only the figures (and the bearers' lantern and halo) are left
  out. **The airship crews are unchanged** (still open with the user): the
  test counts 6 aboard.
- **No peak ring.** The ring was never built in the kit, but
  `SkyWorld.ring` defaulted to on, so `ring_on()` answered true and the
  haze, edge-wind and layout calls took their ring paths. Now it is off for
  the kit's life, so those calls give their "no ring" answers and no layout
  is ever worked out.
- **The sky should look as it did.** With the ring "up", `sea_peaks()` and
  `painted_ridges()` were 0, so the painted distant peaks and horizon
  ridges were already off in the kit. Turning the ring off would have
  brought them back, so I added `SkyWorld.painted_sky` (default true) and
  the kit sets it false. If you want the painted peaks and ridges back in
  the kit, that one flag is the switch. Rendered only, so unverified.
- **Walking off an edge is unchanged** (canopy or respawn is still open).

### Where it lives

- `scripts/cluster_dresser.gd`: `furnish(..., folk := true)`; bearer and
  fisher are skipped when off. `scripts/sky_clusters.gd`: `var folk := true`,
  passed to `furnish`. `studies/aqueduct_isle_sky.gd`: one line,
  `clusters.folk = false`. The old game's `SkyIslands` keeps the default.
- `studies/kit_isle.gd`: `_ready` reads the SkyWorld flags, remembers
  `ring` and `painted_sky`, sets both off; a new `_exit_tree` hands them
  back, so a later old-game scene in the same process (the Scenes picker)
  gets its ring as before. Code stays; round 7 deletes it.
- `scripts/sky_world.gd`: the `painted_sky` var and its two uses.
- Shared files touched: `cluster_dresser.gd`, `sky_clusters.gd`,
  `sky_world.gd` (small edits). Round 7 deleting folk or the ring will meet
  these three.

### Tests (headless)

New: `test_kit_drops` (it fails without the `clusters.folk = false` line,
checked). It stands every cluster and finds no figure outside an airship,
counts the crews, checks the ring is off with no layout, edge wind or
haze, and that the flags come back on leaving.

All PASSED: `test_kit_drops`, `test_front_door`, `test_game_pause`,
`test_kit_clouds`, `test_kit_isle_landing`, `test_isle_teardown`,
`test_export_entry`, `test_aqueduct_isle`, `test_aqueduct_isle_sky`,
`test_aqueduct_isle_look`, `test_aqueduct_isle_plane`, `test_sky_clusters`,
`test_sky_world`. No full suite; `test_sky_cumulus` and
`test_aqueduct_isle_life` were not run.

### Unverified

- Rendered look: that the cluster isles read right without their folk, and
  that the sky is unchanged with `painted_sky` off.

### For later rounds

- If the crews go, `sky_airship.gd:998` is the only figure left in the kit.
- When round 7 removes the ring, the kit's flag handling and `painted_sky`
  go with it (the painted sky is then simply on or off).

## Round 7 done

Branch `consolidate/deletion`, off `main` 471e2249 (rounds 1 to 3). Not
merged, not pushed. `main` has moved since (the pocket sail, 46db24a0):
see "Merging" below.

The user changed the scope mid-round: the peak ring and the lower world
stay as code, unwired, reachable only by their flags. So this round
untangled the hubs, unwired those two, and removed chunk claiming, the sky
folk and the glider.

### Lines removed, by commit

| Commit | What | Lines (+/-) |
|---|---|---|
| a1efbbd7 | Hubs untangled (no behaviour change) | +141 / -99 |
| 28f8e25f | Peak ring and lower world unwired (kept, off, back by flag) | +103 / -72 |
| 7a5a2b5d | Sky folk removed | +16 / -391 |
| 2d119d0a | Glider removed | +203 / -672 |
| a5c0dd15 | Chunk claiming removed | +157 / -3,024 |
| 76075b93 | The ring's remaining tests run under `--peak-ring`; wingspan check | small |
| **Total** | 115 files | **+621 / -4,243** |

Of the total, tests are -1,172 net and tools -1,087. `sky_islands.gd` went
from 1,365 to 624 lines and `wanderer_eye.gd` from 3,123 to 3,002. The
kit's static reach (all five kit scenes and the front door, scene catalog
excluded) went from 406 files and 147,610 lines to 403 files and 145,387
lines. `sky_islands.gd` and `wanderer_eye.gd` are no longer in it.

### The hubs

- `sky_sea` → `sky_islands`: `island_spots` reads `Plate.HALF`.
- `look_pass` → `sky_world`: the ring's switch (`ring`, `ring_on`,
  `sea_peaks`, `painted_ridges`, `read_flags`, plus `use_flags` for tests)
  moved to `sky_homes.gd`, which preloads nothing of the sky. `SkyWorld`
  forwards to it. **The `look_pass.gd` edit is two preload paths**
  (`sky_world.gd` → `sky_homes.gd` in `ridge_strength` and
  `apply_sea_peaks`), nothing else.
- `meadow_types` → `inland_world`: a meadow type's world recipe (`recipe`,
  `plan`) moved to the new `scripts/meadow_recipe.gd`. Its callers are
  `world_lands.gd`, `test_meadow_types`, `tools/map_meadows.gd` and
  `tools/probe_meadow_digests.gd`.
- The seven → `native_chunk_editor`: the editor is typed `Node`, not
  `NativeChunkEditor`, in `world_reference_props` (the edge
  `native_terrain_data` came through), `genesis_audio`, `genesis_canvas`,
  `land_life`, `songbirds`, `stroke_feedback` and `desktop_build_check`.
- **Still reached, through other paths:** `sky_world` (via
  `sky_islets` → `sky_forest_isles`), `inland_world` (via `garden_view` →
  `native_terrain_recipe`) and `native_chunk_editor` (via `songbirds` →
  `scene_inspector`, which genuinely needs the editor). Cutting those is
  the next untangling, not this round's four.

### Kept but unwired

Neither runs by default on any path, the builder included. Their tests
run under their flags (`SkyHomes.use_flags`, `SkyBelow._on`).

| Feature | Files | Flag that brings it back |
|---|---|---|
| Peak ring: the bounded world, the ranges, the ring, the summits, the edge wind | `sky_world`, `sky_peaks`, `sky_peak`, `sky_ring`, `sky_cache`, `sky_reveal`, `mountain_spire` | `--peak-ring` (the ranges and the ring); `--peaks` (the ranges alone, the sky open) |
| Lower world | `sky_below`, `sky_archipelago`, `islet_lod`, `landform_preview` (and `sky_haze`'s below terms) | `--below` (`--landform=<name>` as before) |

- `--no-ring` and `--no-peaks` are gone: that's the default now. The flag
  is `--peak-ring`, not `--ring`, because the aqueduct already has
  `--ring=x,y,z` and the collectible gallery has `--ring`.
- `--below` was on in play by default before (off only with
  `--no-below`). Now it's off everywhere unless asked for.
- **`--moments` now needs `--peak-ring` too.** The moments set pieces are
  laid by the ring's world layout (`SkyWorld._moments`). With `--moments`
  alone, the builder lays none. The moments tests run under both flags.
- The `--wonders` (pillars, tepui, forest isles) were already off. They're
  unchanged.
- The tests run under `--peak-ring`: `test_sky_world`, `test_sky_layout`
  (which checks the new defaults first), `test_sky_summits`,
  `test_sky_peak_look` and `test_sky_peaks` (both `--peaks`),
  `test_sky_cache`, `test_sky_reveal`, `test_sky_swap`, `test_sky_overview`,
  `test_overview_framing`, `test_sky_clusters`, `test_sky_moments`,
  `test_moments_world`, `test_hand_landing_exit`, `test_lower_world`
  (`--below --peak-ring`) and the edge-wind part of `test_sky_glide`.
- `test_sky_painted_ridges` and `test_sky_sea_peaks` now check the default
  (no ring) in process and `--peak-ring` in the child.
- Without the ranges, `test_lower_world`'s first archipelago island paid a
  one-time warm-up: 95 ms against 13 ms. Under `--peak-ring` it's 11.6 ms.
  A plain `--below` run may hitch once, the first time an island stands.

### Removed

- **Chunk claiming.** The fresh chunk islands round the plate, their bakes,
  far flora, look syncing, plate hiding, the claim and the world shift, the
  `built_islands` bookkeeping, F to another island, the canopy claiming
  the island under it, and `SkyAmbientLife` on chunks are gone. Now:
  - `SkyIslands` is the sky round the plate: currents, clouds, cumulus,
    islets, clusters, pierced isles, airship, traffic, tokens and
    moments. OFFSETS stay as slots for the currents, laps and clouds, so
    the builder's sky lays out as before, minus the five islands.
  - **Saves:** a world saved after claims keeps its `origin`, so the sky
    still lays out round the plate's home. Its `plate_seed` and `built`
    islands are written back exactly as read (`_claims_kept`), so no save
    loses a built island's land, though none shows.
  - F and the canopy come in only to the plate, or under `--below` to the
    archipelago.
  - `SkyCollectibles` lays only the plate's under-line (the plate key's
    format is unchanged, so collected ids hold). `SkyHaze.emerging` is
    gone and the rising boxes are published empty.
  - Tests deleted: `test_tools_after_claim`, `test_sky_chunk_popin`,
    `test_sky_streaming_budget` and `test_sky_ambient_life`.
    `SkyAmbientLife` is still covered by the kit's `test_aqueduct_isle_life`.
  - Tools deleted: `profile_claim`, `probe_chunk_popin`,
    `profile_sky_streaming` and `probe_sky_glide`. Twenty-four capture and
    probe tools now wait on `islands.built()`.
- **Sky folk.** `sky_folk.gd` and `test_sky_folk` are deleted.
  `IslanderFigure.SKY_SCALE` and `SCARVES` replace `SkyFolk.SCALE` and
  `SCARVES` for the clusters' folk (`cluster_dresser`) and the airships'
  crews (`sky_airship`, kept). `sky_homes.gd` is **not** folk (the audit's
  row B had it wrong): it's the wonders' home spots, and it now also holds
  the ring's switch.
- **The glider.** The `--glider` flight, the wanderer's `plane` flag, the
  cloth wing, the flap (click, E, the pad's X), the glider hints and its
  `_land` are gone, as are the pad's `glide_rise`, `glide_dive` and
  `glide_flap` actions. `sky_glide.gd` stays: it's the flight model that
  `sky_plane` and `sky_dive` extend. `glide_vapour`, `glide_air` and
  `glide_camera` stay too, since the plane uses them. The glider figure's
  shared meshes and soft textures moved to `facet_mesh.gd` (`frustum`,
  `gem`, `faceted`, `soft_band`, `soft_ring`). The wanderer's drawn plane is
  still the var `glider`, because about 30 capture tools read
  `eye.glider`.

### What's left of the old game

The builder (Scenes → "Builder (old game)", `cozy_worlds.tscn`) still
loads and plays. Building, walking, flying the biplane, the hand landing
(default) and the `--auto-landing` F landing on the plate, skydive and the
canopy, perching on islets, and the sky round the plate are covered by the
tests below. What it lost: the other islands to fly to and claim, the
folk, the glider, and (unless flagged) the mountain ring and the lower
world.

### Files outside my area I touched

- `scripts/look_pass.gd` (round 4's file): two preload paths only, as
  above.
- `scripts/glider_figure.gd` is now a 9-line stub. It's kept only because
  `studies/kit_isle.gd:1867` (round 5's file) preloads it for
  `_soft_ring()`. Point that line at `facet_mesh.gd`'s `soft_ring()` and
  delete the stub.
- Kit-shared scripts with small edits: `sky_sea`, `sky_collectibles`,
  `sky_haze`, `sky_commits` (doc only), `cluster_dresser`, `sky_airship`,
  `islander_figure`, `person_kit`, `plane_figure`, `stone_plane_figure`,
  `facet_mesh`, `pad`, `songbirds`, `genesis_audio`, `land_life`,
  `meadow_types`, `desktop_build_check`. None is in round 4's or round
  5's list.

### Merging

`git merge-tree main consolidate/deletion` shows two conflicts against the
pocket sail (46db24a0), both from the glider removal:

- `scripts/pad.gd`: keep main's `dive_tuck` and drop the three `glide_*`
  actions (and `glide_rise`/`glide_dive` from the deadzone list).
- `scripts/wanderer_eye.gd`: main rewrote the walk hints and the
  canopy/summon text. Keep main's text and drop `GLIDER_HINT`,
  `GLIDER_PERCH_HINT` and the `plane` branches as this branch does. The
  pocket sail replaces the canopy there, so the canopy-claim lines this
  branch removed may already have moved.

### Tests (headless, `tools/run_tests.py --tests ...`, `--jobs 4`, the machine under heavy load)

Baseline: main 471e2249, the same patterns, in a second worktree.

- **Import check:** clean (no parse errors, no missing preloads), after
  every commit. All 326 tests and tools that touch the sky, the wanderer,
  the figures, the meadows, the pad or the look pass parse with
  `--check-only`.
- **Pass, round 1 to 3:** `test_front_door`, `test_game_pause`,
  `test_game_settings`, `test_dev_keys`, `test_isle_teardown`,
  `test_kit_clouds`, `test_scene_picker`, `test_scene_picker_entries`,
  `test_scene_picker_title`, `test_export_entry` and
  `test_kit_isle_landing`. Also the five `test_aqueduct_isle*` (life passed
  this time), `test_isle_*`, `test_kit_water`, `test_title_*` and
  `test_world_title`.
- **Pass, the builder and the sky:** `test_manual_landing`,
  `test_manual_landing_game`, `test_plane_flight`, `test_plane_landing`,
  `test_gamepad` (on rerun), `test_gamepad_screens`,
  `test_hand_landing_exit` (rerun, under the flag), `test_solid_props`,
  `test_glide_camera`, `test_glide_feel` (rerun), `test_sky_dive`, every
  other `test_sky_*` listed under "Kept but unwired", `test_sky_haze`,
  `test_sky_glide`, `test_sky_islets`, `test_sky_sea`, `test_sky_traffic`,
  `test_sky_airship`, `test_sky_clusters` (rerun), `test_sky_moments`
  (rerun), `test_sky_seasons`, `test_sky_objects`, `test_sky_plane`,
  `test_sky_fall_thread`, `test_cloud_*`, `test_collectibles_world`,
  `test_flight_crash`, `test_meadow_*`, `test_lower_world` (alone, under
  `--below --peak-ring`).
- **Fail as on the baseline:**
  - `test_sky_cumulus`: "And the streaks thicken into the cloud's wisps".
  - `test_collectibles_pickup` and `test_moments_world`: every check
    passes, but the engine logs `set_size` non-finite ERRORs. Same on main.
  - `test_sky_overview`: "The layout cost the main thread 68 ms" (81 ms on
    main). A timing budget: load-affected, rerun later.
- **Load-affected or flaky:**
  - `test_gamepad` failed once in the batch ("A again on the way up the
    jump: flying") and passed alone.
  - `test_lower_world` failed once on "It touches down and the pilot
    perches on the island, under the cloud", which depends on frame
    pacing, and passed on rerun.
  - `test_skydive` is `pass_with_known_engine_error` (`exit_leak`) in 2 of
    3 branch runs and 0 of 4 on main. The leaked resource is `clay_sound`'s
    cached `ui-cloth-5.wav` (the `ui_reach` clip) still held at quit, code
    this round didn't touch. On main the same test failed 1 of 4 runs on
    "The stick steers it". Worth a look if it shows up on CI.
  - `test_island_footprint`: `exit_leak` (5 resources), the same on main.
- `test_cloud_view_from_above` is gpu-tagged and was skipped. The full
  suite wasn't run. `known_failures.txt` is unchanged.

### Deliberately kept, and why

- **Skydive and the canopy:** the user hasn't decided yet. The pocket sail
  on main may settle it.
- **Airship crews:** the user hasn't decided.
- **The dresser's folk** (`cluster_dresser`'s lantern bearers and
  fishers): shared cluster code that the kit draws too. "Dresser folk off"
  is round 5's job on the kit side, so it was left there.
- **`SkyAmbientLife`'s claim handover** (`leave`, `handover`, the
  `handing`/`from` easing; about 70 lines) is now never called. It's
  kit-shared (the aqueduct's life), so it was left alone to keep the kit
  untouched. Remove it in a kit-side tidy.
- **Builder internals that only claiming used:**
  `NativeTerrainData.adopt`, `NativeChunkEditor.adopt_shore`, the
  `outline` argument of `Genesis.form`, `WaterFlow`'s adopt path and the
  comments that still name `SkyIslands claim` (`fire_field`,
  `cozy_regrowth`, `water_flow`, `sky_cells`, `sky_islets`,
  `sky_currents`, `sky_traffic`, `sky_airship`, `plane_figure.shift`). They
  are harmless and belong to the deferred old-flag refactor.
- **`SkyCells.advance` and `trim`** (spawning islands as you wander) are
  unused by the builder now, but `SkyCells` is shared and
  `test_sky_glide` still checks them.
- **`origin` in old saves** is honoured, so the sky stays where it was laid
  round a claimed plate's home.

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

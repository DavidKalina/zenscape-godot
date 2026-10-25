# The archive: what was cut, and how to bring it back

On 2026-10-24 the project was cut down to endless flight
(`studies/endless_flight.tscn`). Everything that was cut is kept whole at
the git tag **`archive/before-the-cut`** (commit `a0d5f517`, pushed to
GitHub). The tag is the project exactly as it stood the moment before the
cut: every scene in it ran then.

## Bringing something back

Look at it first, without touching the working tree:

```
git show archive/before-the-cut:studies/olmec_field.gd
git ls-tree -r --name-only archive/before-the-cut -- scripts/olmec_boss
```

Play it as it was: check the tag out in its own worktree, then set the
worktree up (kernels and import):

```
git worktree add ../zenscape-archive archive/before-the-cut
python tools/worktree.py setup ../zenscape-archive
```

Bring files back into today's game:

```
git checkout archive/before-the-cut -- scripts/olmec_boss studies/olmec_field.gd studies/olmec_field.tscn
```

A piece brought back usually needs the files it leaned on too. Each entry
below names its own files and what else it needed. To list everything a
scene reached at the tag, run the reach tool in an archive worktree:
`python scratch/cut/reach.py studies/<scene>.tscn` (kept in
`tools/reach.py` after the cut). The longer a piece sits, the more the
code round it has moved on, so expect a round of fixing to make it fit.

Older shelved work has its own branches: `shelved/calm-olmec` (the calm
Olmec in the overgrown land) and `shelved/river-mesh` (the rapids mesh).

## What was cut

Paths are as they were at the tag.

### The aqueduct isle and the kit isles

The hand-built sky isles you walked: the aqueduct station, its caches,
the sky, the water paths, the front door, pause and settings menus.
- Scenes: `studies/aqueduct_isle.tscn` (the old game's isle),
  `studies/zenscape.tscn` (the old title, the project's main scene until
  the cut), `bell_spires_isle`, `broken_ring_isle`, `cloister_tarn_isle`,
  `colonnade_spine_isle`, `drowned_nave_isle`, `hollow_keel_isle`,
  `stair_clouds_isle`, `sundered_gorge_isle`, `plane_field_isle`,
  `sky_weather_field`, `islet_yard`, `crag_reach`, `hall_rise`,
  `hall_chain`, `tower_shell_study`, `terrace_rock_test`.
- Code: `studies/aqueduct_isle*.gd`, `studies/kit_isle.gd` (the base of
  every kit isle), `studies/island_packs/`, `scripts/kit_isle/` (all but
  the few files the endless land uses, below).
- The menus worth reusing for the game's front door:
  `scripts/kit_isle/front_door.gd`, `pause_menu.gd`, `settings_menu.gd`,
  `game_settings.gd`.
- Docs: `docs/design/isle-look/`, `big-isle/`, `home-isle/`,
  `crag-reach/`, `layout-edit/`, `docs/scenic/`.

Still in the game from this family: `scripts/kit_isle/kit_land.gd`,
`kit_flora.gd`, `kit_look.gd`, `kit_water.gd`, `path_dirt.gd`,
`turf_lips.gd`, `hanging_roots.gd`, and `studies/aqueduct_isle_art.gd` and
`aqueduct_isle_flora.gd` (the endless grass and the layout handles use
them). They moved to `scripts/shared/`.

### The motif editor

Hand-authoring motifs (ruin places) on a grid, saved as recipes and rebuilt
from the code on every load. It was built on the kit isle, so it needed
nearly all of it.
- Scenes: `studies/motif_editor.tscn`, `motif_yard.tscn`,
  `motif_family_gallery.tscn`, `kit_piece_yard.tscn`.
- Code: `studies/motif_editor*.gd`, `studies/motif_yard.gd`,
  `scripts/roguelike/` (the city-layer crossings and greybox layers the
  editor and yard stacked; there was never any shop or merchant code),
  `scripts/cluster_motifs.gd` stayed (the land uses it).
- Saves: `motifs/authored/*.json`. Tool: `tools/kit_piece.py` (its yard
  went with the editor).
- Docs: `docs/design/motif-editor/`.

### The walking character

The wanderer on foot: run, jump (held-height and pump jumps), crouch
slide, slope surf, chained long jumps, the glide ("sail"), wall-run,
ledge grab and climb, rope, carry and throw, roll, lock-on. It played
well; it left because the game is the plane.
- Code: `scripts/pilot_motor.gd` (the motor, PilotMotor) stays for now as
  the ruin kit's size reference: the kit's steps, ledges and gaps are
  sized from its numbers. The rest went: `scripts/endless/endless_walker.gd`
  (getting out of the plane in endless flight), `scripts/pilot_figure.gd`
  and the pilot rig's helpers (`pilot_pose`, `pilot_paint`, `pilot_puffs`,
  `pilot_ripples`, `pilot_step_smooth`, `pilot_physics_ground`,
  `pilot_ledge`, `pilot_drop_shadow`, `wanderer_steps`), `pocket_sail*`,
  `scripts/lock_on/`, `scripts/rope/`, `scripts/noise/`,
  `scripts/interactables/` (the foot pieces).
- Model: `assets/models/pilot.glb`, `art/blender/pilot/`.
- Scenes: `character_study`, `character_runs/`, `pocket_sail_study`,
  `rope_study`, `swing_study`, `interactables_yard`, `crossing_yard`,
  `whole_body_chase`, `whole_body_leap_grab`.
- Docs: `docs/design/architecture/pilot-motor-verbs-handoff.md`,
  `rope/`, `rope-swing/`, `docs/design/endless-flight/get-out-handoff.md`.

### The Olmec, the ancient city and the underground

The Olmec boss and the world built for him: the city kit and its breaks,
the far cities, and the underground looks, among them the **Oculus**
(`--underground=oculus`: a vast sky opening in a cavern roof, a warm key
light, shafts and a mist sea).
- Scenes: `olmec_field`, `city_kit_gallery`, `city_breaks_yard`,
  `city_breaks2_yard`, `city_climb_yard`, `city_landmarks_yard`,
  `city_refuges_yard`, `city_serpent_yard`, `strange_earth_mouths_yard`,
  `strange_day_count_yard`.
- Code: `scripts/olmec_boss/`, `scripts/city_kit*.gd`,
  `scripts/city_breaks/`, `scripts/city_mouths/`, `scripts/underground/`
  (`underground.gd` holds the Oculus preset), `shaders/oculus_*.gdshader`,
  `shaders/olmec_stone.gdshader`.
- Models: `face_colossus.glb`, `city_relief.glb`, `wheel_head.glb`.
- The calm Olmec: branch `shelved/calm-olmec`.

### Enemies and creatures

- Code: `scripts/enemies/` (the headless body, the inhaler head, the
  rolling coin, the rune knight, the rim dragon, the serpent, the slams),
  `scripts/brood/` (the stone brood), crows and guacharos (`flyer`).
- Scenes: `enemy_yard`, `headless_body_isle`, `inhaler_isle`,
  `rolling_coin_isle`, `coin_track_bench`, `serpent_ride`, `brood_poses`,
  `crow_poses`, `guacharo_poses`, `flyer_yard`, `stun_yard`,
  `dragon_vision_study`.
- Models and their Blender sources: `brood_stone_guy`, `guacharo`,
  `headless_body`, `inhaler_head`, `rim_dragon_c`, `rune_knight`
  (`art/blender/<name>/`).
- Docs: `docs/design/brood/`, `bag-brood/`, `sky-weather/` (the storm
  dragon).
- Memories: the stone toad, the rolling coin circuit, the desert isle.

### The heist, the greed run and the wreck

The loot bag on a rope, digging, chests, the greed meter that woke the
brood and then the Olmec, the broken plane's six parts.
- Code: `scripts/greed/`, `scripts/carry/`, `scripts/dig/`,
  `scripts/chest/`, `scripts/home/`, `scripts/plane_arc/`,
  `scripts/cannon/`.
- Scenes: `heist_level`, `wreck_cluster`, `bag_study`, `bridge_study`,
  `chest_study`, `cannon_yard`, `snag_study`, `broken_plane_gallery`,
  `plane_parts_gallery`, `collectible_gallery`, `lodestone_study`,
  `fire_study`, `landing_study`.
- Docs: `docs/design/heist-level/`, `greed-run/`, `bag/`, `bag-hitch/`,
  `bridge-snap/`.

### Traps and greybox studies

- Code: `scripts/traps/` (all but the trap base and the gust the wind
  horn uses), `studies/greybox/`, `scripts/kit_isle/greybox/`.
- Scenes: `trap_yard`, `wind_horn_study`, `studies/greybox/*`.

## What stayed

Endless flight and everything it reaches: the land, sky, clouds, sea,
rivers, flora, birds, the overgrown halls and tunnels, the world regions,
the ruin kit (its arches, halls and tunnels stand in the land), the
layout handles, the native terrain kernels and the harness. The ruin
kit's break system (cutting pieces and dropping their parts) moved to
`scripts/breaks/`, for light destruction later. `studies/flight_study`
(the greybox flying course, with the crash) and `studies/ruin_kit_gallery`
stayed as test beds.

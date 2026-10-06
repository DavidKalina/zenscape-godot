# Deprecated and retired

A running tally of what ZenScape no longer needs, so it can be removed on
purpose rather than by accident. The dead study scenes and prototypes
(section 6) were removed on 2026-10-02, with the tests that drove the old
build palette and the hidden Bigfoot resident; the rest is still in the tree.

**The product (settled 2026-09-27):** relaxing Genesis-style landscape crafting.
Life emerges from what you build, and Bigfoot is a rare random event. You tune
palettes, take photos, and stitch chunks into an atlas. You then see the world
through a human's or a creature's eyes. There is no gameplay and no progression.
Anything that doesn't serve that belongs on this list.

Status key:

- **Retired**: the user has said it's gone.
- **Proposed**: not part of the vision, but the user hasn't confirmed it's gone.
  Decide before removing.
- **Keep**: looks related to something retired, but the product still uses it.

The in-tree survey was made from `feature/tree-mix` at fc0445d. Reachability
means reachable from the main scene, `studies/cozy_worlds.tscn`, by following
`res://` paths and `class_name` references. Tests and tools were not counted as
entry points. Sections 2 to 8 were brought up to date after the 2026-10-02
removal.

---

## 1. Retired directions (they live on branches, not in this tree)

None of this code is on the current line. `feature/twin-chunks-bridge`,
`feature/world-progression-2`, `feature/places-gallery`,
`feature/stitched-terrain` and `docs/cryptids-pitch` are not ancestors of HEAD.
Removing these directions means deleting branches and worktrees, not code.

| Direction | Status | Branches | Worktrees |
|---|---|---|---|
| Terrarium, world progression, world links | Retired | `feature/world-progression`, `feature/world-progression-2`, `feature/world-links`, `feature/day-seven`, `feature/dawn-review`, `feature/film-year`, `feature/winter-hibernation`, `feature/mind-time-of-day`, `feature/weather-reaches-him`, `feature/fish-restock` | `/private/tmp/zs-links`, `/private/tmp/zs-dayseven`, `/private/tmp/zs-review` |
| Cryptids camera-trap game | Retired | `docs/cryptids-pitch` (PR #16, PR #18), `feature/trail-cam`, `feature/evidence-objects`, `feature/bigfoot-traces`, `feature/fog-of-war`, `feature/actor-visibility`, `feature/reaction-bubbles`, `feature/lantern-ui` | `/private/tmp/zs-cam`, `zs-evidence`, `zs-traces`, `zs-fog`, `zs-sight` |
| Twin islands, bridge, campers | Retired | `feature/twin-chunks-bridge`, `feature/bridge-construction`, `feature/bridge-crossing`, `feature/bridge-cut`, `feature/bridge-weather`, `feature/suspension-bridge`, `feature/crew-far-island`, `feature/camper-jobs`, `feature/basics-one-camper`, `feature/island-generator`, `feature/second-chunk`, `codex/camper-models`, `codex/campsite-experiment` | `/private/tmp/zs-twin`, `zs-build`, `zs-cross`, `zs-cut`, `zs-crew`, `zs-jobs`, `.claude/worktrees/camper-models`, `.claude/worktrees/campsite-experiment` |
| Dispatch loop | Retired | Lived on the stitched and twin branches | none |
| Places map | Retired | `feature/places-gallery` | `/private/tmp/zs-places` |
| Seamless stitched landscape | Retired | `feature/stitched-terrain`, `feature/bigfoot-parts-trees` | `/private/tmp/zs-path` |

I sorted branches by name and commit history, so skim each one before deleting it.
`feature/life-answers`, `feature/bigfoot-sighting` and `feature/world-continuity`
are already merged into HEAD. Their code is live, so they're left off this table.

The chunk atlas (`feature/chunk-atlas`, merged) replaces the seamless
landscape and places map, and is **kept**.

**Suggested cleanup:** tag each retired branch tip first so nothing is lost,
for example `git tag archive/twin-chunks-bridge feature/twin-chunks-bridge`.
Then remove the worktree and delete the branch. `git worktree prune` clears the
`/private/tmp` entries already marked prunable. Some worktrees under
`.claude/worktrees` are locked, so check for running agents first.

### Stale merged branches and worktrees

122 local branches are already merged into HEAD, and about 90 agent worktrees
are still checked out under `.claude/worktrees/`. None of them are deprecated
features. They're just clutter, and they can go once the retired branches
above are archived.

---

## 2. Bigfoot as a character (Proposed)

The vision keeps Bigfoot only as a rare ambient event. The earlier Bigfoot
simulation is a large AI and animation system with a personality, a lair, a
cave, routines, mischief, rage, object exchange, tree hugs and wetness. The
lair, the cave and his needs-driven living world were removed on 2026-10-05.

**Keep:**

- `scripts/life_bigfoot.gd`: the rare dusk sighting, driven by `life_moments.gd`.
- `assets/models/zenscape-bigfoot-ambient.glb`
- `feature/ambient-bigfoot` (worktree `.claude/worktrees/ambient-bigfoot`): the
  stooped prop with 8 clips. It isn't wired in yet, but it's the likely future
  of the rare event.

**Proposed for removal:**

- Scripts: `scripts/bigfoot_*.gd` (17 files: breath, crossing_wish,
  environment, fire, habits, leaf_bed, mischief, object_exchange, personality,
  routine, shelter, temper, tree_hug, tree_touch, warm_hands, wetness), plus
  `scripts/reference_bigfoot.gd`,
  `scripts/creature_brain.gd`, `scripts/creature_hand_reach.gd`,
  `scripts/creature_tree_peek.gd` and `scripts/resident_interaction.gd`.
  Check `creature_actor.gd` and `creature_navigation.gd` for the deer and
  heron before removing them.
- Studies: `studies/bigfoot_encounter.gd`.
- Tests: `tests/test_bigfoot*.gd`.
- Tools: `tools/*bigfoot*` (the Blender rig, restyle, animate and film
  scripts). **Keep** anything
  `feature/ambient-bigfoot` still uses to rebuild its model.
- Docs: `docs/bigfoot-*` (9 folders) and `docs/bigfoot-heavy-walk.md`,
  `docs/fidelity-life/`.
- Branches: `codex/bigfoot-*`, `codex/cozy-bigfoot`, `codex/resolve-pr10`,
  `feature/bigfoot-patterson-walk`, `feature/hide-cave`.

**Still wired into the live product.** Untangle these before deleting:

- `studies/diorama.gd` → `fidelity_life.gd` (Bigfoot references in both).
- `scripts/cozy_regrowth.gd` → `creature_actor.gd` → `bigfoot_personality.gd`
  (6 references in cozy_regrowth).
- `scripts/native_chunk_editor.gd` → `native_garden_landmarks.gd` →
  `studies/bigfoot_encounter.gd` → `reference_bigfoot.gd`.
- The `--force-bigfoot` flag.

---

## 3. Destruction, explosives and god mode (Proposed)

Blowing up mountains, tunnels, chasms and physics mischief don't fit a relaxing
building game.

- Scripts: `native_explosives.gd`, `explosive_asset.gd`,
  `explosion_effects.gd`, `terrain_blast.gd`, `internal_blast.gd`,
  `native_blast_preparation.gd`, `mountain_collapse.gd`, `native_tunnels.gd`,
  `native_chasm_mesh.gd`, `chasm_glade.gd`, `native_chunk_hull.gd`
  (the blast hull), `world_rumble.gd`, `reference_tremor.gd`,
  `native_drop_reactions.gd`.
- Mischief and loose props: `play_loose_body.gd`, `play_loose_props.gd`,
  `play_spring_tree.gd`, `play_water_mischief.gd`, `world_loose_body.gd`,
  `world_loose_props.gd`, `world_spring_tree.gd`, `world_water_play.gd`,
  `diorama_world_play.gd`.
- Tests: `test_native_explosives`, `test_explosive_landscapes`,
  `test_internal_blast`, `test_mountain_collapse`, `test_native_tunnels`,
  `test_threaded_destruction`, `test_chasm_terrain`, `test_creature_void_fall`,
  `test_creature_tremor`, `test_fidelity_tremor`, `test_loose_prop_cursor`.
  **Keep** `reference_tremor.gd`: the shaping tools' rumble
  (`clay_tremor.gd`) kicks it now.
- Docs: `docs/terrain-destruction`, `docs/chasm`.
- Branches: `codex/terrain-destruction`, `codex/god-mode-playground`,
  `jolt-blast-debris-water`.

**Still wired in:** `native_chunk_editor.gd` has about 30 explosive and 8
blast references. `garden_view.gd` has 7. `studies/diorama.gd` pulls in the
play and mischief chain through `diorama_world_play.gd`.

**Check before removing:** the drop reactions (`native_drop_reactions.gd`)
might be part of the water ball splash.

---

## 4. Wildfire (Proposed, needs a decision)

The wildfire simulation (PR #5, `docs/fire/DESIGN.md`) isn't in the new
vision. Keeping it as a rare weather event could fit, the same way Bigfoot is.

- Scripts: `fire_field.gd`, `fire_effects.gd`, `fire_look.gd`,
  `fire_material.gd`, `bigfoot_fire.gd`.
- Tests: `test_fire_*` (five files). **Not** `test_fireflies.gd`: fireflies are
  ambient life and stay.
- Tools: `film_fire*.gd`, `profile_fire.gd`.
- Branches: `feature/fire`, `feature/fire-*`.
- Wired in via `native_chunk_editor.gd`, `garden_view.gd` (10 references) and
  `studies/fidelity.gd` (28 references).

---

## 5. Crossing and route experiments (Proposed)

These came from the bridge and crossing era: log walkways, stepping stones,
the crossing glade.

- `scripts/crossing_glade.gd` (still reached from `studies/diorama.gd`),
  `log_walkways.gd` (reached through `fidelity_habitat.gd`),
  `stepping_route.gd`, `creature_route_query.gd`.
- Tests: `test_log_walkways`, `test_stepping_route`.
- Tools and docs: `tools/render_crossing_glade.gd`, `docs/crossing-glade`.

---

## 6. Dead study scenes and prototypes (removed 2026-10-02)

Removed on branch `cleanup/dead-code`: the sandbox (`scenes/sandbox.tscn`,
`sandbox.gd`, `terrain_view.gd`, `orbit_camera.gd`, `garden_look.gd`,
`garden_weather.gd` and their shaders), `cozy_flow_prototype` with
`cozy_chunk_prototype.gd`, `nursery_preview`, `open_meadow`, every
`prototype_*` study, script and shader, `redwood_forest`, `visual_benchmark`
with `benchmark_planar_water`, `wind_playground` with `wind_demo_landscape.gd`,
the Bigfoot life, lighting, living-world and playground studies, the god mode
and destruction playgrounds, the bear and the older Bigfoot model passes, the
materials-tray specimen SVGs, their launchers, tests, tools and docs.

Corrections to the earlier list, all of which stay:

- `run-cozy-flow.command` is the live launcher: it opens `cozy_worlds.tscn`.
- `scripts/title_showcase.gd` is live (`cozy_worlds.gd` loads it).
- `shaders/lake_reference_water.gdshader` is live through
  `assets/zen_reference/geometry.scn`.
- `studies/diorama.tscn`, `fidelity.tscn` and `fidelity_life.tscn` are
  unreachable from the game but are the harness scenes of many tests and
  tools. Their scripts are the game's ancestors (`cozy_worlds.gd` →
  `diorama.gd` → `fidelity_life.gd` → `fidelity.gd`).
- `art/blender/bigfoot/zenscape-bigfoot-classic.blend` and
  `assets/models/zenscape-bigfoot-classic.glb`:
  `tools/animate_bigfoot_interactions.py` builds the interactions model the
  creature tests load from them.
- `docs/bigfoot-scale`: `tools/open_woodland.gd` opens its `woodland.json`.

The look references stay: the Fidelity scene is the aesthetic bar, see
`docs/fidelity`.

---

## 7. Old editors and A/B flags (Proposed)

Genesis is now the only way to create. These keep the older paths alive:

- `--classic-build` in `studies/cozy_worlds.gd`: the pre-Genesis build editor.
- `--garden` in `studies/fidelity.gd`: the old garden editor (its
  `run-garden.command` launcher is gone). `selection-garden.json` at the root is
  its demonstration save, written by `tools/capture_selection_garden.gd`.
- `--classic-trees`, `--classic-life`, `--classic-grass`, `--classic-rocks`,
  `--classic-palette`: A/B switches from the look passes. Once the new versions
  are accepted, the flags and the classic code paths can go.
- The editor UIs they carry: `native_build_panel.gd`,
  `native_build_palette.gd`, `native_selection_panel.gd`,
  `landscape_preset_editor.gd`, `scene_look_editor.gd`,
  `tree_motion_tuner.gd`. Check each one against Genesis before removing it.

---

## 8. Loose files

- About 45 untracked `*.gd.uid` files in `scripts/`, `tests/` and `tools/`.
  Commit them or delete them along with their scripts.
- `tools/blender_trees/__pycache__/` should be gitignored.

---

## Suggested order

1. Archive-tag, then delete, the retired branches and worktrees in section 1.
   Nothing in the tree changes.
2. ~~Delete the dead study scenes and prototypes in section 6.~~ Done
   2026-10-02.
3. Decide on fire (section 4) and the classic flags (section 7).
4. Untangle `studies/diorama.gd`, `native_chunk_editor.gd`,
   `cozy_regrowth.gd` and `garden_view.gd` from Bigfoot, destruction and fire.
   Then delete sections 2, 3 and 5 along with their tests, tools and docs.
   This is the real work: `native_chunk_editor.gd` alone is 2,230 lines.

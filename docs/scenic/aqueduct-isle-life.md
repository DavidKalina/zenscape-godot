# Aqueduct isle: life (handoff)

Branch `look/aqueduct-isle-life` (from main). Not merged, not pushed. Run it with `./run-aqueduct-isle.command`.

The brief was to make the isle feel less empty using only systems the game already has. No new creatures or systems were made. Everything is on by default, and each part has its own opt-out flag.

## Where it lives

- `studies/aqueduct_isle_life.gd` is the owner node. It reads the isle's ground into a 0.6 m grid once (`ground_at`, `standing_at`, `grass_at`), then sets up each part and advances it every frame.
- `studies/aqueduct_isle_undergrowth.gd` grows the undergrowth.
- `studies/aqueduct_isle_birds.gd` runs the songbirds on the stones.
- `studies/aqueduct_isle_tokens.gd` holds the on-foot tokens.
- `studies/aqueduct_isle.gd` changes are small, so they merge easily with `look/aqueduct-isle-sky`:
  - one `const Life` line;
  - an `_add_life()` call in `_ready`;
  - `life.advance(delta)` in `_process`;
  - `life.step_pilot()` in `tick`;
  - `life.advance` in the `--capture` settle loop;
  - a header note;
  - a self-contained block at the end of the file (`var life`, `_add_life`).
- Test: `tests/test_aqueduct_isle_life.gd` (headless). It passes. `tests/test_aqueduct_isle.gd` also still passes.

## What was added

| Part | Reused system | How it's wired here |
|---|---|---|
| Undergrowth | The game's fern and shrub (`undergrowth_mesh.gd`), mushroom, mossy log, leaf bed: the plate catalog's parts | Plant records drawn through `Flora._draw`, so they sway, part for the pilot's wake and follow the look presets' seasons. They gather at what stands (a ring probe 2.4 m round finds something that isn't open turf) and under the rims, plus 12% scattered elsewhere. Never on the worn paths. About 275 ferns, 170 shrubs, 190 mushrooms in clusters, 26 leaf beds and 5 logs. |
| Butterflies | `scripts/life_butterflies.gd`, unchanged | One per flower patch: the 4 fullest 16 m tiles of the isle flora's meadow flowers, each with a `Meadow` owner (LandLife's interface: survey, material, clock). This gives about 28 butterflies. They leave in snow and autumn presets, in rain and at night. Their batches are re-boxed round their patch, because the plate's box sits at the origin. |
| Fireflies | `studies/fireflies.gd` and its shader | 70 over the ferns, shrubs and logs, lit only at dusk and at night (try a night preset with L). |
| Songbirds | `songbird_body.gd` and the numbers from `songbirds.gd` | See below. |
| Breeze ribbons | `scripts/breeze_ribbons.gd`, through `Atmosphere.setup_wind_trails` | They ride the gust fronts, including B. They are bounded round the camera, as the fronts are. They are lifted over the ruins (the ground grid's "standing" cells act as a canopy), and over the sky they keep to the islands' height. Their published heads bow the grass and the vines. |
| Leaf litter | `scripts/wind_leaf_litter.gd` | 96 leaves at the feet of the castellum, blind wall, heel stone and gate, and by the shrubs and logs. |
| Grass chaff | `scripts/wind_grass_chaff.gd` | About 70 on the east meadow. |
| Kicked blades | `scripts/wind_kicked_blades.gd` | Plucked from the grass under a sweeping ribbon. |
| Tokens | `glyph_pickup.gd` (calm "foot" tokens) and `collectibles_hud.gd` | 7 tokens, one line of "wildflower" glyphs. The blip climbs with each pickup, and the flourish plays on the last. The HUD shows the count and pips (n of 7). |

### Songbirds on stone

There are 4 flocks with 14 birds in total:
- 5 sparrows at home on the aqueduct;
- 4 goldfinches on the circle's lintels;
- 2 robins on the castellum;
- 3 sparrows at the gate and the stumps.

Perches are found in the physics space: a ray down onto a flat top at least 0.7 m over the turf (or over the sky), with room above it. There are about 123 perches in 6 groups: aqueduct parapets and lips, castellum, circle lintels and the floating sarsen, heel and east stones, gate and stumps, and the drift and south stones.

Each flock keeps within 5 m of a focus perch, so it reads as one flock. What the birds do:
- They sit 9–22 s, glance about and flick their tails.
- They hop along to a free perch (45% of the time), drop to the turf to forage in hops and pecks, or flit within the group.
- They flush when the pilot comes within 3.6 m (5.5 m at a run), when the plane passes within 14 m, or when a B gust reaches them. A flushed flock wheels, then settles in another group at least 12 m from him.
- 18–35 s later, once he is 14 m from home, they come back home.
- They roam by themselves every 80–180 s.
- They fly off at dusk and come back in the morning.

## Flags

- `--no-life`: all of it.
- `--no-undergrowth`
- `--no-butterflies`
- `--no-fireflies`
- `--no-birds`
- `--no-wind-life`: ribbons, leaves, chaff and blades.
- `--no-tokens`

## Tokens: where, and the move each asks for

Each token was driven headless as a player would, and each is taken. Each stands in open air, and where turf lies under it, it is out of a pump jump's reach.

| # | Name | Where (world) | Move |
|---|---|---|---|
| 1 | slot | 97.9, 33.9, -2.6 | Wall-kick up the slot between the castellum's high step and the blind wall. |
| 2 | wallrun | 101.66, 33.45, -4.9 | A running jump into a wall run along the blind wall's east face. It is 3.45 m up, so a pump jump can't reach it. |
| 3 | span | 100, 35.65, -33.7 | Run off the snapped end of the fallen span without jumping, take it as you sink, then twirl up to the far lip. A normal jump over the gap passes above it. |
| 4 | sarsen | floating `ring_sarsen` + 0.85 m | A twirled jump from the ring's lintels onto the floating sarsen over the bite. |
| 5 | trilithon | great trilithon top + 0.85 m | Climb onto the ring's lintels, then jump up from the back lintel onto the great trilithon, the isle's summit. |
| 6 | drift | under the north lip of `drift_3` | Step off the lintel's north edge, hang, and shimmy along. Falling past it also takes it. |
| 7 | stumps | 92, 31.25, -39.3 | From the far island, a running jump out over the sky to the first stepping stump. |

Positions are computed in `Tokens.spots()`. The drift and stone ones follow `Art.platforms()`.

## Skipped, and why

- **Dragonflies.** The isle has no still water, only the channel's running film and its spill.
- **Snakes** (`life_snakes.gd`). They need a pond with banks and pond life.
- **Woodpecker.** It needs snags (dead trees), and the isle has no trees.
- **Geese.** Banned.
- **Pollen** (`pollen_cloud.gd` / `pollen_wind.gd`). This is the forest brush's released veil and needs the editor and emergence. There is no passive pollen system to reuse.
- **Moss cushions.** There is no standalone moss asset. The mossy log carries the log-moss part, and the ruin kit's own moss and tufts remain.
- **"Something on the warm stone"** (a basking lizard). No such creature exists in the game. Adding one would be a new creature.

## Cost

- **Setup.** About 150–200 ms: ground grid about 40 ms, undergrowth about 35–80 ms, birds and wind under 10 ms.
- **Frame time.** The rendered `--capture` frame time stayed at about 16.7 ms (capped) in the start view, against 16.7 ms with `--no-life`. It was about 20 ms in two wide views over the castellum. Draw calls rose from about 110 to about 200–300, mostly the undergrowth tiles (122 multimeshes) and the birds (each songbird is a few mesh instances with its own material, as in the game).
- **Triangles.** The undergrowth draws at most about 170k instanced triangles (fern and shrub tiles fade out at 65 m).

## Tuning knobs

- **Undergrowth.** `KINDS` (per-m² density and size), `LOGS`, `FOOT`, `OPEN_KEEP`.
- **Butterflies.** `PATCHES`, `PATCH_FLOWERS` (5 flowers per butterfly).
- **Fireflies.** `FIREFLIES`, `FIREFLY_HEIGHT`.
- **Wind.** `LEAF_ANCHORS`, `CHAFF_MEADOW`. Ribbon strength comes from the game's own `--ribbon-*`, `--wake=` and `--sweeps=`; front strength from `--fronts=`.
- **Birds.** `FLOCKS`, `SIT`, `HOP_SHARE`, `FORAGE_SHARE`, `FIGURE_NEAR`, `RUN_NEAR`, `PLANE_NEAR`, `GUST_FLUSH`, `HOME_AFTER`, `ROAM`, `FOCUS_REACH`.
- **Tokens.** Positions in `spots()`, plus `GLYPH` and `SIZE`.

## Open

- **Not judged at length by eye.** Undergrowth and leaves read well at the ruins' feet. The birds are game-sized (15 cm), so from the walker's camera they read mostly in flight. Bigger birds, or a perch group nearer the start, would make them easier to notice.
- **Butterflies, fireflies, the token glow and the ribbons were not captured.** Their visuals have not been checked rendered.
- **The night was not captured rendered.** Fireflies were checked headless only (activity 1.0 in Nordic night).
- **The gate group has almost no foraging turf** (1 spot). Its sparrows mostly perch.
- **Tokens are not saved.** They are laid again each run, and R doesn't reset them. There is no persistent count in the HUD between pickups. The readout shows only for a moment, as in the sky.
- **The drift token can also be taken by falling past it.** It can't be reached from the ground.
- **Bird counts are random.** Over 20 s about two-thirds of bird-time is spent perched.

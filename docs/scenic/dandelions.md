# The dandelion's round: seed on the air, and life that spreads

Branch `beautification`, 2026-10-02. The user loved the painted flowers and asked for "more particle effects... the dandelions to be able to blow off with the wind and maybe regenerate over time... some natural spreading of the flowers". Painting stays the tool (docs/scenic/handful.md "Flower seed"); spreading is what living plants do.

Settled with the user before building:

- **What sheds.** Both airs: the world's breeze peels a seed or two now and then, and the wind tool's gusts strip clocks bare in a soft cloud.
- **Coming back.** The real life cycle: a bare stalk, then a gold dandelion on it, then a seed clock again.
- **How far it spreads.** It creeps from the drifts. A few seeds take on open ground near flowers already standing, so meadows feather out a few metres. Ground the hand thinned stays clear for a while.
- **Scope.** Dandelions first. Pollen glints and slow spreading for the other kinds are a second pass.

## What happens

`scripts/dandelion_seeds.gd` (`DandelionSeeds`, made by `NativeChunkEditor._setup_dandelions`, under the terrain node) keeps every seed clock's state and the seeds in the air.

- **The breeze peels.** About once every 80 s (`PEEL`), a clock in air that drifts pollen at 1 m/s (`PEEL_AIR`) loses one or two seeds. The rate goes with the square of the air, so calm hardly moves them and a gale strips quickly. The air is pollen's (`scripts/pollen_wind.gd` `at`: the atmosphere's strength, swell and gust parcels, plus any wind-tool gust). At the default dial a clock is bare in the better part of an hour.
- **A gust strips.** Where the wind tool leans the plants hard (`WindGust.blow_at`: its lanes, bursts, the blowing hand and the Feather's wake), a clock loses up to `STRIP` (4.5) of its seeds a second. That ramps from a lean of 0.25 to 0.85 (`STRIP_LEAN`). A full lane through a drift strips it as it passes. Holding the blowing hand still over clocks fluffs them off bit by bit, like blowing on a real one.
- **The round.** When its last seed goes, a clock stands bare for `BARE` (30 s), plus up to `BARE_JITTER` (25 s) so a stripped patch comes back plant by plant. Then a gold head pops open (an easeOutBack over 1.2 s) and holds for `GOLD` (55 s), closes over `CLOSE` (2 s), and the clock fluffs out over `FLUFF` (5 s), seed by seed in its rank order.
- **The seeds** lift off the head and take up the air over about half a second (`FOLLOW`). They sink at `SINK` (0.32 m/s) less a little lift in moving air (`LIFT`), bob on their own eddies, and keep under `CEILING` (5 m). A seed fades over `SETTLE` (1.4 s) where it lands, or as it leaves the land. At most `SEEDS_MAX` (360) fly at once. A stripped clock sends a fifth of its seeds as motes (`STRIP_SHOWN`); each mote carries the others' chance of taking.
- **Some take.** A landed seed takes with chance `TAKE` (0.12, times its weight), at most one every `SPREAD_GAP` (3 s), and only where all of these hold:
  - the flower brush could paint there (`FlowerSowing.suits`: no water, rock, snow, steep ground or shade);
  - `ROOM` (0.22 m) is clear of any plant;
  - a kit flower stands within `CREEP` (3 m);
  - fewer than `CROWD` (5) stand within 0.8 m, so a full core does not stack;
  - the hand has not thinned flowers there (within 1 m) in the last `CLEAR_HOLD` (900 s);
  - the land holds fewer than `MOST_FLOWERS` (5,500) kit flowers;
  - no stroke is open and no world is forming (`held`).

  What comes up is the dandelion slot's mix: a dandelion, or a seed clock 37% of the time (`CLOCK_SHARE`), sized by its meadow type. It is an ordinary record with `source: "emerged"` and a `born` stamp. It is drawn at once through the paint preview, grows in with the shared pop, and is saved like any emerged plant.

Measured headless (`tests/test_dandelion_seeds.gd`): a 3 m drift in a steady 1 m/s breeze grew about 11 plants in 15 minutes, the furthest 5.7 m from its middle. A gust's seeds mostly fly 5 to 10 m, past `CREEP`, so a gust spreads little. The slow, steady creep comes from the breeze.

## Drawing it without a rebuild

The record never changes: a stripped clock is still a `dandelion_clock`. The material draws the whole round from one number per clock.

- **State in the instance alpha.** `GardenView.set_flower_state(id, state)` writes it into the clock's instance colour alpha, live and in the paint preview, and writes it again after every publish (`_index_fire_parts`), as fire state is. Its meaning:
  - 1: whole;
  - 1 + f: a share f of its seeds blown;
  - 4 + t: gone bare at t on Emergence's clock (`zs_emergence_time`).

  The vertex alpha of the kit's meshes is 1, so the shader reads the instance's alpha exactly. Clocks have no colour variants, so the variant code's alpha (under 0.5) never meets it.
- **Parts in the mesh.** `MeadowFlowerMesh` builds the clock with each head vertex's part in `CUSTOM0.w` (`ROLE_*`):
  - 2 + rank for each of the 42 parachutes (a shuffled order, so a thinning clock thins all over);
  - 4 + r for a gold head on the same neck (the dandelion's florets, drawn 1.5×);
  - 6 + r for the core;
  - 8 + r for the folded bracts.

  The clock's look is unchanged. It is now 286 triangles (was 202) and 389 vertices; the gold head's 137 vertices are folded away while it stands whole.
- **Shader** (`flower_cycle`, `flower_cycle_times`, a block after the distance thinning in `shaders/reference_surface.gdshader`):
  - a seed whose rank is under f folds into the neck, and comes back in rank order as the clock fluffs out;
  - the gold head pops and folds;
  - the core shrinks toward a small tan nub as the seeds go (0.42 of its size, bare), and tucks away with the bracts under the gold.

  A folded vertex skips the rest of the vertex stage, like a dropped far plant. No varyings are added.
- **The seeds** are one MultiMesh (`shaders/dandelion_seed.gdshader`), uploaded as a single buffer each frame. Each is a camera-facing soft tuft: faintly rayed hairs round a bright heart, a dark speck of seed, drawn out a touch along its way. They are lit by the scene's light and glow toward the sun.

## Cost

- **Main thread, per frame** (rendered, `tools/still_dandelions.gd`, M5 Pro): 0.05–0.1 ms with clocks and no gust. While a full gust strips 105 clocks with 360 seeds in the air, the worst frame was 0.5–0.7 ms. That was 2.4–2.9 ms before the ground under each seed was cached per 0.5 m cell (`ground_at`); `ground_height` costs 4.7 µs a call.
- **Reading the land.** It reads the land again the step after a publish, and only when the objects changed (`objects_revision` and count). On a 4,500-flower meadow that read costs about 4.4 ms. A take updates the index itself, so the publish it causes does not read the land again.
- **GPU.** Dandelions meadow (`tools/film_breeze.gd --land=dandelions --seconds=0 --probe`, 1280×720, vsync on):
  - frame median 20.0–20.2 ms, against 19.6 ms with the mesh and shader from before;
  - 1.50 M primitives, against 1.37 M;
  - without flowers, 16.7 ms (the vsync floor), so the flowers' own share is not resolved finer than that.

## Checks

- `tests/test_dandelion_seeds.gd` (headless) checks:
  - the mesh's parts and ranks, and the material's switch;
  - still air sheds nothing, and a breeze peels a few seeds and strips no clock;
  - seeds ride downwind and land;
  - a gust strips the clocks under it bare and spares the rest, under `SEEDS_MAX`;
  - a bare clock comes round to whole;
  - a restore clears the round and the air;
  - every taking rule above;
  - a drift creeps over 15 minutes of breeze;
  - in the cozy scene, the editor's wiring, drawing at once, no take into an open stroke, and save and reopen.
- `tools/still_dandelions.gd` (rendered, `--no-title`) shows a drift whole, in bands of every phase, all bare, and all gold. It then sends a lane through it at 0.6, 1.1, 1.8 and 3.5 s, and gives a far view. Frames go to `captures/dandelions/`. `--bench` prints the per-call costs of the air, the gust lean and the ground.

## Not verified

- Motion over time: only stills were taken, no film. The rise of the gold head and the fluffing out have not been watched.
- Seeds at dusk and at night, and the backlit glow looking into the sun.
- A whole dandelions meadow under the default breeze for a long session: how fast it visibly cycles and creeps.
- Undo after spreading: as with emergence, undoing a stroke restores the land from before it, which takes back plants that came up since.

## Open

- Pollen and spreading for the other kinds (the second pass the user asked for): faint pollen glints off heads in the breeze, and slow creep for daisies, poppies and cosmos.
- The old `--meadow-flowers` remap draws `umbel_flower` records as clocks, but those do not go round.
- Nothing ever dies back, so a meadow only grows; `MOST_FLOWERS` and `CROWD` are the brakes.

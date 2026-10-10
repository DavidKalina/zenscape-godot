# Aqueduct isle: handoff

Branch `look/aqueduct-isle` (from main 79398f2e). Not merged, not pushed.

This is the ruins archipelago's aqueduct station (station 2 of `studies/island_packs/ruins_archipelago.gd`) built on its own as a standalone scene. It uses the gothic ruin kit and the game's real noon look, and you play it on foot as the pilot.

## Run

```sh
./run-aqueduct-isle.command
godot --path . res://studies/aqueduct_isle.tscn -- --no-title
```

- **Start.** The pilot starts at the foot of the rubble slope. **R** puts him back there.
- **Recordings.** F5 records. F6 replays the station's own route recordings (the two `ruins-2-*` runs in `studies/character_runs/`), and F7 goes to the older one. F8 draws every path.
- **Other keys.** F1 shows the numbers, F2 opens the feel sliders, Esc releases the mouse. All the character study's moves work.
- **Captures.**
  - `--capture=out.png` saves a frame after the sky settles, then quits.
  - Add `--at=x,y,z --look=x,y,z` for a free camera.
  - Add `--place=x,y,z[,turn]` to start the pilot somewhere else, seen from the walker camera. `turn` is degrees clockwise from facing −z.

## What's in it

- **`studies/aqueduct_isle.gd`.** Extends `studies/character_study.gd`, so the pilot, camera, moves, recorder and replays are the study's own.
  - It loads the pack and keeps station 2 only.
  - The station's boxes become invisible collision. The island slabs and the moss pad are dropped because real islands replace them.
  - It builds the art and lights the scene the way the ruin kit gallery does: `LandscapeLighting`, `Celestial` with the gallery's `GAME_LOOK` at `DAY`, and `LookPass`, which adds the cloud sea, cloud volume and grade.
  - Headless, the look is skipped and only a plain sun is used.
- **`studies/aqueduct_isle_art.gd`.** All the art, in world coordinates. The aqueduct's middle line is x 100 and the island tops are at y 30, as in the station.
  - **Aqueduct.** Built from the kit's own parts at the greybox numbers:
    - `Aqueduct._pier`, `RuinKit._arch_ring`, `RuinKit._courses`, `Aqueduct._deck` and `Aqueduct._spill`.
    - Hanging piers with broken feet and ivy, and two walled-up arches in the blind wall.
    - The fallen span: springers and ragged stubs remain, and the channel's water spills through the gap into the sky.
    - The 30° slope is the fallen end's slabs laid in the slope's plane over a heap of courses. The far end's 1.2 m drops are coursed rubble.
    - The kit aqueduct's stone is drawn only; its hulls are discarded.
  - **Channel water.** A new shader, `shaders/aqueduct_channel.gdshader`, because the islet pond shader is a still tarn and read flat navy. This water flows down the channel with ripples, streaks riding the current, edge foam, sky fresnel, a glint and some transparency over the bed. It is also a 6 cm wading pool in `PilotPhysicsGround.pools`, under `WADE_FROM`, so it never slows him: the feet splash and leave ripple trails, and the steps sound wet.
  - **Islands.** Two islands with authored, jittered outlines, about 57 × 42 m and 31 × 26 m.
    - The turf is faceted (a Delaunay triangulation over a jittered 2 m grid) with three gentle grassy rises kept away from the routes.
    - Under the turf, the sides drop through an earth lip and banded rock rings to a faceted keel with spurs, about 30 m and 20 m deep.
    - The turf collides as its own trimesh.
    - This is a cheap builder of my own, not `island_shore.gd`/`sky_islet.gd`. Those are tied to `NativeTerrainData` and the plate grid, and the station's routes need a top that is exactly 30.
  - **Castellum (the summit).** A 4 m square water tower at the aqueduct's head.
    - Its crown is 7.8 m up, the highest stand on the isle, with a view over the cloud sea.
    - Its south-east quarter has fallen in steps of 1.6 m (`SET_OFF`): 1.4, 3.0, 4.6 and 6.2 m.
    - Its east face is 1.8 m off the aqueduct.
    - It uses clean box collision under coursed stone.
  - **Stumps.** Three broken piers of an older arcade, floating in the sky west of the aqueduct and coursed, with tufted tops. They are a second way between the islands.
  - **Playground.** 19 kit pieces collide through their own hulls (see `PIECES` in `aqueduct_isle.gd`):
    - **West:** a stair, three cloister walls, three broken piers, a fallen pier, a tomb chest, a vault bay and a lancet wall.
    - **East:** the rose gable, a buttress, a wall and a fallen pier.
    - **Far island:** the arch as the gate, two piers and floor slabs.
  - **Grass.** Tufts in drifts, in lighter living greens (`_tuft`) so they don't read as dark shards.
- **`tests/test_aqueduct_isle.gd`** (headless, about 4 s). See Checks.
- **`run-aqueduct-isle.command`.**

## Deviations from the greybox numbers

Every walked and caught number of the station stands: its own boxes collide.

The art differs from them as follows:

| Station | Here |
|---|---|
| Channel top flat 2.4 m at 6 m | The same top. The deck slabs stand 5 cm proud on each side. Parapet stones (0.42 m high, 0.4 thick, ±0.95 m off the middle, broken in runs) now collide as clean boxes. Under STEP_UP, they are stepped over. They are kept off the east side over the blind wall (world z +1 to −16), where the kicks catch the lip, and off the 3 m gap. |
| Arches 4 m wide, 4 m clear, spandrels from 4 m | Pointed drop arches (radius 0.75 of the span) with the crown at 4 m, springing at 1.17 m. The haunches below 4 m are new clean boxes inside the arch ring (3 steps a side), so a walker under an arch doesn't stand in the stone. |
| Piers 2 × 2.4 m | The same size. The kit pier is 1.7 × 2.8 m. |
| Spandrel faces at ±1.2 m | Drawn at ±1.06 m, set back 0.1 m behind the piers' strips. The blind wall is flush at ±1.18 m, because it is the wall-run face. |
| Hanging piers' feet at 21 / 19 / 20 m | The same, with ragged stones hanging up to about 1 m below (drawn only). |
| Water: none | A 6 cm film from the head to the snap. It is a wading pool in the motor too, but under `WADE_FROM`. |
| Island slabs 28 × 34 and 24 × 22 m, moss pad | Irregular islands about 57 × 42 and 31 × 26 m, flat at 30 within 7 m of the aqueduct's line, with gentle rises (up to 1.6 m) elsewhere. |
| — | New: the castellum, the stumps, the rubble heap beside the slope (kit hulls, west side; three tiny stones east that don't collide) and the 19 kit pieces. |

## Free play: lines found and tested

**By the test bot** (`tests/test_aqueduct_isle.gd` `_free_play`), all passing:

- **Summit, three ways:**
  - Up the castellum's fallen quarter from the ground, 1.6 m a step, to the crown at 7.8 m.
  - From the channel, a running jump across 1.8 m to the 6.2 m step, then up onto the crown.
  - Wall kicks up the slot between the castellum and the blind wall to the channel (4 kicks).
- **Summit back down:** a twirled jump off the crown down onto the channel, or a running jump from the 6.2 m step back to it.
- **The loop back:** from the far island over the three stumps to the near island. The two long gaps (3.4 and 3.0 m) need a twirled jump; the two short ones (2.0 and 1.9 m) a running jump. With the aqueduct, this makes a loop: slope → channel → fallen span → far island → stumps → home.
- **Cloister:** up the kit stair onto the first wall (about 2.2 m), a running jump to the second, along it, and a twirled jump to the third.
- **Piers:** running jumps along the three broken piers' heads (about 2 m up).

**By a scratch explorer bot**, passing but not kept in the test:

- Running jump off the fallen pier.
- Climbs onto the lancet window's sill (1.6 m).
- Up the kit buttress's set-offs to about 3.9 m.
- Onto the east wall's top.
- Onto the far gate arch's lower parts (about 1.9 m).
- From the ground onto a cloister wall: walk, jump and climb.

**Not reached or not tested:**

- The vault bay's tops: the bot couldn't climb it.
- The rose gable: its eaves at 5.2 m are untried.
- The lancet wall's crest at 7.8 m.
- The far island's piers: one jump from the ground misses; a pump is untested.
- The first broken pier from the ground: needs the pump; untested.

Long jump chains, slide hops and wall runs on open ground are untested. The near island has 30–50 m of open turf runs west of the aqueduct and along its east side.

## Cost

- **Triangles:** 342,108 drawn in all (islands, aqueduct, castellum, stumps, 19 kit pieces, growth). The test caps it at 900k.
- **Load:** the scene builds in about 3.3 s headless.
- **Collision:** the kit pieces' hulls are not merged (19 bodies).

## Captures

Saved in `captures/aqueduct-isle/` in the main checkout (ignored by git):

- `1-establishing.png`
- `2-summit.png`
- `3-channel.png`
- `4-arcade.png`
- `5-gap.png`
- `6-stumps.png`

## Weak

- **Squat aqueduct.** It is 6 m to the channel, per the greybox, against the kit's 10.8 m that the user called "amazing". It reads heavier and lower, and the drop arches spring at 1.17 m, so the piers are stubby. Taller piers would mean new route numbers.
- **Water.** It flows and reads glassy from above. At grazing angles it is pale and frosted, and it starts abruptly at the head with no source. The spill is the kit's thin strand and reads well from the side (6-stumps), but is barely visible from on the channel.
- **Islands.**
  - The turf is big flat facets in one green, with no flowers. The tufts are still sparse.
  - The keel is a simple cone of rings, not the game's real shore and strata. Its underside is dark.
  - The island builder is new code, not the game's island pipeline.
- **Playground composition.** It reads scattered rather than as one abbey. The west quarter needs a stronger plan (a cloister square, a nave line). The rose gable and vault are backdrop more than play.
- **Castellum.** Its tops are plain coping slabs. Its art is a few cm off its clean boxes in places.
- **Not flyable.** No plane is wired in.
- **HUD.** The hint bar still lists station keys 1–9, but only 2 does anything here.
- **Look tests.** Headless runs skip the look. Nothing in the test checks the rendered look; captures only.

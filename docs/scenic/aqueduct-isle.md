# Aqueduct isle: handoff (round 3)

Branch `look/aqueduct-isle-3` (from `look/aqueduct-isle-2` 74225ff7). Not merged, not pushed. Round 3 is the stair only: the user's three issues were falling through the stair, the pilot and camera vibrating on it, and the static grass. Mid-round the user held the grass (item 3) and asked instead why the stair "still doesn't look quite right".

## Falling through (fixed in the kit)

- **Root cause.** The motor's ground is one ray straight down from the feet (`scripts/pilot_physics_ground.gd`). The stair's treads were its drawn blocks' own convex hulls: a slab or two per section, each settled, tilted, chipped, with a chunk sometimes bitten from the top, 12–16 mm apart, and Jolt rounds every hull's edges by its 0.04 m margin. A headless probe grid over the grand stair found **20,729 of 79,310 points (26 %)** where the ray fell past the tread, 8,450 of them straight through to the turf, along every tread joint, every slab joint and across the chunk-bitten slabs. Once the feet's ray drops through, the motor falls, its body cylinder (from 0.5 m up) already overlapping the treads, so he sinks through the stair. The cheeks had the same fault: course joints and the odd courses' missing first stone left pits to the ground along their tops. A diagnostic drive (360 approaches) failed 249 of them.
- **Fix (`scripts/ruin_kit.gd` `_flight`, so every kit stair gets it).** The drawn treads, cheek courses and copings get no hull. The stair walks on clean invisible hulls instead: `_walk_box` gives each step one box the flight's full width, its top true, from its nose back past the flight's back (`WALK_OVERLAP` 0.05 m, so the boxes overlap and flights meet seamlessly). `_walk_hull` gives each cheek course and coping its un-worn, un-chipped, un-settled planes. The odd cheek courses now start with a short stone instead of leaving their first 0.35 m out.
- **Result.** 0 of 79,044 tread probes off the tread's top; no pit along either cheek; 0 of 360 driven approaches (9 slants from −50° to 50°, 5 lines across, up and down, walk and run, jumping and not) ever under a tread or off the isle.

## Vibrating (fixed in the study)

- **Root causes.** (1) The motor stands the feet on each tread in turn, so `feet.y` pops a riser (0.28 m then, 0.187 m now) in one frame. The figure was drawn exactly at the feet, so it popped too: the most a frame's rise changed frame to frame was **0.28 m**. (2) The camera's look point eased toward feet + 0.8 m, but its distance came from a single ray, which jumps from one stair nosing to the next as it sweeps over a stair behind the pilot. Walking down, the camera's frame-to-frame change in rise was **0.053–0.072 m**, distance jumps up to 0.12 m a frame.
- **Fix.**
  - `scripts/pilot_step_smooth.gd` (new, presentation only; the motor, its routes and replays are untouched) draws the figure and the camera's look point at a height that is the ground averaged along the way he goes (a 13-ray triangle filter ±0.5 m at a run, none standing). Over a stair this is a ramp through the treads, risen into before each riser, so there is no lag. It follows on a critically damped spring told the aim's own rate, never more than 0.3 m off the feet. Off the ground it follows the feet.
  - `studies/character_study.gd`: the figure and camera use `step_smooth.lift`. The camera's reach is a 0.25 m ball cast (`_cam_reach`), whose reach changes smoothly as edges pass. It falls back to the old ray where the ball starts inside something. Letting the camera back out is now a critically damped spring from rest instead of an exponential with a kink.
- **Result** (`tests/test_aqueduct_isle.gd`, up and down, straight and 30° slanted, walk and run). The most a frame's rise changes frame to frame:

  | | Before | After | Test bound |
  |---|---|---|---|
  | Feet | 0.28 m | 0.187 m (they still stand each tread) | — |
  | Figure | 0.28 m | 0.0095 m | < 0.02 m |
  | Camera height | 0.053–0.072 m | 0.0078 m | < 0.015 m |
  | Camera distance | — | 0.0128 m | < 0.02 m |

  The figure is drawn at most 0.112 m off the feet (bound: half a riser + 0.06 m).
- **Not done.** The game's own walker (`scripts/wanderer_eye.gd`) has neither part yet. Its camera code is the study's twin, so the same two changes would carry over.

## Why it looked off, and what changed

Captures are in `captures/aqueduct-isle-3/` (git-ignored): `before/` (round 2's stair, from 74225ff7's kit) and `after/`, the same five views. Re-take them with `zsh tools/stair_captures.sh DIR`. The views are `a-from-foot`, `b-side`, `c-top-down`, `d-onfoot-climb` and `e-far`. The before views were taken with the old foot and climb placements; after, those two are 2 m further east, following the moved stair.

1. **Treads read as a heap of loaves, not steps (changed).** Every tread was chamfered on all twelve arrises, chipped, tilted and often bitten by a chunk, and laid in 2–4 slabs with wandering joints, so no nosing line ran across. Now each tread is laid as the halls' cheap stone (Build `lean`): its top level, chamfered only along the tread, few chips, no chunk. One slab per section, with a joint in only 30 % of sections. Tilt and settle are about halved.
2. **Steps too big for the pilot (changed).** A 0.28 m riser is a quarter of the 1.1 m pilot's height: a giant's stair. The grand stair now has its own finer steps: `GRAND_STEPS` 12 a flight of `GRAND_RISER` 0.187 m by `GRAND_TREAD` 0.42 m, to the same 4.48 m head. Its run grows from 10.0 m to 12.24 m. `STAIR_AT` moves east to x 83.62, so its back still meets the terrace at x 77.5 and its foot is at x 90.3, about 2.2 m short of the castellum. The worn path's first points move to the new foot. The kit `stairs` flight keeps RISER × TREAD; it is shared with the island packs.
3. **Too ruined for a ceremonial way (changed for this scene).** At weathered 0.55 one cheek was torn to rubble, the coping read as a loose rail, and a newel's cap lay as a black lump at the foot. The isle's stair is now `STAIR_WEATHERED` 0.3: cheeks stand, one torn low near its foot, and no cap has fallen. The circle stays at 0.55.
4. **Corner breaks too big (changed).** They were rarer (weathered × 0.25), and keep 65–85 % of the slab.
5. **Cheek courses had notches (changed).** Every other course left out its first 0.35 m stone at the foot of each flight.
6. **Still open:**
   - The castellum's shadow falls across the stair's foot in the noon light, so its lower flight reads dark from the east.
   - The seam down the middle, where the two sections' slabs meet, is still visible on some treads.
   - The cheek's shaded north face is a dark mass from the side (`b-side`).
   - The coping is a thin sloped line that still reads a little like a handrail from low angles.

## Tests (headless)

- **Import check.** Clean.
- **`tests/test_aqueduct_isle.gd`.** PASS. Five new stair checks: tread probes, cheek pits, the 360 approaches, feet pop, smoothness bound, figure offset.
- **`tests/test_ruin_kit.gd`.** PASS. New: every tread of `stairs` and `grand_stair` (3 seeds × weathered 0 and 1) walks at its true top; the grand stair's finer steps reach the kit flight's head and stay under STEP_UP.
- **Also run, touching `character_study.gd`.** These pass: `test_character_study`, `test_character_climb`, `test_character_momentum`, `test_character_tricks`, `test_island_pack_ruins_archipelago`, `test_island_pack_sky_village`. `test_sundered_hall` passes with a classified exit leak.
- **`test_character_recordings`.** FAILS: "tech-fun-fluid-movement" strays at 28.8 s. It fails identically on 74225ff7 without this round's changes, so the failure was already there.
- **Not run.** The full suite (per standing instructions). Nothing was added to `tests/known_failures.txt`.

## The held grass

The held grass work is parked, not merged, on `park/aqueduct-isle-3-flora` (a8f8a8eb). That branch also carries an earlier state of the stair fixes.

- `studies/aqueduct_isle_flora.gd` grows the sky islets' own path: the plate catalog's shader grass tuft, fern, shrub and mushrooms, plus meadow flower drifts, using `GardenInstanceSamples.add_item` and `SkyIslets._plant_material`.
- It is placed by physics rays, so it stays off anything standing, the paths' middles, the stair's foot and head, and the terrace wall.
- Counts: about 6.1k tufts, 176 ferns, 105 shrubs and 177 mushrooms. That is about 590k instanced triangles, and the test budget was raised to 1.2M for it.
- The breeze's offset is published each frame and the pilot's wake (`scripts/pilot_wake.gd`) is wired in.
- It has a test section, and rendered captures in the same captures folder (`1-isle-grass-onfoot.png`, `2-isle-overview.png`, `main-test-island.png` for comparison).

# Round 2

Branch `look/aqueduct-isle-2` (from `look/aqueduct-isle` 0c2749ca). Not merged, not pushed.

The ruins archipelago's aqueduct station (station 2 of `studies/island_packs/ruins_archipelago.gd`) as a standalone on-foot scene, in the gothic ruin kit and the game's noon look.

Round 1 was liked ("I actually really enjoyed it"), but the user found it random: scattered walls, no clear set piece. This round extends the kit with a **stone circle** and a **grand stair**. It also recomposes the isle around three landmarks on one axis and removes the loose walls.

## Run

```sh
./run-aqueduct-isle.command
godot --path . res://studies/aqueduct_isle.tscn -- --no-title
```

- **Start and reset.** The pilot starts at the foot of the rubble slope. **R** puts him back there.
- **Recordings.** F5 records. F6 replays the station's own recordings, F7 goes to the older one, and F8 draws every path.
- **Other keys.** F1 shows the numbers, F2 opens the feel sliders, Esc releases the mouse.
- **Hint bar.** It no longer lists the station keys 1–9.
- **Captures.**
  - `--capture=out.png` saves a frame and quits.
  - Add `--at=x,y,z --look=x,y,z` for a free camera.
  - Add `--place=x,y,z[,turn]` to start the pilot somewhere else. `turn` is degrees clockwise from facing −z.

## Composition

The isle's axis is world z 0. Looking along it from west to east:

- **The henge.** It stands on the near island's new west lobe, which is now about 80 × 42 m.
  - **Terrace.** A round terrace of coursed walling 4.48 m high: 16 straight runs, wall middle 12 m from (65, 0), turfed on top, with four buttresses.
  - **Stone circle.** The kit piece stands on the terrace and faces east. Its lintel ring is at 38.48 m. The great trilithon at its back is at 39.68 m, the isle's highest stand.
  - **Grand stair.** The kit piece climbs the terrace's east face on the axis, from its foot at x 87.6 to the terrace at x 77.5.
- **The aqueduct and castellum.** Unchanged. The castellum stands just east of the stair's foot, so stair, castellum and the aqueduct's head read as one group.
- **The heel stone.** A lone leaning sarsen out east on the axis at (118, 0), 2.3 m tall, so its top is a pump catch. It ties the empty east turf back to the henge.
- **The far island.** Only the gate arch and its paving stay, where the aqueduct comes down.
- **Removed.** The round-1 playground: three cloister walls, the kit stair, the broken and fallen piers, the tomb chest, the vault, the lancet wall, the rose gable, the kit buttress, the east wall, and the far island's two piers. Everything left belongs to a landmark.
- **Worn paths.** The turf is worn dun along paths that join the landmarks:
  - from the stair's foot round the castellum to the start, then on to the heel stone;
  - from the fallen corner along the north edge to the stumps;
  - in a ring round the circle's floor.
- **Turf.** It now drifts between meadow (lighter, yellower) and hollow (deeper) patches instead of one flat green. Wildflowers (cream, buttercup, harebell; faceted, no glow) grow among the tufts.

## New kit pieces (`scripts/ruin_kit.gd`)

Both are in `PIECES` and `NAMES`, in `piece()`, and in a fourth gothic row of the gallery (`./run-ruin-kit.command --family=gothic --piece=13` / `--piece=14`).

- **`grand_stair` (13).** Two of the stair's own flights, one above the other.
  - Each flight is `STEPS` 8 × `RISER` 0.28 × `TREAD` 0.5.
  - It is `GRAND_WIDTH` 4.4 m wide, with a `GRAND_LANDING` 2 m landing between the flights. The head is 4.48 m up.
  - It has cheek walls and newels. When weathered, a cheek is torn on each flight and a newel's cap lies in the grass.
  - Meta `foot` and `head` are the middles of its foot and its head landing.
  - The stair's body is now `_flight(b, pose, steps, width, landing, foot)`. `stairs` calls it and builds byte-identical meshes; I checked this against the old code for 3 seeds × 4 weathered values. Wider flights lay each tread in more slabs.
- **`stone_circle` (14).** The ring has 14 sarsens (`SARSEN` 1.7 × 3.4 × 1.1) at radius 8.5, with 1.3 m-deep lintels cut to the radii, so the ring top is 4.0 m.
  - **Fallen lintels.** `round(weathered × 3)` lintels have fallen. They are never adjacent, and never one that a way up lands on. They lie toppled in the grass and, at weathered over 0.5, cracked.
  - **Great trilithon.** It stands at the back. Its 0.9 m slot is a window on the axis, and its lintel top at 5.2 m is a jump-catch from the ring's back lintel.
  - **Altar stone.** A low slab lies before the great trilithon.
  - **Fallen trilithon.** Its stub (2.5 m) stands 0.25 m in from the ring's lintels. Its partner lies in toward the middle with its top at about 1.05 m, and its lintel lies broken in two.
  - **Leaning stone.** A sarsen has fallen in against sarsen 2 at a 30° slope. Its head rests at 3.25 m, under the lintels, so you walk up it and jump-catch onto them.
  - **Meta `ring`.** It holds `top`, `lintels` (top middle and whether it stands), `fallen`, `trilithon`, `stub`, `lying`, `lean_foot` and `lean_head`.
  - **Helpers.** `_sarsen` (tapered, out of plumb, sunk) and `_toppled_lintel`.
- **`tests/test_ruin_kit.gd`.** It now expects 14 gothic pieces, and `stone_circle` gets the hall bay's 45 m size allowance; its diagonal is about 31 m.

## How to reach each landmark (all proven headless)

**The terrace (4.48 m), three ways:**

- Up the grand stair. It is all walked steps.
- Up the fallen corner on the north face (x 64–66, z −12.6 to −16.6): a heap at 1.5 m, then 3.0 m, then the coping. Each is one jump-catch.
- Up a buttress's set-offs (1.6 m, 3.2 m), then a jump-catch onto the coping. The bot used the south-east buttress; there are four.

**The lintel ring (38.48 m), two ways:**

- Up the leaning stone (walked, slowed by the slope), then a jump-catch onto the lintel over it.
- Onto the fallen trilithon's lying stone, then onto its stub, then a running jump-catch onto the lintel beyond.

**Running the ring.** It runs as a full loop: walked lintel to lintel, with a twirled jump over each fallen lintel (2 at this seed). The jump is about 3.8 m between lintel ends.

**The summit (great trilithon, 39.68 m).** A jump-catch in from the ring's back lintel.

**Still there:** the aqueduct's easy and expert routes and both recordings, the castellum's summit (three ways up, two down), and the stumps loop back from the far island.

## Captures

These are in `captures/aqueduct-isle-2/` in this worktree (ignored by git):

| File | View |
|---|---|
| `1-establishing.png` | From the south-east, high. Henge, stair, castellum, aqueduct, gate and heel stone. |
| `2-circle.png` | The circle on its terrace, the stair coming up on the right. |
| `3-stair.png` | Low view of the stair and the terrace from the castellum's side. |
| `4-onfoot-axis.png` | Walker camera on the worn path toward the stair's foot. |
| `5-from-henge.png` | From over the ring's lintels, looking east at the aqueduct and gate. |
| `g-circle.png`, `g-stair.png` | The new pieces in the gallery, intact and weathered. |

**Legibility check.** In the establishing shot you can name each landmark: "a Stonehenge on a stone platform", "a stair up to it", "an aqueduct with a tower at its head", "a gate on the far island". Round 1's shot read as a field of walls.

## Cost

- **Triangles.** About 377k drawn (round 1: 342k). The test caps it at 900k.
- **Build time.** About 3.5 s headless.
- **Collision.** The terrace walls collide through their kit hulls (several hundred). The terrace top is one trimesh. The fallen corner uses clean boxes.

## Checks

- **Import.** The headless import check is clean.
- **`tests/test_aqueduct_isle.gd`.** PASS headless, 25 checks: the original routes, replays and summit lines, plus 7 new henge and circle proofs.
  - Round 1's cloister and piers checks were removed with those pieces.
- **`tests/test_ruin_kit.gd`.** PASS headless.
- **Not done.** The full suite was not run (per standing instructions). Nothing was added to `tests/known_failures.txt`.

## Weak

- **Sarsens read too clean.** They are big smooth faces in one stone tone, with little chipping visible at distance. They read "Stonehenge" instantly but more neolithic-clean than gothic-romantic. Worth trying: more lichen, deeper wear, a vertical split in one or two.
- **The terrace wall reads a little like a tank.** It is a plain coursed drum; the buttresses help only a little. It could use a broken parapet run, a breach or a stepped plinth.
- **The grand stair at weathered 0.55 is busy.** Its cheeks are heavily torn, so the stair's clean diagonal is weaker than the kit stair's. It is still clearly a stair in every capture. Lower weathering would read more ceremonial.
- **Kicks between sarsens are untested.** The fallen-lintel gaps are 1.9–2.3 m (faces 25° off parallel), in the kick range, but the bot never tried them. Hop chains through the ring are untested too.
- **The bot can't see lintels overhead.** Its ground probe misses a lintel above head height, so lines onto the ring use running jumps. A player just jumps.
- **The heel stone is unproven.** Its pump catch at 2.3 m is not tested.
- **The east half is open turf.** That is deliberate, for 20–50 m runs, but it is plain apart from the heel stone and the paths.
- **No physical link from the henge's height to the aqueduct.** The relationship is the axis, not a connection. There is no water feature leading to the henge.
- **Round 1's weak items still stand:** squat aqueduct, the water's grazing look, the island keel/builder, no plane, the castellum's plain tops, and look checks done by captures only.

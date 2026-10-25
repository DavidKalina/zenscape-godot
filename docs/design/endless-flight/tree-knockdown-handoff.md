# Tree knockdown: handoff

Prototype round. In the weighted presets (light, medium, heavy), flying
into a spruce knocks it down: the plane keeps flying and pays about a
scrape's cost, and the tree falls the way the plane was going, lies on the
land, then sinks away. `--weight=off` is unchanged.

## Try it

    ./run-endless-flight.command --at=-282,-3008 --heading=-90 --alt=8

Seed 1, flying east through the densest wood near the start. Going this
way the plane knocks down 4 or 5 trees in 8 s with no stick input. Fly low
over any wood. F1's numbers line shows "N trees knocked, M down".

## What changed

- `scripts/endless/tree_knock.gd` (new, `TreeKnock`, the study's `knock`):
  - Finds hits before the move, prices them and runs the falls.
  - Each frame before the plane's step (`before`), it checks the plane's
    current and next spots against the standing trees the same way the
    move and the near misses would:
    - the middle against the flight cone plus `SkyGlide.SKIM`
    - NearMiss's body points `TIP_DEPTH` into the cone
    - points along the wings against the bare crown (the collider)
  - Every tree it meets is knocked down before the move, so the plane flies
    on through instead of riding up or being turned aside.
- `scripts/endless/land_trees.gd`: adds `knocked` (game state), `tree_key`,
  `tree_in`, `knock`, `parts`, `tint`, and the hiding (`_hide_block`,
  `_shrink`, `_tone_of`).
  - Each cell lookup now also carries `slots` (variant, index in that
    variant's near batches, index in the block) and `pose` (scale, wide,
    yaw), built in `_cells` and `_lookup`.
  - Hiding goes by index, not by reading MultiMesh buffers back: headless
    reads give zeros, and on the GPU a read-back would stall.
  - A knocked tree is shrunk to zero in its block's trunk, crown, sprite,
    mid and shade batches. It is taken out of the block's detail-square
    buffers, and the squares already standing are rebuilt.
  - Its solid entry gets top, reach and radius 0 and `[q+7] = 1`, so
    `top_at`, `ground`, `inside`, the birds (they skip trees under 4 m) and
    the near misses all pass it.
  - Its `CollisionShape3D` (now named `T<i>`) is taken out of the physics
    space at once, and `_fill` skips knocked trees.
  - `_commit` applies the knocked set to every block it stands again.
- `scripts/sky_plane.gd`: adds `knock(keep, shove, yaw)`.
- `scripts/endless/flight_contact.gd`: a tree hit that still reaches the
  grading goes to `TreeKnock.at_hit` and comes back as `{"knock": ...}`.
  This is only a fallback; the drivers saw no tree scrapes or crashes.
- `studies/endless_flight.gd`:
  - calls `knock.before` before `hand_landing.step`, and `knock.step` after
    `trees.step`
  - `_knocked` adds the frame's `events["knock"]`, the chain loss and a
    scrape's shake
  - adds `knock.note()` to the F1 line
- Effects:
  - `flight_debris.gd`: a new "wood" kind (chips), plus leaves at the hit
    and leaves and dust where the crown lands.
  - `flight_sound.gd`: new clip kinds `snap` (trees-6, broken branches),
    `crack` (mesa-break 1–2 pitched up 1.7) and `thud` (pat-4, pat-6, body
    falls on dirt). A knock plays crack, snap and leaves. The fall's creak
    and thud play in 3D at the tree.
  - `flight_rumble.gd`: adds `KNOCK` and `KNOCK_MORE` (by heft).

## Rules and knobs (all in `scripts/endless/tree_knock.gd`)

- **What still crashes:** no tree. Every spruce goes down, and there is no
  knob for it. Land, stone and water are graded exactly as before.
- **Cost per tree:**
  - Speed: you keep `KEEP` = 0.96 for a brush of the tip, down to 0.86 for
    a hit deep in the tree.
  - `heft`: how far under the cone's top the hit point was, over `HEFT` =
    0.35 of the tree's height. A wing-only hit counts `WING` = 0.5 of that.
  - A shove of `JOLT` = (1.8 m/s away from the trunk, 0.9 up), times 0.4
    to 1 by heft.
  - A yaw of `YAW` = 0.05 rad away from the trunk, times heft.
  - Several trees in one frame multiply their keeps.
  - For comparison, a scrape keeps 0.88 less 0.012 per m/s into the
    surface.
- **Chain:** `LOSES_CHAIN` = true. A knock loses the unbanked near-miss
  chain as a scrape does. I chose this so knocks cost the same as scrapes.
  Set it false to make knocks cost speed only.
- **Fall:**
  - The tree breaks `STUMP` = 0.6 m up (capped at 8 % of its height), and
    a stump stays.
  - It tips as a rod on its foot: angular acceleration = 1.5 g ×
    `FALL_G` (2.2) × sin(angle) / height.
  - It starts from `TIP0` = 0.07 rad, with a push of `PUSH` (0.35) × speed
    × (hit height / height) / height.
  - It comes to rest square to the land's slope along the fall, lifted by
    the crown's girth (`REST_LIFT` = 0.55).
  - It bounces back `BOUNCE` = 0.22 of its swing, at most `BOUNCES` = 2
    times, and gets a random twist of up to `TWIST` = 0.35 rad (seeded by
    the tree's spot).
- **Clean-up:**
  - A fallen tree lies `LIE` = 30 s, then sinks into the land over `SINK` =
    6 s.
  - At most `MAX_LIVE` = 12 lie at once; past that the oldest sinks over
    `SINK_FAST` = 1.5 s.
  - One more than `FORGET` = 900 m from the eye is dropped.
  - While the chase camera is inside a falling crown (girth plus
    `CLEAR_EYE` = 1.5 m), the crown isn't drawn. The camera follows the
    plane's path through where the trunk stood, and without this the
    screen filled with trunk for a frame.
- **Game state:** `LandTrees.knocked` is keyed by `tree_key` = the tree's
  plan x and z in decimetres (the plan puts each tree at the same float32
  spot on every build). It lasts the session and isn't saved. The plan and
  land are untouched, so they are still a pure function of the seed.

## Measured (headless, seed 1, `scratch/knock.gd`, `scratch/tryit.gd`)

- One lone 14.5 m spruce, hit at half its height at 36.75 m/s:
  - knocked, no crash, no tree scrape
  - speed 36.75 to 33.32 m/s: kept 0.907, against the event's 0.906 at
    heft 0.54
- The fall: thud at 1.38 s, at rest at 1.87 s, rest angle 1.41 rad.
- After the knock:
  - `tree_in` and `top_at` ignore the tree
  - no collider shape for it, and nothing at its trunk in the physics space
  - hidden by index in its block's Trunk, Sprite and Shade batches and one
    detail square
  - in a rendered run, reading the instances back finds none left drawn at
    its spot
- After freeing its block and standing it again (worker build plus
  `_commit`): still hidden (read back in the rendered run), still no solid,
  still no collider.
- 6 s low through the densest cell (79 trees): 5 knocked, 0 crashes, 0
  tree scrapes. Speed went 37 to 29 m/s over the run.
- The try-it line: 5 knocks on medium, 4 on light, 4 on heavy, 0 crashes;
  `off` knocks none, as before.
- Smoke check passes.
- Rendered films (side view, and the play camera through the hit) were
  judged by eye: the tip starts slowly, speeds up, thuds, puffs and
  settles.

## Unverified / known gaps

- **The native tree kernels weren't exercised.** This worktree's library
  has no `ZenScapeTrees` class, so trees were built in GDScript. Reading
  `tree_cell.h` `block`, its near, mid and tile buffers and its tone RNG
  come in the same order as `_block_from`, so the index hiding should hold.
- **Far ring:** its thinned trees (past 1380 m, drawn only with
  `--spruce-sprites=0`) are not hidden. With the default sprites the far
  cells draw no crowns.
- **Seeing the fall from the chase camera:** the tree falls the way you
  fly but you pass it in about 0.3 s. You see the hit (leaves, chips, the
  crack) and the fall itself only when you look back or turn round.
- **Not checked:** sound by ear (headless only counts shots) and the pad
  rumble by hand. Birds perched in a tree you knock stay where they were.
- **Commit cost:** a block that holds knocked trees does a little more work
  when it is stood (a loop over the knocked set and the block's cells). Not
  measured; there was no perf pass.

## Tests

- No new tests.
- `tests/test_sky_plane.gd` fails on a missing `_scarf_points` in
  `plane_figure.gd`, and fails the same way without this change.
- No existing test touches LandTrees, FlightContact, the debris, the
  sound or the rumble.

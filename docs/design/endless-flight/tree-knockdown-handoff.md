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
    `FALL_G` × sin(angle) / height.
  - How it starts, which way it falls and the crown's whip: see "Round 2"
    below (it replaced `TIP0` 0.07 and `PUSH`, and `FALL_G` went 2.2 to
    1.5).
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
- **Seeing the fall from the chase camera:** addressed in Round 2 below.
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

## Round 2: snap at the hit, lean to the struck side

The plane passes a tree in about 0.3 s, so before this round the chase
camera showed the hit but not the tree moving. Now the tree lurches over
in the first few frames, the way the plane was going and out to the side
it was clipped on.

### What changed (`scripts/endless/tree_knock.gd`, `flight_debris.gd`)

- **Snap.** The slow start (`TIP0` 0.07 rad plus `PUSH`) is replaced by a
  lurch: an extra spin that dies away fast, with gravity taking over after.
  - The lurch's spin is `SNAP` = 8 rad/s, scaled by:
    - the blow: `SNAP_TIP` = 0.5 for a brush, up to 1 for a full hit
    - the speed over `SNAP_SPEED` = 36 m/s, clamped to `SNAP_RANGE`
      0.5–1.5
    - the hit's height on the tree (0.6 to 1)
    - sqrt(`SNAP_HEIGHT` 14 m / height), clamped 0.75–1.35
  - It dies over `LURCH` = 0.11 s, and `CARRY` = 0.05 of it stays as the
    fall's spin.
  - `FALL_G` went from 2.2 to 1.5, so the rest of the fall isn't rushed.
  - **The blow** (`_blow`) comes from the plane's line, not from the heft:
    - full when the line passes within `BLOW_IN` = 0.3 of the half span of
      the trunk, falling to none at half span plus the crown's girth
    - times how far under the treetop the plane is, over `BLOW_DEEP` =
      0.35 of the height
    - The heft wasn't usable: the hit is caught the frame the plane first
      touches the cone, so the heft is shallow on nearly every pass.
- **Lean.** The fall turns off the plane's way toward the side the trunk
  stood on (`_lean`).
  - It turns by up to `LEAN` = 0.85 rad (49°): none inside `LEAN_DEAD` =
    0.4 m of the flight line, the whole of it at `LEAN_FULL` = 0.8 of the
    half span or further out.
  - `CENTRE_SWERVE` (0, off) would turn a dead-centre hit that much to a
    side chosen by the tree's spot.
  - The rest angle reads the land's slope along the leaned way.
- **Crown whip.** At the first fall, each variant's trunk and crown meshes
  are cut at `JOINTS` = 0.42 and 0.7 of the height (cached; each piece
  keeps the whole vertex buffer and its own triangles). The pieces hang
  from joint nodes.
  - Each joint bends on a spring (`WHIP_HZ` = 2.4, `WHIP_DAMP` = 0.28,
    capped at `WHIP_MOST` = 0.4 rad).
  - At the hit it is kicked back by `WHIP` = 0.6 × the lurch, so the top
    lags, then overshoots forward. At the thud it gets `WHIP_THUD` = 0.12
    × the spin.
  - If the arrays can't be read, the tree falls in one piece.
- **Needles.** A new debris kind, `needles`:
  - 64 small dark-green quads from a ball 1.5 m round, with a pool of 4
    emitters.
  - They are faded out within 1.5 to 5 m of the eye (distance fade), so
    the camera flying through a burst isn't filled with squares.
  - A burst comes off the crown (0.78 of the height) at the hit, and a
    smaller one off the top the first time the whip swings forward
    through straight.
- **Unchanged:** the plane-side cost (keep, shove, yaw, chain), the knocked
  set, hiding and colliders, lie and sink, the cap, and the land's
  determinism.

### Measured (headless, seed 1)

- `scratch/lean.gd` flies the same lone 14 m spruce three ways (12 checks,
  all OK):
  - **Left-wing clip** (line 1.05 m right of the trunk): falls 44° left of
    the flight line. Blow 0.86, 0.48 rad over after 0.1 s.
  - **Right-wing clip:** falls 44° right. 0.47 rad at 0.1 s.
  - **Centre:** falls 0.0° off the line. Blow 1.0, 0.51 rad at 0.1 s.
  - **Crown bend** per joint: −0.16 rad at about 0.07 s, overshooting to
    +0.07 at about 0.27 s, settled by 0.6 s.
  - Each knocked tree: `tree_in` empty, no collider shape at its trunk.
- `scratch/blows.gd` (try-it line, medium), five knocks:

  | blow | lean | at 0.1 s | at 0.3 s |
  |---|---|---|---|
  | 0.21 | −50° | 0.24 rad | 0.39 rad |
  | 0.22 | −50° | 0.25 rad | 0.41 rad |
  | 1.0 | +3° | 0.39 rad | 0.66 rad |
  | 0.65 | −51° | 0.38 rad | 0.65 rad |
  | 0.17 | +50° | 0.24 rad | 0.39 rad |

  Most hits in a wood are wing clips into a crown's edge.
- **Thud:** about 0.6–0.95 s for a full hit, about 1.4 s for a brush
  (sim). Before this round it was about 1.4 s for every hit.
- `scratch/knock.gd` (previous round's checks): 18/18 OK. Thud at 0.60 s
  on an uphill rest. The same 0.945 speed kept as the event. Still gone
  and no collider after its block is stood again.
- `scratch/tryit.gd`: 5 knocks on medium, 4 on light, 4 on heavy, 0
  crashes; `off` knocks none. All the same as before.
- Smoke check passes.

### Judged (rendered, chase/play camera; stills in this worktree's `scratch/shots/`)

- `lean_left_sheet.png` and `lean_right_sheet.png`: the same tree clipped
  by each wing, every 2 frames.
  - In frames 0–10 (0.33 s) it goes from upright to slanting hard out to
    its side across the frame, left for the left wing and right for the
    right.
  - Then the camera passes it.
- `tryA_sheet.png`: try-it line, the first knock (a weak left clip, blow
  0.21). In frames 0–6 (0.2 s) the tree visibly leans left as the camera
  closes on it, then leaves the frame on the left.
- `lean_centre_sheet.png`: a full centre hit.
  - The tree drops away ahead: on screen it shortens and its trunk shows
    as it tips away. Then it lies under the flight line.
  - This reads less than a side clip: a fall straight away from the camera
    has little sideways motion, and its top moves at about the plane's
    speed.
  - `CENTRE_SWERVE` is there to try if centre hits need it.
- `body_centre_sheet.png` (side view, square to the fall): the lurch, and
  the crown's lag and whip bending the top.
- The judging was done with the needles faded near the eye. Without the
  fade (`try1`/`try3`, earlier), big pale squares filled the frame as the
  camera flew through the burst.

### Unverified / known gaps

- **Seams:** the cuts open small gaps on the outside of a bend at the
  joints. Not visible at chase-camera distance in the stills; not checked
  close up.
- **Native tree kernels:** not exercised, as in round 1.
- **Sway:** the falling copies keep the crown's sway shader.
- **Dark quads:** an occasional small dark square shows in the leaves,
  wood and needle bursts in the rendered stills. Not looked into.
- **Not checked:** sound and rumble (unchanged), and how this feels in
  play.


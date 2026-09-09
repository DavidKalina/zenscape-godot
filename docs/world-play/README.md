# Physical play in Diorama

The normal `studies/diorama.tscn` entry point now uses authored scenery for play. In Enjoy mode, drag trees to bend and release them; swing and release rocks, boulders, logs, and stumps to throw them. Bigfoot can choose reachable stones, logs, and trees, using the shared animations and rage behavior. Dragging him over water and releasing lets him paddle to a checked shore.

Build retains placement/edit gestures. Saving or returning to Build writes moved prop positions and orientations into their existing records, restores batching, and resets temporary tree bends. Legacy reference scenery is converted to authored records with validated source suppression saved alongside the world, avoiding duplicate scenery on reopening.

## Implementation

`diorama_world_play.gd` adapts the shared playground controllers to the product scene. Original meshes, compound parts, placements, and materials are retained. Untouched scenery stays batched; touched props use convex rigid bodies and nearby projectiles can wake additional props. Dynamic clearance prevents navigation through moved props. Collision is prepared when entering Enjoy, outside the first grab. Trees deform their existing materials with a shared bend include; height follows the authored object.

Bigfoot uses props that fit his current hand choreography; the player can grab any supported object size. Static navigation remains conservative about the old prop location until saving or returning to Build refreshes it. Physics and tree bends are transient; persistent saves store placements, not active velocities or rage timers.

## Validation

- `tests/test_diorama_world_play.gd`: all 13 tree/prop kinds, original mesh transforms, directional tension and recoil, actual rigid-body motion, pause, saving/reopening placements and rotations, Build ownership, world replacement, all three Bigfoot actions, rage speed, water sampling and swimming release. Passed headless and Metal.
- `tests/test_world_reference_play.gd`: legacy migration, idempotence, source suppression, save/reopen.
- `tests/test_diorama_flow.gd`, `tests/test_resident_interaction.gd`, `tests/test_resident_gust.gd`, `tests/test_loose_props.gd`: product flow and existing gesture/physics regressions.
- `tools/profile_diorama_world_play.gd`: in-memory frame measurements, no per-frame screenshots. Use the real renderer without `--fixed-fps`.

## Performance measurement

Apple M5 Pro, Metal Forward+, 1440×960 window, redwood preset with 346 objects, no Bigfoot, 240 frames per phase after warmup. Median frame interval was 8.34 ms (~120 FPS) with interactions disabled, idle, bending, and recoiling; p95 stayed below 8.5 ms. First-tree activation fell from 22.5 ms to 0.2 ms after preparing collision on entering Enjoy. This is a measured scene, not a guarantee for all resolutions or environments. The renderer reported GPU duration as zero, so no GPU timing claim is made.

A subsequent resident-enabled comparison retained an ~8.33 ms median and revealed an occasional ~52 ms scene callback with the new interactions disabled (baseline AI/navigation behavior). That intermittent resident hitch remains; it is separate from the fixed promotion cost and capture overhead.

The earlier movie recorder wrote full-resolution PNGs every frame and distorted perceived performance; it is not used for gameplay timing.

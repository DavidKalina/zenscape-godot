# Solid props on foot: handoff

Branch `feature/solid-props`, from `main` at ce50f324. Not merged and not pushed.

## What changed

On foot, the plate's props are now solid things with a height. Before this
change they were 2D circles that blocked at every height.

- **New `scripts/solid_props.gd`** (`SolidProps`). It reads each drawn part
  of a solid prop as a column cut into 24 bands by height:
  - Round parts (trees, rocks, boulders, stumps, cacti) store the widest
    vertex per band.
  - Box parts (`log`, `cabin`) store each band's extent in the part's own
    x/z, turned with the part.
  - Props that can be stood on (`rock`, `log`, `stump`, `boulder_1..4`,
    `cabin`) also get a top grid: the mesh's highest surface seen from
    above, 32 cells across, built once per mesh. That makes a boulder
    domed, a log only as wide as the log, and the cabin roof pitched
    (eave about 1.6 m, ridge about 2.66 m).
  - A 2 m spatial grid keeps the queries cheap.

  It answers three questions:
  - `push`: the walk step pushed out of what stands at the body's height,
    from STEP 0.2 to HEAD 1.15 m over the feet.
  - `top`: the highest surface to stand on.
  - `wall`: the way off a wall for the motor.
- **`scripts/wanderer_eye.gd`**:
  - `cabin` joins `SOLID`.
  - `_read_obstacles` also fills `solids`, with the parked plane as a
    column.
  - `_walk` now uses `solids.push`. The square-on lean round trunks is
    kept.
  - `_motor_ground` returns max(terrain, prop top). Because of that, ledges
    (`_lip`) come for free on boulder lips and cabin eaves.
  - `motor.wall = _wall` checks the props first, then falls back to
    `PilotMotor.heightfield_wall`. Perched on an islet, it uses the islet's
    ground as before.
  - `motor.water` subtracts a prop's height, so standing on a rock in a
    pond doesn't wade at the rock's top.
  - `_obstacles` (the 2D circles) is still built and still used for
    placement (`_blocked`, `_free_spot`), landing strips and
    `tools/probe_wanderer.gd`.

## The rules, and the decisions behind them

- **What stops the body.** A part stops the body when it has geometry
  between feet+0.2 and feet+1.15. Standing on flat ground, this is the same
  footprint as before, so the eye is still kept out of trunks and of low
  crowns like a spruce's skirt. A broadleaf's high crown still doesn't
  count.
- **Foliage is soft in the air.** A part counts as foliage when its name
  contains `canop`, `thatch`, `blades` or `deadwood`. On the ground,
  foliage still stops the body as before. In the air it doesn't: jump into
  a crown and the body goes in among the leaves to the trunk. If he lands
  inside a crown, the feet are eased out at 0.05 m per step (3 m/s), not
  snapped.
- **Stand-on props.** One of these stops the body only while its top is
  more than STEP_UP (0.45 m) above the feet. Below that it is ground: walked
  up onto, or landed on.
  - On the ground, the test uses the prop's highest point, so you can't
    climb a boulder's flank step by step.
  - In the air, it uses the top where the body comes down, so falling onto
    a boulder's shoulder lands on the shoulder.
- **Walls.**
  - What counts: any part that isn't foliage, as wide as it is at the
    body's height, plus the figure's 0.28 m radius. The whole prop must
    stand WALL_TALL (1.2 m) over the feet, measured to the prop's highest
    point. Without that, a broadleaf's trunk part, which ends inside the
    crown, would be too short.
  - The trunk, not the crown: foliage never counts as a wall.
    - A spruce is held by its 0.16 m trunk once he's in the air.
    - A broadleaf's trunk mesh carries branches up into the crown. At body
      height mid-jump, those branches make it about 1.08 m wide at size
      1.4, so he holds on about 1.36 m from its middle. He's still holding
      the trunk part, not the leaves.
  - Like the terrain's walls, the motor takes hold once a wall is within
    WALL_PROBE (0.45 m) ahead. On a thin trunk he can hang up to about
    0.4 m off the bark.
- **Cabins.**
  - The walls are oriented boxes. Walk into one and you slide along it;
    the walls can be slid down and kicked off.
  - The roof can be landed on. It is pitched, read from the mesh.
  - The eave is low (about 1.6 m). On a long side, a wall hold usually
    turns into catching the eave, and the climb takes him onto the roof.
    That's Mario-like and I left it.
  - A clean wall kick is easiest off a gable end.

## Numbers seen (walk-test island, the test's placements)

| Prop | Size | Measured |
|---|---|---|
| boulder_1 | 1.1 | top 1.07 m; landed on its top at 0.91 m |
| rock | 1.0 | top about 0.95 m (too short to be a wall from the ground) |
| log | 1.8 | top 0.27 m: walked straight over |
| log | 3.6 | top 0.53 m: stops a walk, hopped with a jump |
| stump | 1.0 | top 0.39 m: stepped up |
| cabin | 1.0 | ridge 2.66 m, eave about 1.6 m |
| spruce trunk | | held 0.80 m from the middle |
| broadleaf (branchy trunk) | | held 1.36 m from the middle |

Wall kick: 5.2 m/s out, about 1.4 m up, unchanged from the motor's
constants.

Reading the props takes about 0.3 s the first time, while the top grids
are built. After that it only re-reads when the objects change, as before.

## How to try it

- Walk-test island: trees, boulders, logs and stumps, and you start on foot:
  - `./run-walk-island.command`, or
  - `godot --path . res://studies/walk_island.tscn -- --no-title`
- The real game: `godot --path . res://studies/cozy_worlds.tscn -- --no-title`.
  Place a cabin from the case, then press V to walk.
- Things to try:
  - Run at a tree, jump into it, keep pushing into it, and press Jump to
    kick.
  - Jump onto a boulder.
  - Run over a low log.
  - Jump at a cabin's long wall: he catches the eave, and pushing in climbs
    onto the roof.

## Tests (headless)

- `tests/test_solid_props.gd`: new, passes, about 33 s on its own. It uses
  the walk-test island with its props cleared and its own set down: spruce,
  broadleaf, boulder, a low and a tall log, a cabin. It steps the motor at
  60 fps with the walker's own ground, walk, wall and ledge callables. It
  checks:
  - wall kicks off a spruce, a broadleaf and the cabin's gable;
  - landing and standing on the boulder's top, then walking off;
  - a low log walked over, a tall log blocking a walk and hopped with a
    jump;
  - sliding round both trunks, never inside them;
  - sliding along the cabin wall, never inside it;
  - catching the eave and climbing onto the roof;
  - dropping onto the roof.
- Touched suites run with `python3 tools/run_tests.py`:
  - `test_pilot_*`, `test_character_*`, `test_walk_island`,
    `test_test_island`, `test_plane_flight` and `test_solid_props`.
  - All pass. `test_plane_flight` passes with its usual classified exit
    leak.
  - The full suite was not run.

## Not verified

- Nobody has played it by hand. The feel isn't checked: kicking off a thin
  trunk from up to 0.4 m away, the dome slopes on small boulders, the eave
  catch on cabins, and the eye on a cabin roof.
- No rendered capture. The camera's ground clearance still reads the
  terrain only, not prop tops (see limits).

## Known limits

- **Islets are not covered.** Perched on a sky islet, props are still
  `SkyIslets.blocked` (sky_islet.gd's own record grid). They have no tops
  and aren't walls. Bringing them in means reading the islet's records into
  a `SolidProps` in the islet's frame.
- **Circles and boxes come from vertices.** The bands are vertex-sparse, so
  a low-poly part's band can be empty or narrow between its vertices.
- **Boulder shapes.**
  - A rounded boulder's flank can be steep enough (over 44°) that he
    surfs off its shoulder.
  - Walked into on the ground, a boulder whose top is over a step away
    stops him at its widest band, even where its dome is lower.
- **Small rocks aren't walls.** A rock or boulder under 1.2 m over the feet
  isn't a wall (same rule as terrain). Only big rocks (`rock` at 1.0 is
  0.95 m) and scaled-up boulders are.
- **Ledge catches on props.** The ledge finder now sees prop tops, so
  walking slowly off a boulder 0.66 m or taller hangs from its edge.
  Catches on cabin eaves happen as on cliffs.
- **Camera.** `_frame_walker`'s clearance ground is terrain only. On a
  cabin roof the camera can sit in the roof.
- **Box parts.** Logs and cabins have no square-on lean. Walked
  dead-square into one, he stops; any angle slides.
- **Other box placeables.** Fences, lamps and wells were not touched.

## Next steps

1. Play it: tune how close a wall hold on a trunk happens. One option is to
   probe props with a shorter reach than WALL_PROBE, so the hand meets the
   bark.
2. Islets: build a `SolidProps` per perched islet from its records.
3. Let the camera's clearance use `_motor_ground` (prop tops) on foot.
4. Consider flattening the walkable top of small boulders, if surfing off
   them feels bad.
5. Fences and wells as boxes, through the same `BOXES` path, if wanted.

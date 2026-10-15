# Airship ferry, round 1

The last plane part on foot. The cowl is jammed under the bell in the bell
spires' belfry, and nothing on foot reached the bell spires. One of the sky
folk's airships is now a ferry that you can ride on foot.

## What was built

- `scripts/kit_isle/airship_ferry.gd`: the ferry. It is the sky folk's ship
  at 1.8x (`SCALE`), so the foredeck (about 4 m by 2.5) takes the walker. It
  has a solid of its own: the hull's half shell up to the flat deck, the
  cabin, and the envelope's capsules, all scaled. The body is a
  StaticBody3D that is set in the physics server every frame, so his ground
  ray reads the deck where it is now.
- The carry follows the serpent rider's three steps
  (`scripts/kit_isle/serpent_rider.gd`), at process priority -100, ahead of
  the scene's step:
  1. Work out what he is on: the deck (a ray hits its body, or a ledge on
     its edge), other ground, or the air.
  2. Move the ship on.
  3. Carry him by its move with `PilotMotor.carry`, along with his camera
     and its turn. In the air off the deck he keeps the frame he jumped
     from. That frame is held, then fades, like the serpent's.
- `studies/aqueduct_isle_sky.gd`: the old first loop (past the isle and out
  by the bell spires) is now the ferry. The other two ships keep their
  loops and phases. The ferry is last in `airships` and moves itself. The
  sky only reads its position for the drone and the crew's wave.
- Docs: the cowl's lines in `scripts/plane_arc/part_spots.gd` and
  `plane_arc.gd`, and the sky's header.

## Route and stops

This is a closed Catmull-Rom loop of about 750 m, 181 s a lap. Between stops
the ship eases up to 7 m/s and back down at 0.3 m/s², a long slow glide in
and out. It rests 14 s at each stop. Its position depends only on its clock.

- **home**: (92, 29.9, 18.5), heading west along the aqueduct isle's south
  edge, by the start and the parked plane. The deck is level with the turf
  (30.0) and the starboard side is 0.3 to 0.55 m off the edge, so you walk
  or hop on.
- **out**: it climbs west over the serpent's home ledge (about 9 m over
  it), turns south, and heads back east above the serpent's south-rim run
  and its dip. It comes round to the bell spires from the north.
- **bell**: (385.8, 41.7, 52.5), heading south along the bell spires' west
  lobe. The deck is level with the turf (41.8) and the port side is about
  0.6 m off. From there the low stair's foot is about 25 m east, and the
  belfry is up it and up the hero's stair. That's `--part-at=cowl`'s spot,
  where a slam knocks the cowl loose.
- **back**: it turns west short of the floating stone south of the lobe,
  then heads home high over the serpent's way. It comes down to the south
  edge from the east.

The default clock has it gliding in to home 12 s after the start.

## Flags

- `--ferry-aboard`: start on the foredeck at home, 4 s before it leaves.
  The crossing takes about 85 s.
- `--ferry-aboard=bell`: start on the foredeck 25 s out from the bell
  spires. Their isle is stood up at once.
- `--ferry-at=home|bell`: start on foot at the stop's edge, with the ferry
  20 s from coming to rest.
- `--no-ferry` leaves it out. `--no-airships` and `--serpent-old-route`
  leave it out too, because the old long way runs through its loop under
  the bell spires.
- `--part-at=cowl` (existing): start on the belfry floor by the jammed
  cowl, to try the slam.

## How to try it

```
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path <wt> -- --no-title --ferry-aboard
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path <wt> -- --no-title --ferry-aboard=bell
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path <wt> -- --no-title --ferry-at=home
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path <wt> -- --no-title --part-at=cowl
```

With no flags, it comes in by the start soon after you begin. Walk onto its
foredeck while it rests.

## Checks

`tests/test_airship_ferry.gd` (suite: slow, about 60 s) checks:

- The stops: the deck is level with the turf, and the turf is a hand off
  the deck's edge.
- The body follows the ship at once.
- Round the whole lap, the hull, cabin and envelope never touch an isle or
  the parked plane (shape queries every 0.5 s).
- The loop stays at least 6 m past the serpent's reach (7.1 m at the
  closest, over its home run) and 144 m from the other ships' loops.
- A ride from home to bell: on the deck every frame, 7 mm of drift, worst
  frame 0.1 mm, turned with the ship, and a jump on the moving deck lands
  0.05 m off.
- Off at the bell spires onto their turf.
- Walking aboard at home.
- Both `--ferry-aboard` starts.

Other test changes:

- `tests/test_aqueduct_isle_sky.gd` now counts the ferry.
- `tests/test_serpent_route.gd` leaves the ferry's loop to the ferry's own
  test. By design the ferry comes down near the isles and crosses over the
  serpent's home run.

## What's rough

- No visual check: everything was headless. The ship at 1.8x, the bank, and
  how the docking reads have not been seen rendered.
- The camera gets pulled in by the cabin when he faces the bow, because
  the cabin is solid and stands behind him. Swing the camera to the side.
  The serpent's back has the same behaviour.
- The deck has no solid rail. You can walk off the far side, as off the
  serpent. Mid-crossing that's a fall: the game's own stranding puts you
  back by the plane.
- The pusher pods and the bow crew figure aren't solid. The walker passes
  through them, and at home the pods hang over the turf by the start.
- On the way out it crosses the serpent's home run about 5 m clear of its
  keel. That is clear, but tighter than the other ships' 15 m.
- With `--serpent-old-route` there is no ferry, so the cowl needs the plane.
- The bell stop is on the west lobe, so the walk to the stairs is about
  25 m. A stop nearer the belfry (by the hero's top landing) would put the
  30 m envelope against the spires. Not tried.

# Terrace rock: handoff

Loop `terrace-rock`, branch `iter/terrace-rock` (from main 6bb42c50). Spec:
`spec-terrace-rock.md` beside this file. The trail:
`git log --grep='^ITER(terrace-rock)' --format='%B'`.

## What's built

- **TerraceRock** (`scripts/kit_isle/terrace_rock.gd`): tiers (an outline at a
  height, `cut: true` to lower) are built as one closed solid. Turf goes on the
  tops, faceted rock on every riser and down to a keel, and the collision is
  the drawn faces. A top under about 1.8 m wide gets a stone cap. Grand stair
  helpers: `grand_stair_cut`, `seat_grand_stair`, `grand_stair_frame`,
  `STAIR_RISE`. KitLand is untouched.
- **The check** (`tools/terrace_check.gd`, runner `tools/terrace_check_run.gd`,
  listed in tools/README.md). It counts see_in, through, holes and standoff.
  Seated pieces carry meta `terrace_seated`. Stair points where five close
  rays disagree are `piece_edge` (not judged); a stair's collision over a sunk
  slab is `piece_proud`.
- **The Stair to the Clouds** rebuilt on it, with the same plan. Each of the
  eight flights climbs in a cut, with a parapet on its outer side. The old
  heightfield mesa, facades and skirt are gone.
  - Things placed on the new mesa were refitted: rails on legs 5 to 8 inset
    0.45 m (`Balustrade` `inset`, default 0), the slabs off the lawn raised,
    two piers moved, and the plane rings' spiral moved out to radius 33.
  - The tomb chests are removed. Sparrows perch on the pad 3 pier and the
    terrace 3 arch; robins on the summit's turret and lancets.
  - Flora is kept off the stone caps.
- **Shared changes outside the isle:**
  - `scripts/ruin_kit.gd` `_flight`: a hidden dark block under each grand
    stair step closes the light seam between its two slabs. It is visual
    only and on its own seed.
  - `scripts/cloud_volume.gd`: clouds draw for whichever camera is on
    screen. Stills no longer show a stale cloud card, and the telescope view
    should get real clouds.
- `studies/terrace_rock_test.tscn`: the builder's test shape.

## Play

`./run-stair-clouds.command` from the worktree (`--foot-at=stair`,
`--foot-at=stair_slabs`).

## Proof (last run, step 4e)

- Terrace check on the isle: 0 / 0 / 0 / 0.
- Real-input climb of all eight flights, up and down, plus 48 runs into the
  walls: never inside rock in 16,079 frames.
- `tests/test_motif_sky.gd`: the plane lands on the lawn, parks, and the pilot
  walks off. This is scripted control input, not a person flying.
- Smoke: stair_clouds_isle and zenscape PASS, re-run at the finish.

## Open

- Breaks, not re-recorded: the mesa fingerprint (`tools/kit_isle_fingerprint.gd`)
  and `tests/motif_fingerprint.gd`. Any test counting a grand stair's
  triangles sees 12 more per step. The full suite was not run, and
  `tests/test_stair_clouds_isle.gd` was not re-run after step 3b.
- Stair weathering is 0 (a chipped slab showed a back face).
- `shot_at` in `tools/harness/drive.gd` still lays the stale cloud picture
  over stills (its own camera); `tools/shot.py` is fixed.
- The cut walls read dark and plain from inside the flights.
- Other stepped isles could move onto TerraceRock in a later round.

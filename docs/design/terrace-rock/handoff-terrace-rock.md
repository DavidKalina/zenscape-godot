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
- **Placement cleanup** (3e3600e7, after the user played it): RuinKit
  `Build.seat(ground, drop)` is opt-in and per thread. A piece built while it
  is set lays its rubble and drifts on the real ground and leaves out any over
  a drop, and nothing else changes. The isle builds its shrines, summit pieces
  and bridge anchors through `Stair.seated`. Five body stones were moved off
  the drop (piers on pads 1 and 5 to r 25, small turns elsewhere). The gate
  moved along the rim to `GATE_AT` (-3.5, -7) so both feet stand on the
  summit. The rope bridge now arrives about 3.5 m beside it, which the user
  accepted. The floating-piece audit went from 16 to 0 and the overhanging
  arches from 1 to 0.
- **Lock-in round:** the landing tokens moved from r 24.3 to r 22 on each
  landing's inner side. The pad 1 and pad 5 piers at r 25 stood over the old
  spot, so the token was inside stone and the walk round the corner was
  blocked.

## Proof (last run, step 4e)

- Terrace check on the isle: 0 / 0 / 0 / 0.
- Real-input climb of all eight flights, up and down, plus 48 runs into the
  walls: never inside rock in 16,079 frames.
- `tests/test_motif_sky.gd`: the plane lands on the lawn, parks, and the pilot
  walks off. This is scripted control input, not a person flying.
- Smoke: stair_clouds_isle and zenscape PASS, re-run at the finish.

## Lock-in round

- **Merged main** (ef7ca136: slam springs, air rings, the ring route,
  movement tuning). There were no conflicts. The ring route lies on the
  aqueduct isle (x 140 to 410, z about -12); the stair isle sits in the sky at
  (440, 14, -254.6), so nothing of it reaches the mesa.
- **Fingerprints:**
  - `tests/test_motif_families.gd` TODAY: `colonnade_spine` re-recorded
    (26064:ebd3abea...). Its only change is the grand stair's tread bed: with
    the `_tread_core` call off, the old hash comes back. `broken_ring` is
    unchanged.
  - Kit isle fingerprints (`tools/kit_isle_fingerprints.sh` and
    `kit_isle_fp_check.py`; their baselines are git-ignored captures, so a
    "re-record" means a new base run). The stair isle is now on the list.
    Main against the branch: all rays are the same on all five old isles. The
    only real shape changes are on the aqueduct isle's sky foot route at the
    stair isle (the inset rails and the raised slabs). The tool hashed
    `str(shape)`, whose instance id changed with any code change, so every
    isle's Cylinder line differed. Cylinders, capsules and spheres are now
    hashed by their sizes. Two branch runs give identical output.
- **Tests:**
  - `tests/test_stair_clouds_isle.gd`: the climb follows the new route (each
    flight's middle, round each landing past its token, the summit and the
    moved gate). The old route went round the old landing corners at
    r 24.3. All 13 checks pass, with all six tokens taken.
  - `tests/test_motif_sky.gd`: passes, unchanged.
  - New: `tests/test_terrace_rock.gd` runs the terrace check on the test
    shape (889 samples), and `tests/test_stair_clouds_terrace.gd` runs it
    on the mesa with its eight stairs seated (919 samples). Each wants 0
    see_in, through, holes and standoff, and each takes about 6 s.
- **Suite** (`python3 tools/run_tests.py`, headless): 285 passed, 31 gpu
  skipped (unverified), 2 known failures, 8 other failures. None of the 8
  comes from this branch:
  - These 7 fail the same way on main (ef7ca136, run in the main checkout):
    `test_aqueduct_isle_look` (plant budget, path plant), `test_aqueduct_isle_plane`
    (R3 camera), `test_gamepad` (fails on a different line each run),
    `test_isle_lock`, `test_kit_audio` (grass/stone), `test_serpent_hops`
    (uneven frames), `test_slam` (5 updraft/slam lines, after the movement
    tuning).
  - `test_sky_cache` printed PASS but logged mesh-RID engine errors in
    `scripts/sky_ring.gd` `_stand`, a worker-thread mesh race that shows
    under load. It passes alone on the branch (twice) and on main.
- **Smoke:** stair_clouds_isle, zenscape `--no-title`, and the motif yard
  with sundered_gorge and editor_hill all pass with 0 errors.

## Play

`./run-stair-clouds.command` from the worktree (`--foot-at=stair`,
`--foot-at=stair_slabs`).

## Open

- Stair weathering is 0 (a chipped slab showed a back face).
- `shot_at` in `tools/harness/drive.gd` still lays the stale cloud picture
  over stills (its own camera); `tools/shot.py` is fixed.
- The cut walls read dark and plain from inside the flights.
- Other stepped isles could move onto TerraceRock in a later round.
- The 7 failures that are already on main (above) are for their own rounds.

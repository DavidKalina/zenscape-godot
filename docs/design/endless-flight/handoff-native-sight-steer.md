# Handoff: the chase camera's sight and the burrower's steering in C++

Branch `claude/frametime-analysis-flight-77218b`, 2026-11-03. Goal: the same
answers, faster, for the camera's line-of-sight checks (worst near the
burrower's bore, f7: `s_tube` spikes to 21 ms) and the burrower's `_move`.

## What went native (`native/terrain_kernels/bore_sight_bind.h`)

- **ZenScapeHallSolid**: LandHalls `inside` (`land_halls.gd`), over its
  records' BoxSolid grids. LandHalls publishes a record on `_commit`, again
  when a section takes its near solid (`_stand_near`), and drops it in
  `_free`. Both LandHalls (the tunnels' stretches and the surface halls)
  use it.
- **ZenScapeBoreSight**: LandTunnels `near`, `tube`, `inside`, `land_y` and
  `sight` (`land_tunnels.gd`): the site tables (`local`, `profile`,
  `roof_over`, `floor_at`, `bore_at`, `shaft_at`, `portal_at`, `section`,
  `_cover`'s cap with the engine's FastNoiseLite), the stretches' HallSolid,
  and the near spurs and plugs (BoreSpurs/BorePlugs `sight_pack`, re-sent
  when their near lists change or a spur moves; `solid_moved`). The whole
  `sight` march runs in C++.
- **ZenScapeBurrowerSteer**: `_ask_trunks` (game_land `trees_near`'s loop,
  the filter, the sort, the cut to 14) and `_move`'s steering loop round
  `_obstacles` + `_trunks` (packed once, and when the trunks change).
- `scripts/endless/bore_native.gd` makes them (version gate per class).
  `--sight-native=0` or `--gdscript-kernels`, no library or a stale one:
  the GDScript (`inside_gd`, `tube_gd`, `land_y_gd`, `sight_gd`, the old
  loops), which stays the reference.

GDScript-level, same answers:

- The game's `_sight` 10-step march and `_solid` read `field.height` once
  a point and hand it to the eye's floor (`_eye_over`), `sea_height` and
  `tunnels.inside(p, h)` (each used to read it again).
- game_land `_open` / `_wall` / `stands`: the height read once for the
  water (`_water_over`) and the tunnels; arches and rocks asked only where
  GroundNative's mask says they stand (as the game's `_solid` already did).

## What stayed GDScript, and why

- **`LandField.height`** (`field.height`, ~20 us a call here): with tunnels,
  ponds, splits, the Peak and the isles on, it is GDScript glue round the
  native field plus the tunnels' massif carve (`Tunnels.carve_m`, ~8.5 us).
  It is now the floor of every remaining cost: each `-1` point of the
  tunnels' sight, each step of the game's march, each burrower probe
  (`_open` reads it 5 times: the spot and `normal`'s four). Porting the
  carve (massif, shelves, trenches, pits, sunk bowls) and the sample glue to
  C++ is the next lever; it must match the land mesh bit for bit.
- `arches.inside`, `rocks.inside`, `ice.*`, `eye_floor`'s river and sea: in
  the game's 10-step march; they are cheap (~1 us, masked) next to the
  height, so the march loop stays GDScript round native per-point tests.
- `_feel`'s memo, `stand_ahead`, `roam_goal`, `water_goal`: built on
  `open`/`wet_run`, so on the height.
- `ground`, `guide`, `keep` in LandTunnels (the plane's, not the camera's).

## Equality

`scratch/native_sight_check.gd` (throwaway, git-ignored):
`python tools/drive.py scratch/native_sight_check.gd -- --timeout=800 --seed=11 --scene-args --at=4700,4385 --alt=40`
(two stood tunnels, `doors/tunnel/1_0` among them, 5 stretch records) and
`... -- --land --timeout=800` (the spawn's land, for the trunks).

- 20,000 points round the stood bores (portals, shafts, walls, over the
  massif) and 4,000 camera lines, twice: as stood, then with fake spurs and
  plugs put in the near lists and 10,000 more points round them. `tube`,
  `inside`, `inside(p, h)`, `land_y`, `near`, both halls' `inside`,
  `sight`, `sight_whole`, and the game's new `_sight` / `_solid` against
  their old code with every native off: **0 mismatches** (both seeds).
- game_land `_open` and `_wall` (new vs old, 3,000 spots each place),
  trunks (2,000 asks, 421 with trunks at the spawn), steering (random rocks
  plus the trunks): **0 mismatches**.
- `std::stable_sort` stands in for `sort_custom` (unstable): two trunks at
  exactly the same distance along could come out in another order. None
  did; a float tie between two trees is all but impossible.
- A run with the burrower woken in lead (`scratch/burrower_run.gd`, 2,400
  frames) ends with the same stats native and GDScript, within the
  run-to-run spread the GDScript alone shows (land streaming is threaded).

## Headless per call (us, old GDScript vs new)

| call | old | new | x |
|---|---|---|---|
| `tunnels.tube` | 7.3 | 0.45 | 16 |
| `tunnels.inside` | 41-49 | 20-25 | 2 |
| tunnels' halls `inside` | 3.6-4.7 | 0.5-0.6 | 7 |
| surface halls `inside` (none stood) | 0.6-0.8 | 0.4-0.6 | 1.3 |
| `tunnels.sight`, mixed lines | 276-336 | 52-62 | 5 |
| `tunnels.sight`, lines in the tube | 386-490 | 4.4-5.9 | 80-95 |
| game `_sight` | 378-455 | 102-110 | 3.8 |
| game `_solid` | 54-67 | 31-37 | 1.9 |
| game_land `_open` (bore / spawn) | 153-169 / 96-113 | 109-113 / 73-82 | 1.4 |
| trunk gather | 10.0 | 4.6 | 2.2 |
| steering round 14 trunks | 21.5 | 0.7 | 31 |

The tube case is the f7 spike (tight follow in the bore, the dodge scan
marching every line in 0.75 m steps): it should go from milliseconds to a
few tenths. Lines that leave the tube still pay `field.height` per point.

## Tests and checks

- `python tools/smoke.py studies/endless_flight.tscn`: PASS (also with
  `--sight-native=0`); `studies/burrower_study.tscn`, `flight_study.tscn`: PASS.
- `test_glide_camera.gd`: PASS. `test_native_collision_faces.gd` (the
  rebuilt library): PASS. No existing test touches LandTunnels, LandHalls
  or the burrower; none broken that I know of. The full suite was not run.
- `tools/ground_parity.py` was not run: the arches, rocks, Peak, ice and
  tree solid are untouched.

## Native build

Built on this PC (template_debug and template_release, MSVC, godot-cpp at
`<main>/builds/godot-cpp`, `python tools/build_native_kernels.py ... --scons
<scons.exe>`); `tools/native_stamp.py` says current. New classes start at
version 1 (BoreNative `HALL_VERSION`, `BORE_VERSION`, `STEER_VERSION`); the
existing classes are unchanged. The built DLLs are only in this worktree's
git-ignored `bin/`: copy them to the main checkout's
`native/terrain_kernels/bin/` once this is merged (not done). The Mac needs
its own build; until then it runs the GDScript, same answers.

## The FrameLog commit

`c29678b8` holds only the instrumentation (camera `c_*` marks, `n_sight` /
`s_tube` / `s_ice` / `s_march` adds, the burrower's `bt_*` marks); drop it
when the hunt is over. `b494e785` (the dodge scan's exact pruning, the log
opening once) is meant to stay.

## What a real flight must confirm

Fly the burrower's bore chase low and tight with `--frame-log`, as f7:
`s_tube` and `c_clear` in the tube should fall to a fraction (f7: `c_clear`
1.49 ms, `s_tube` 0.92 ms in tight follow, spikes 5-21 ms); `s_march` less
(~0.35 ms to maybe 0.1); `bt_move` some (its probes are mostly
`field.height`). The camera must behave exactly as before (same dodges,
same clears). Not covered: the GPU, a Mac, a world with surface halls
stood (the wilderness has none; the same class answers the tunnels'
stretches).

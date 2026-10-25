# The scope cut: handoff

On 2026-10-24 the project was cut down to endless flight. Everything cut is
whole at the tag `archive/before-the-cut` (commit `a0d5f517`, pushed to
GitHub); `docs/archive.md` lists each piece and how to bring it back.

## What changed

- **The front door.** `studies/endless_flight.tscn` is the main scene. The
  `GameState` autoload (the isles' objectives ledger) is gone; `RenderCap`
  stays.
- **No walking.** F on the wheels does nothing now (in the air it still
  works the flaps). `scripts/endless/endless_walker.gd` and `--on-foot` are
  gone, and the birds' "him on foot" lookup is safe without a walker. The
  cockpit pilot still sits in the plane.
- **The break system** moved from `scripts/kit_isle/` and
  `scripts/enemies/body_dust.gd` to `scripts/breaks/`, on its own: the
  Olmec's bulk sizes are copied in (`BULK_W`, `BULK_L`) and the noise-bus
  call is gone. Nothing in the game calls it yet. The hub (`breakables.gd`)
  already names a `plane` breaker, off.
- **Borrowed pieces** the land still uses moved to `scripts/shared/` (the
  kit land, flora, look and water, the turf lips, dirt paths, hanging roots,
  islet, slabs and swing rope, the trap base and gust, the aqueduct isle's
  art and flora, celestial, the falls' foam and mist, the gust arrows and
  fronts).
- **The cut.** About 1,400 code, shader and asset files, 101 tests, about 70
  tools, the design docs of cut work, the Blender sources of cut models and
  every cut scene's launcher. Kept scenes: `endless_flight`,
  `flight_study` (the flight packs and the crash) and `ruin_kit_gallery`.
- **Tools.** `tools/reach.py` (what a scene reaches, why a file is
  reached) and `tools/reach_deps.gd` (the dependencies of compressed binary
  scenes, from Godot) were the cut's own; `tools/README.md` and the root
  README describe the flight game only.

How the cut was chosen: everything the three kept scenes, `scripts/endless/`
and `scripts/breaks/` reach (res:// strings, class names, uid ids, shader
includes, Godot's own dependency list for binary scenes, plus the sea's
shaders loaded by a built-up name and all of `assets/audio/` and
`assets/fonts/`) stayed, and nothing else.

## Proof

- Smoke: endless flight (the default world, `--world=regions`,
  `--world=overgrown`), `flight_study` and `ruin_kit_gallery` pass with 0
  errors after every chunk.
- Every remaining script, scene and shader loads (515, 0 failures;
  `scratch/cut/load_all.gd`, uncommitted).
- The land's hash for seed 1 (native field) is unchanged: 0 of 78,627 spots
  differ.
- Rendered stills of the meadow, hills, river and cruise views before and
  after look the same (`scratch/cut/before`, `scratch/cut/after`).
- Through the real input (`scratch/cut/fly_land.gd`): a glide onto the
  meadow touches at 12.8 m/s and stops; F on the wheels makes no walker and
  never enters the landing's EXIT phase; Boost and back stick take off and
  climb past 8 m in 295 frames.
- The break system (`scratch/cut/breaks_check.gd`): three ruin pieces
  adopted, three hits each break one, five parts fall as bodies.
- Tests run: `test_ruin_kit`, `test_ruin_growth`, `test_sky_plane`,
  `test_glide_camera`, `test_flight_study`, `test_world_scale_guard`: all
  pass. The full suite (76 tests left) was not run.

## Seen, not caused by the cut

Stopped on the wheels with the brake held, the plane creeps about 6 m over
4.5 s (idle taxi, 1.6 m/s). The flight loop's only removed lines acted when
getting out, so it predates the cut.

## Left for later

- **Freeze the walker's numbers into the ruin kit**, then
  `scripts/pilot_motor.gd` and its pieces can go: `ruin_kit.gd` (`STAND`,
  `GRAB_TOP`, `CHAIN_TOP`), `ruin_kit_tower.gd` (the wall kick),
  `ruin_kit_keel.gd` (`SLIDE_AUTO`), and the gadgets that push him
  (`wind_horn.gd`, `dragon_air_blast.gd`, `slam.gd`, `traps/gust.gd`).
- **Untangle the old engine.** The endless grass still loads the aqueduct
  isle's flora and `sky_islets.gd`, which brings the garden and the native
  terrain families; the look loads `sky_below.gd` and the sky archipelago.
  It works; it is just more code than the game needs.
- **The cockpit pilot**: keep a figure in the plane or not, decided with
  the new plane's look.
- The window title is still "ZenScape — Landscape Sandbox"
  (`project.godot` `config/name`).
- `.claude/skills/enemy-build/` is for enemies, now out of scope.
- The branches `shelved/calm-olmec` and `shelved/river-mesh` exist only
  locally; the tag is on GitHub.

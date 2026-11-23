# ZenScape

Fly a small plane over land that never ends, and land anywhere flat.

### [⬇ Download for Windows](https://github.com/DavidKalina/zenscape-godot/releases/latest/download/ZenScape-windows-x64.zip) · [⬇ Download for Mac](https://github.com/DavidKalina/zenscape-godot/releases/latest/download/ZenScape-mac-universal.zip)

Builds of `main`, checked before they're posted. **Windows:** extract the zip
to its own folder and run **`ZenScape.exe`**; if SmartScreen stops it, click
**More info → Run anyway**. **Mac** (Apple silicon or Intel): unzip, drag
**`ZenScape.app`** to Applications, and the first time macOS blocks it, go to
**System Settings → Privacy & Security → Open Anyway**. Install notes and
controls: [ZenScape for Windows and Mac](docs/desktop-builds.md) ·
[all releases](https://github.com/DavidKalina/zenscape-godot/releases).

## Play from source

The game is endless flight: you fly a plane over procedural land that never
ends. Double-click **`run-endless-flight.command`** (Mac) or
**`run-endless-flight.cmd`** (Windows); both import first, so a fresh merge
never opens to an empty sea. Or open
`project.godot` in **Godot 4.7.2** (standard edition; no .NET needed) and
press **F5**. Both open `studies/endless_flight.tscn`.

Keys: WASD or the left stick bank and pitch (W nose down), the mouse steers,
Space boost, Shift brake, Q and E hold a knife edge (twice quickly, a barrel
roll, or click), F the flaps, hold the right mouse button to look round, R
back up into the air, F1 the numbers, Esc frees the mouse. Land on any flat
turf; stopped, Space rolls it off again. Pad controls are in
[gamepad](docs/gamepad.md). Flags such as `--seed=7`, `--world=regions` and
`--hour=17` are listed at the top of `studies/endless_flight.gd`.

How the downloads are built and posted, and exporting by hand:
[desktop builds](docs/desktop-builds.md#for-the-developer-how-builds-are-made).

## Structure

- `studies/endless_flight.gd`: the game's engine (the plane, the camera,
  streaming, the HUD). `scripts/endless/`: the land, sky, clouds, sea,
  rivers, grass, trees, birds, the ruins in the land, and the world profiles
  and regions (`scripts/endless/world/`).
- `scripts/sky_plane.gd`, `manual_landing.gd`, `plane_figure.gd`,
  `glide_camera.gd`: the plane, its hand landing, its look and the chase
  camera.
- `scripts/ruin_kit*.gd`: the ruin kit the arches, halls and tunnels are
  built from. `scripts/breaks/`: its break system (cut pieces, falling
  parts), kept for light destruction.
- `scripts/shared/`: pieces from the old sky isles the land still uses.
- `studies/flight_study.tscn` (a greybox flying course with the crash) and
  `studies/ruin_kit_gallery.tscn`: test beds.
- `native/terrain_kernels/`: the optional native terrain kernels
  (`tools/build_native_kernels.py`); without a built kernel the GDScript
  versions run.
- `docs/archive.md`: what was cut on 2026-10-24 (the isles, the walking
  character, the Olmec, enemies, the motif editor) and how to bring it back
  from the `archive/before-the-cut` tag.

## Checks

```sh
godot --headless --editor --path . --import
python3 tools/smoke.py studies/endless_flight.tscn
```

The test runner runs every script under `tests/`, headless, eight at a time,
and keeps each test's log and a JSON report:

```sh
python3 tools/run_tests.py                          # the whole headless suite
python3 tools/run_tests.py --quick                  # skip tests tagged slow
python3 tools/run_tests.py --tests 'test_sky_*.gd'  # repeat --tests for more globs
python3 tools/run_tests.py --list                   # what would run, with tags
```

A test declares what it needs with a `## suite:` line near its top:

- `## suite: gpu`: needs a real renderer (pixel readback, MultiMesh
  transforms, global shader parameters). Headless runs skip it and never count
  it as passing.
- `## suite: slow`: takes over a minute headless. `--quick` skips it, and it
  gets three times the per-test `--timeout` (180 s by default).
- `## suite: serial`: holds a frame-time or wall-clock budget that fails under
  load. It runs alone, after the parallel tests.

`tests/known_failures.txt` lists tests that fail for a recorded reason. They
still run, but they don't fail the suite. The runner says when one starts
passing so its line can go. Any other failure fails the run.

Headless uses Godot's dummy renderer, so a headless run doesn't replace the
visual checks. `--rendered --gpu-only` runs the gpu set in Forward+, which opens
windows and may take focus. Use it only when you mean to. Headless runs never
fall back to a graphical renderer. Use `--godot /path/to/Godot` to override the
executable.

The original Three.js ZenScape project remains a separate reference for
landscape recipes, atmosphere, water and wildlife. This project has no runtime
dependency on it.

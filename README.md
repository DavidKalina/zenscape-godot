# ZenScape

## Play

Double-click **`run-zenscape.command`**, or open `project.godot` in
**Godot 4.7.2** (standard edition; no .NET needed) and press **F5**. Both open
the front door, `studies/zenscape.tscn`: the title over the aqueduct isle
(`studies/aqueduct_isle.gd`), the camera orbiting it. **Begin** puts you on
foot beside your parked plane; **Scenes** opens every study and greybox;
**Settings** (look, day and night, weather, sound, controller); **Quit**.
`-- --no-title` goes straight in. The sky is live: the day turns (8 minutes a
day), the year turns from the real date's season, the weather drifts and
storms flash in the clouds (`scripts/kit_isle/kit_weather.gd`;
`--day-length=60 --weather=storm` to watch it fast). In the game, **Esc** or
the pad's **Menu** pauses: Resume, Back to the plane (also **R** on foot),
Settings, Scenes, Back to the title and Quit. The study's developer keys
(F1-F12, the station keys, L, B) and capture flags work only in editor and
debug runs. Pad controls are in [gamepad](docs/gamepad.md).

For a standalone Windows or Mac app, see
[desktop builds](docs/desktop-builds.md).

## Notes

`docs/scenic/` describes the aqueduct isle, the ruin kit, the motif isles, the
Sundered hall, the rune serpent, wind and clouds.

## Structure

- `studies/zenscape.tscn` and `scripts/kit_isle/front_door.gd`: the title and
  the game.
- `studies/aqueduct_isle.gd` with `scripts/kit_isle/`: the isle, its land,
  life, sky, sound and settings.
- `native/terrain_kernels/`: the optional native terrain kernels
  (`tools/build_native_kernels.py`); without a built kernel the GDScript
  versions run.

## Checks

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/test_landscape.gd
godot --headless --path . --script tests/test_garden.gd
godot --headless --path . --script tests/test_world_clock.gd
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

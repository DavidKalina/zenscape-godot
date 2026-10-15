# Test execution

Run automated Godot tests and imports with `--headless`. The user does not want
test windows opening or taking focus. The Python test runners default to headless.
See README.md's Checks section for commands and rendering limitations.

Do not automatically retry a failing headless test with a graphical renderer.
Report GPU-dependent checks as unverified when headless cannot exercise them;
do not weaken assertions or claim a full-suite pass. Use the runners' `--rendered`
option only when the user explicitly requests a graphical test.

Rendered captures to judge visual work (animation, models, looks, layouts)
are allowed without asking: one window at a time, short, quit by a watchdog.
Look at them yourself and iterate before handing off.

Run the suite with `python3 tools/run_tests.py` (headless, 8 jobs). A new test
that needs a real renderer gets a `## suite: gpu` line under `extends`, and one
that takes over a minute headless gets `## suite: slow`, and one with a timing budget gets `## suite: serial`. Don't add a test to
`tests/known_failures.txt` to get a run green. That file holds only failures
the user has accepted, each with its reason.

# The harness

Before writing a tool, read `tools/README.md`. It has a ready-made tool for
each of these: finding Godot and keeping the import fresh (`tools/godot.py`),
the smoke check (`tools/smoke.py`), checks through the real play loop
(`tools/harness/drive.gd` with `tools/drive.py`), seed and knob tables
(`tools/sweep.py`), rendered stills (`tools/shot.py`) and runs longer than the tool-call
limit (`tools/bg.py`). `python tools/index.py <word>` finds the older
one-off tools. Throwaway drivers go in `scratch/` (git-ignored). If a
round needs a tool the harness lacks, say so in its handoff.

# Running on Windows

The user develops on a Mac and sometimes on a Windows PC. The `run-*.command`
launchers, the Mac Godot path in the tools and the `/opt/homebrew/bin/blender`
lines in the Blender scripts' docstrings are Mac-only. On Windows, work in
PowerShell from the repo root:

- Install Godot **4.7.2** standard (win64, not .NET), Python 3.13 and
  Blender, e.g. `winget install Python.Python.3.13 BlenderFoundation.Blender`
  and Godot unzipped to `C:\Tools\Godot\` or from winget. Git LFS isn't needed.
  This PC has Godot from winget
  (`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\`) and
  Python as `python` (no `py`). The harness (`tools/godot.py`) finds either
  Godot on its own; `python tools/godot.py --where` prints the one it uses.
- Point the tools at Godot's **console** build (the plain `.exe` prints
  nothing to the terminal): `$env:GODOT = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"`.
  `tools/run_tests.py` reads `GODOT`; other tools take `--godot $env:GODOT`.
- Import: `& $env:GODOT --headless --editor --path . --import`.
- Play: `& $env:GODOT --path . --rendering-method forward_plus --windowed --resolution 1440x900 -- --no-title`.
  A study: put its scene after `--path .`, e.g. `studies/character_study.tscn`.
  A `run-*.command` file shows the scene and flags it launches.
- Tests: `python tools/run_tests.py` (same flags as above).
- Blender scripts: `& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --python art/blender/plane/plane_build.py`
  (or `blender` if it's on PATH).
- The native terrain kernels are optional; without them the GDScript
  versions run. Building them needs Visual Studio's C++ tools and SCons
  (`docs/desktop-builds.md`).

# Prototyping

The game is being prototyped: the user judges work by playing it. Until the
user asks to lock a feature in, a round proves its work with a smoke check (a
headless import, then its scene loaded for a few hundred frames with no script
errors) plus whatever throwaway check through the real play loop it needs,
left uncommitted. Committed tests come in a lock-in round the user asks for,
which also reconciles the tests prototypes broke. A round's handoff lists any
existing test its change breaks.

# Subagent models

Pick a subagent's model by what it makes:

- **Opus**, the default: physics, moving bodies, input, movement and feel,
  complex logic, animation (new clips and changes to existing ones) and new
  models. Brief it to prove the work through the real play loop and input
  path, not only scripted test ticks.
- **Sonnet**, assembly and looks: putting pieces that already exist together
  into a scene, layouts; shaders, materials, textures, reskins and
  other surface changes that leave shape, motion and collision alone.
- **Haiku**: names, labels and other small brainstorms.

A task that mixes kinds goes to Opus.

# Sizes

The plane's and the wanderer's sizes live only in `scripts/world_scale.gd`,
the one parser of `--plane-scale=` / `--wanderer-scale=` / `--opening-ratio=`.
Size a flown opening from its toy-era width (named in the file that owns it,
e.g. `TOY_THREAD := 3.5`) with `WorldScale.opening(toy_width)`: toy width x
plane x `RATIO` (1.0), floored at `SNUG` (1.2 m past each wingtip). At
`--plane-scale=1 --opening-ratio=1` every opening is its toy width exactly.
Use `gap(room)` only for spacing with no toy width, and a knife-edge slot
only on purpose with `knife()`. Derive walker reach, steps, ledges and jump
gaps from the wanderer size (`PilotMotor.set_size`,
`RuinKit.GRAB_TOP`/`CHAIN_TOP`). Other files ask WorldScale rather than
copy 2.0, 2.4, the ratio, 1.2 (`pilot_size`) or the toy span 1.4. Guarded by
`tests/test_world_scale_guard.gd` and `tests/test_world_scale_fit.gd`.

# Art direction

The world is painterly and the things in it are real. The grass, terrain,
sky and light are painted: soft shader grass, broad washes. Creatures,
stone and the wanderer are near-realistic weathered materials: they read
through real texture, not through bright colour or clean toy shapes.

- **The wanderer**: real, lived-in stuff: felt, knit, canvas, twill,
  scuffed leather, tarnished brass, sun-fade, and ochre dust up the boots
  (`shaders/pilot_paint.gdshader`, `scripts/pilot_paint.gd`). His hat stays readable from the
  high play camera.
- **Menace comes from material, weight and restraint**, not genre
  clichés. No horns, spikes, ember-red glows or black edgy stone; the
  user rejected that as too edgy and stereotypical. Glows stay dim and warm
  on stone.
- **Detail fades with distance**: work the weathering in solid noise over
  the model's rest pose, so it rides on a moving body. Fade fine layers
  by pixel footprint so they never shimmer. Let the broad washes and the
  value contrast carry the look at gameplay range.
- **Judge it by eye**, in rendered stills, at gameplay range and close,
  on the real painted terrain.

# Animation

Characters and enemies animate to a Nintendo-like bar: authored key poses
that read at a glance, anticipation, squash and stretch, follow-through,
snappy timing with holds, and weight that matches size. Author clips in
Blender (rig + actions exported to glb) and layer procedural corrections,
such as hands placed on the real wall, on top of them. Judge animation by
eye in rendered captures.

# Models

A round that makes or changes a model assesses the geometry tricks in
`docs/art/model-budget.md` and lists in its handoff which apply, with
estimated triangle and frame-time savings.

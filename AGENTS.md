# The game

The game is the aqueduct isle. The project's main scene,
`studies/zenscape.tscn` (`run-zenscape.command`), shows the title over the
aqueduct isle (`studies/aqueduct_isle.gd`, `scripts/kit_isle/`), and
**Begin** or `-- --no-title` puts you on foot beside the parked plane.
`run-aqueduct-isle.command` opens the isle directly. When the user says
"the game" or "the main scene", they mean this one.

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
Look at them yourself and iterate before handing off. Every windowed run
passes `-- --no-title`, or the title world shows up in the capture.

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
limit (`tools/bg.py`). A new RuinKit piece: `tools/kit_piece.py` (scaffold,
numbers, recipe, yard, check). `python tools/index.py <word>` finds the older
one-off tools. Throwaway drivers go in `scratch/` (git-ignored); before
writing one, run `python tools/drive.py --api` for the helpers it can call. If a
round needs a tool the harness lacks, say so in its handoff.

macOS has no `timeout`; wrapping a command in it silently does nothing. Use
the harness's watchdogs or `tools/bg.py`.

# Fresh worktrees

`native/terrain_kernels/bin/`, `zenscape_kernels.gdextension` and its
`.uid` are git-ignored, so a fresh worktree fails with "Could not find type
NativeTerrainData". Before anything else, run
`python tools/worktree.py setup <path>`: it copies those three from the main
checkout and runs the headless import. `--cache NAME` also copies a build's
cached files (scratch/cache/NAME, else scratch/NAME).

# Running on Windows

The user develops on a Mac and sometimes on a Windows PC. The `run-*.command`
launchers and the Mac Godot path in the tools are Mac-only. On Windows, work in
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
  A study: put its scene after `--path .`, e.g. `studies/motif_yard.tscn -- --motif=sundered_gorge`.
  A `run-*.command` file shows the scene and flags it launches.
- Tests: `python tools/run_tests.py` (same flags as above).
- Blender scripts: `python tools/blender.py run art/blender/plane/plane_build.py [-- args]`.
  It finds Blender (a Program Files install, else the Microsoft Store
  build's `blender-launcher.exe`, whose `blender.exe` gives Access denied
  and whose launcher drops the output and exit code), waits, relays the
  output and exits with the script's code. `--where` prints the one it uses.
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
existing test its change breaks. Run the full suite only when the user asks.

# Working with the user

- When the user is talking through ideas, only discuss. Start work, or add
  asks to a running agent, only on an explicit go.
- Delegated work goes one round per agent. A round ends with its commits and
  a short handoff doc, and the next round is a fresh agent briefed from that
  doc. A build that spans several stages, or would run long in one agent,
  runs as a loop of fresh agents instead (skill `iterate`). Size the brief to the ask: a demo or experiment gets the smallest
  playable build, a smoke check and a few-line note, with no bot sweeps,
  perf passes or extra tests unless asked.
- The user explores what the game is by playing it. Don't write a game
  pitch, pillars, taste rules or comparisons to other games into docs,
  comments, skills or handoffs unless the user asks. Skills describe
  mechanics (steps, contracts, proof) and stay general. Code, assets and
  tools built for earlier directions stay; they are tools.

# Landing turf

Every isle the plane can reach keeps a clear stretch of turf long enough
to land the plane by hand. Terrain added to an isle must not take it away.

# Handles

The user tunes what agents build by hand in the world view (F4 in the
aqueduct isle; `docs/design/world-editor/world-editor-handoff.md`). So
placement code names its pieces: it asks `scripts/layout_overrides.gd` for
each piece, islet or platform section by a stable name (`<route>/<piece>`),
the user's moves in the layout file win over the coded spot, and a
procedural build (a stair, a run) also shows its knobs. Keep those names
stable; saved layouts key on them.

# The motif editor

The user hand-authors motifs in `studies/motif_editor.tscn` (design and
rounds: `docs/design/motif-editor/level-editor*.md`). Its saves,
`motifs/authored/*.json`, are recipes (piece ids, seeds, settings,
transforms) rebuilt from the current code on every load. So when you change
RuinKit pieces, KitLand, flora or the motif contract:

- Keep piece ids stable; a rename breaks saved motifs.
- A piece whose size or shape changes gets its connectors updated in
  `scripts/ruin_kit_fit.gd`.
- Keep KitLand and flora changes additive or opt-in (the editor's `stable`
  mode), so existing motifs build as before. Smoke a kit motif and an
  `editor_*` one in the motif yard.

Work that touches none of these can ignore the editor.

# Subagent models

Pick a subagent's model by what it makes:

- **Opus**, the default: physics, moving bodies, input, movement and feel,
  complex logic, animation (new clips and changes to existing ones), new
  models, new kit pieces, new motif places (land, routes and threat under
  the real motor) and the combo lab. Brief it to prove
  the work through the real play loop and input path, not only scripted test
  ticks.
- **Sonnet**, assembly and looks: putting pieces that already exist together
  into a scene, motifs, layouts; shaders, materials, textures, reskins and
  other surface changes that leave shape, motion and collision alone.
- **Haiku**: names, labels and other small brainstorms, and code search:
  the `scout` agent (`.claude/agents/scout.md`).

A task that mixes kinds goes to Opus.

To learn the code before working, any agent sends `scout`s instead of
reading files itself or using Explore: one narrow question per scout, and
several in one message when the question spans areas (up to about 5). The
scouts return short `path:line` reports; read only the lines they point
to.

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
`tests/test_world_scale_guard.gd`.

# Animation

Characters and enemies animate to a high bar: authored key poses
that read at a glance, anticipation, squash and stretch, follow-through,
snappy timing with holds, and weight that matches size. Author clips in
Blender (rig + actions exported to glb) and layer procedural corrections,
such as hands placed on the real wall, on top of them. Judge animation by
eye in rendered captures.

# Models

A round that makes or changes a model assesses the geometry tricks in
`docs/art/model-budget.md` and lists in its handoff which apply, with
estimated triangle and frame-time savings.

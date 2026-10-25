# The game

The game is endless flight: you fly the plane over procedural land that
never ends (hills, mountains, cliffs, lakes, rivers, coast and sea, with
bird flocks, overgrown halls and tunnels and scattered ruins) and land
anywhere flat. Its scene is `studies/endless_flight.tscn`, the project's
main scene (`run-endless-flight.command`; design and rounds:
`docs/design/endless-flight/`). It is to ship on Steam. When the user says
"the game" or "the main scene", they mean endless flight.

In scope: the plane, its flight, landing and the camera; the land, sky,
water and ambience; collectibles and flying challenges (the flight packs in
`studies/flight_study.tscn`); light destruction of the ruins
(`scripts/breaks/`). Out of scope: walking (cut on 2026-10-24), enemies,
treasure heists, the Olmec, hearts and damage.

On 2026-10-24 everything else was cut: the aqueduct isle and the kit isles,
the motif editor, the walking character, the Olmec and the city kit,
enemies and their studies. They are whole at the git tag
`archive/before-the-cut`; `docs/archive.md` lists each and how to bring it
back. The walker's motor went too (2026-10-25): the ruin kit keeps the
walker's numbers it was sized by as frozen constants.

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
- Play: `.\run-endless-flight.cmd` (double-click, or launch flags after it,
  e.g. `.\run-endless-flight.cmd --weight=heavy`). It runs `tools/play.py`,
  which finds Godot, imports if needed and opens the window. By hand:
  `& $env:GODOT --path . --rendering-method forward_plus --windowed --resolution 1440x900 -- --no-title`.
  A study: put its scene after `--path .`, e.g. `studies/flight_study.tscn -- --pack=lines`.
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

# Meadows and flats

The land always has meadows and flats in reach: wherever the plane is
over land, a flat stretch long enough to land by hand is never far off.
Terrain, kinds of place and dressing added to the land must not take that
away.

# Handles

Placement code names its pieces: it asks `scripts/layout_overrides.gd` for
each piece by a stable name (`<route>/<piece>`), and the moves in the layout
file (`layouts/<scene>.json`) win over the coded spot; the slot halls read
theirs this way (`scripts/endless/hall_sites.gd`). Keep those names stable;
saved layouts key on them. (The in-world editor that wrote layout files,
F4, was part of the aqueduct isle and is in the archive.)

# The ruin kit

The arches, halls and tunnels in the land are built from RuinKit pieces
(`scripts/ruin_kit*.gd`). Keep piece ids stable: the land's recipes and the
break kinds (`scripts/breaks/break_kinds.gd` `KIND_OF`) name them.

# Subagent models

Pick a subagent's model by what it makes:

- **Opus**, the default: physics, moving bodies, input, movement and feel,
  complex logic, animation (new clips and changes to existing ones), new
  models, new kit pieces, new kinds of place in the land. Brief it to prove
  the work through the real play loop and input path, not only scripted test
  ticks.
- **Sonnet**, assembly and looks: putting pieces that already exist together
  into a scene, layouts; shaders, materials, textures, reskins and
  other surface changes that leave shape, motion and collision alone.
- **Haiku**: names, labels and other small brainstorms, and code search:
  the `scout` agent (`.claude/agents/scout.md`).

A task that mixes kinds goes to Opus.

To learn the code before working, any agent sends `scout`s instead of
reading files itself or using Explore: one narrow question per scout, and
several in one message when the question spans areas (up to about 5). The
scouts return short `path:line` reports; read only the lines they point
to. A scout's list is a lead, not a census: before an edit that must reach
every call site, every user of a name or every file a change touches, run
that grep yourself.

# Sizes

The plane's and the wanderer's sizes live only in `scripts/world_scale.gd`,
the one parser of `--plane-scale=` / `--wanderer-scale=` / `--opening-ratio=`.
Size a flown opening from its toy-era width (named in the file that owns it,
e.g. `TOY_THREAD := 3.5`) with `WorldScale.opening(toy_width)`: toy width x
plane x `RATIO` (1.0), floored at `SNUG` (1.2 m past each wingtip). At
`--plane-scale=1 --opening-ratio=1` every opening is its toy width exactly.
Use `gap(room)` only for spacing with no toy width, and a knife-edge slot
only on purpose with `knife()`. The ruin kit's steps, ledges and jump gaps
come from the walker's numbers, frozen in the kit when the walker was cut
(`RuinKit.STAND`, `GRAB_TOP`/`CHAIN_TOP`, the tower's kick). Other files ask WorldScale rather than
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

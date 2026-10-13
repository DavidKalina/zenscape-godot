# Test execution

Run automated Godot tests and imports with `--headless`. The user does not want
test windows opening or taking focus. The Python test runners default to headless.
See README.md's Checks section for commands and rendering limitations.

Do not automatically retry a failing headless test with a graphical renderer.
Report GPU-dependent checks as unverified when headless cannot exercise them;
do not weaken assertions or claim a full-suite pass. Use the runners' `--rendered`
option only when the user explicitly requests a graphical test or visual capture.

Run the suite with `python3 tools/run_tests.py` (headless, 8 jobs). A new test
that needs a real renderer gets a `## suite: gpu` line under `extends`, and one
that takes over a minute headless gets `## suite: slow`, and one with a timing budget gets `## suite: serial`. Don't add a test to
`tests/known_failures.txt` to get a run green. That file holds only failures
the user has accepted, each with its reason.

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
  complex logic, graphics, shaders, art, new kit pieces. Brief it to prove the
  work through the real play loop and input path, not only scripted test ticks.
- **Sonnet**, assembly: putting pieces that already exist together into a
  scene, motifs, layouts.
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

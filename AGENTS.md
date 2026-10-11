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

# Sizes

The plane's and the wanderer's sizes live only in `scripts/world_scale.gd`,
the one parser of `--plane-scale=` / `--wanderer-scale=`. Size a flown gap
with its `gap(room)` or `span` (a toy-sized base with `TOY_SPAN`): at least
`SNUG` room (1.2 m past each wingtip), `ROOM` by default, and a knife-edge
slot only on purpose with `knife()`. Derive walker reach, steps, ledges
and jump gaps from the wanderer size (`PilotMotor.set_size`,
`RuinKit.GRAB_TOP`/`CHAIN_TOP`). Other files ask WorldScale rather than
copy 2.0, 2.4, 1.2 (`pilot_size`) or the toy span 1.4. Guarded by
`tests/test_world_scale_guard.gd` and `tests/test_world_scale_fit.gd`.

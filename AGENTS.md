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

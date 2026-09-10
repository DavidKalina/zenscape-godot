# PR #10 integration with main

Merged main `eb3458a` into the PR head `45b231d`, retaining both the cave/living
slice and main's environmental behavior, fire, terrain, and desktop-export work.

The six textual conflicts are resolved. Main's desktop workflow, native-kernel
README, and release verifier are retained byte-for-byte; both study introductions
remain in the root README. Habitat interests keep tree categories and bounds as
well as cave clearance. The resident scene initializes both activity owners.

Quiet environmental activities and cave/living journeys respect each other's
ownership. Lightning still interrupts a home visit. Projectiles and needs advance
exactly once when the environment owns the resident, and pause freezes all three.
The new `test_bigfoot_living_environment.gd` exercises those boundaries in the
actual cave scene. Its helper also accommodates existing standalone test worlds.

## Validation

All 12 selected native tests pass: eight cleanly, four with the previously
recorded Godot light-unpair teardown diagnostics. Coverage includes cave movement,
fishing, needs/activities, main-game save/reopen, environmental interactions,
tree hugs, fire behavior and transactions, and desktop entry.

The initial integrated autonomous run exposed a stopped needs clock during
an environmental activity. After correcting the shared clock, the five-minute
run passed with home checks, fishing, meals, sleep, gathering, and bedding
improvement. Save/reopen and the ownership regression also passed again.

The export-verifier Python syntax and equality of the retained desktop CI files
were checked. This is focused integration validation; the old full-suite report
is preserved as historical evidence, not presented as a run of the merged tree.
See [per-test results](pr10-merge-verification.json).

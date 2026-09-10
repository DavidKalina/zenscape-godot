# Regression audit against a15b607

The completed native sweep ran **197 tests: 165 clean passes, 5 passes with
classified engine diagnostics, 26 failures and 1 timeout**. The suite does not
pass. Separate baseline comparisons and corrected-current reruns distinguish
existing failures from fixes and unresolved differences; they do not rewrite the
original sweep.

The four suite runs used Godot 4.7.2 native Metal Forward+ with the runner's
640×480 starting resolution. Later resident diagnostics requested windowed
1440×900. Individual tests and saved display settings can override these requests. Baseline comparisons ran
at commit `a15b607` in `/private/tmp/zenscape-bigfoot-living-baseline`.

## Evidence

| Run | Results | Outcome |
| --- | --- | --- |
| Full current sweep | `/tmp/bigfoot-living-final-suite/results.json` | 197 completed; 27 unsuccessful |
| Original baseline tests | `/tmp/bigfoot-living-baseline-comparison/results.json` | 21 completed; 19 unsuccessful, 2 clean passes |
| Corrected-current targeted checks | `/tmp/bigfoot-living-postfix-tests/results.json` | All 5 passed: lair, foraging, living-store, living-world, routine-actor; 4 retain classified light-unpair diagnostics |
| Focused current comparisons | `/tmp/bigfoot-living-paired-followups/results.json` | 6 completed; camera passed, 5 unsuccessful |
| Resident input diagnostics | `/tmp/bigfoot-resident-diagnostic-current.stdout`, `/tmp/bigfoot-resident-diagnostic-baseline.stdout` | Both retain the original assertions and pass with observation logging; no production or harness fix applied |

Each JSON entry includes its command, stdout/engine logs, assertion diagnostics,
and duration. The full source comparison used `git show a15b607:<path>`. A failure
is called reproduced on baseline only when its relevant diagnostic matches;
merely sharing a failed exit code or an unchanged test is insufficient.

## Final dispositions

All names below refer to `tests/test_<name>.gd`.

| Test | Disposition | Evidence that determines the disposition |
| --- | --- | --- |
| authoring_preparation | Existing startup mismatch, source-supported | Test immediately reads uninitialized UI; baseline main initialization awaits two frames. The null dereference prevents its final quit and causes the timeout. |
| bigfoot_home | Existing startup mismatch, source-supported | Test waits one frame before reading the editor; baseline requires two. |
| creature_deliberation | Existing startup mismatch, source-supported | Same one-frame wait, then null editor/actor calls. |
| editor_coherence | Existing startup mismatch, source-supported | Same one-frame wait, then null palette access. |
| redwood_grove | Existing startup mismatch, source-supported | Reads editor immediately after adding the main scene. |
| bigfoot_lair | Introduced lighting regression fixed; current rerun passed | New BedWindowBounce initially omitted shadows. Enabling shadows satisfies the existing light-layer test. |
| bigfoot_habits | Failure reproduced on baseline | Same five missing-bed/progression/visit assertions. |
| bigfoot_routine_day | Failure reproduced on baseline | Same six assertions, only stone completed, identical 1.3820304265 distance. |
| bigfoot_routine_world | Failure reproduced on baseline | Same sit-completion, sleep-loop and sleep-mark assertions. |
| bigfoot_wetness | Failure reproduced on baseline | Same shared-source-material-dry assertion. |
| connected_formation_water | Failure reproduced on baseline | Same three redwood_grove route/cascade/visibility assertions. |
| fidelity_life | Failure reproduced on baseline | Same two movement assertions, 0.70 traveled and 29 moving frames. |
| formation_responsiveness | Threshold failure reproduced on baseline | Both exceed the 50ms foundation bound: current 68.695ms, baseline 58.750ms. This establishes an existing failure, not equivalent performance. |
| native_asset_catalog | Failure reproduced on baseline | Same 17-asset expectation and missing raw desert-cactus node. |
| native_build_palette | Renderer diagnostic reproduced on baseline | Both report zero assertion failures but the same four null-material RD renderer errors. Neither is a clean pass. |
| native_build_tools | Failure reproduced on baseline | Same missing sky-row control at test line 111. |
| native_editor_hotkeys | Failure reproduced on baseline | Same flower-preview-radius assertion. |
| native_mountain_shape | Failure reproduced on baseline | Same 24-unit peak-limit assertion. |
| nature_audio | Failure and teardown diagnostic reproduced on baseline | Same four gait-count assertions and two-resources-in-use message. |
| performance_trace | Failure reproduced on baseline | Same automatic capture stop/save assertion. |
| resident_gust | Failure reproduced on baseline | Same initial aiming failure, downstream gust failures and empty gust-array access. |
| camera_exploration | Original failure not reproduced | Baseline and focused current rerun both pass. This does not establish the original intermittent failure's cause. |
| bigfoot_mischief | Existing unstable native check; differing signatures, source-equivalent active path | Current repeat fails stone continuity; baseline instead fails windup, stone completion and launch under player interruption. Both fail, but these are different faults. |
| display_fog | Existing unstable native check; differing signatures, unchanged active path | Current repeat fails restored-camera/terrain fog comparisons. Baseline instead reports image accesses beyond width 640 while the test expects larger dimensions. |
| log_animation | Existing unstable native check; differing signatures, source-equivalent active path | Current repeat fails reaching carry for changed-path testing, then its dependent blocked-path assertion. Baseline instead fails initial overhead/carry/completion checks. |
| native_drop_reactions | Existing failing/unstable native check; partial signature match, unchanged active path | Both fail catalog coverage. Baseline then aborts on empty placed-object array; current reaches and fails the later paused-reaction-count assertion. |
| resident_interaction | Unstable input/window-dependent legacy verification; feature regression not demonstrated | Raw baseline passes and raw current repeats fail; observation-only diagnostics retaining the original assertions pass on both. Exact first-failure cause is not conclusively reproduced. |

The differing native signatures above are not matching reproductions and remain
unsuccessful original tests. Four have unchanged or semantically equivalent
active paths, established below. Resident input diagnostics pass on both
versions and expose window/live-pointer dependence, but do not establish the
exact cause of its original failure. This is not a green-suite claim, a claim
that every failure is identical on baseline, or a claim that a production input
bug was fixed.

## Confirmed fixes and current coverage

Two production issues introduced during this work were corrected:

- The new bed bounce light now casts shadows. The corrected native lair test
  passes, with separately classified renderer light-unpair diagnostics.
- An inactive living controller's cancellation path could clear hand targets
  owned by legacy routines during their own world edits. Cancellation now
  respects ownership. The updated living-world regression exercises the idle
  cancellation guard, and corrected-current routine-actor/foraging tests pass.

Corrected-current living-store and living-world tests also pass, covering real
study-to-main save/reopen, source-backed food ownership, generic editable-tree
collection, actual pickup interruption, visible room consequences and autonomous
activity. These targeted passes do not replace the unresolved legacy tests above.

## Causal source evidence

These references explain the source-supported dispositions and several baseline
failures without relying only on unchanged file names. Line numbers below refer
to `a15b607`.

**Main startup:** `studies/diorama.gd:36–43` awaits two process frames before
`super._ready()`, and line 68 prepares authoring UI. In contrast:
`test_authoring_preparation.gd:11–13` reads UI immediately;
`test_bigfoot_home.gd:17–22`, `test_creature_deliberation.gd:14–18`, and
`test_editor_coherence.gd:23–28` wait only one frame;
`test_redwood_grove.gd:11–15` reads the editor immediately. The baseline
`new_diorama()` dereferences `_chunk_editor.forming` at line 383. These exact
statements explain the observed null accesses before living behavior executes.

**Autonomous simulation cadence:** `test_bigfoot_habits.gd:11–12,32–39` and
`test_bigfoot_routine_day.gd:21–30` advance hundreds of simulation ticks per real
frame; `test_fidelity_life.gd:21–31` yields no real frame during its 3,600 ticks.
`creature_route_query.gd:27–35` suspends work on real process frames after a
1,500-microsecond budget, and `creature_brain.gd:221–223` blocks routine choices
while planning. The baseline runs reproduce the failed behavior; this scheduling
mismatch explains why elapsed simulation ticks alone do not guarantee progress.

**Sit lifecycle:** personality is enabled at `bigfoot_personality.gd:4`.
`bigfoot_routine.gd:389–394` gives the Sit loop alone eight seconds before
StandUp, but `test_bigfoot_routine_world.gd:30–33` allows only seven seconds for
the entire sequence. Lines 34–38 then force sleep while that sequence remains
unfinished, making the sleep assertions dependent on the first invalid premise.

**Redwood water:** `native_landscape_presets.gd:6` includes redwood_grove, but
`native_formation_water.gd:9–49` only creates routes for the other families.
`test_connected_formation_water.gd:13–16` demands routes for every preset; its
visibility assertion at line 28 evaluates `0 < 0` when routes are absent.
`test_redwood_grove.gd:21` separately documents that this grove intentionally
leaves water to the builder.

**Catalog and editor expectations:** `native_asset_catalog.gd:4–25` defines 21
assets, while its test expects 17 at line 22. Production's
`source_node()` synthesizes desert-cactus at lines 59–71; the test bypasses it and
reads raw geometry at line 44. `native_chunk_editor.gd:294–303` restores per-kind
placement settings, and lines 317–318 make flower radius `0.15*object_scale`;
`test_native_editor_hotkeys.gd:58–62` incorrectly expects a flower to inherit tree
scale 2. `native_terrain_data.gd:6,915–924` permits height 64 and scales a detailed
mountain shape that is not clamped to one (`native_mountain_shape.gd:55–60`), while
its test assumes 24 is the editing limit.

**Reaction coverage:** `native_terrain_data.gd:8` includes explosive, cactus and
layered_tree, but `native_drop_reactions.gd:29–55` omits those IDs. Test lines
85–87 demand a reaction for every non-waterfall asset. This proves only the
catalog assertion; it does not explain the later current paused-count failure.

**Gait counts:** `bigfoot_personality.gd:14–18` installs HeavyWalk with four
steps per loop and reference speed 0.85; `creature_actor.gd:122` uses that gait's
speed. `test_nature_audio.gd:63–76` assumes the older two-step gait and fixed
cumulative counts of four/eight. Its later idle/frozen assertions reuse those
counts instead of comparing before and after. Both gait failures and the separate
resource diagnostic reproduce on baseline.

**Source-equivalent active paths for differing native signatures:**
`test_bigfoot_mischief.gd` and `test_log_animation.gd` instantiate
`god_mode_playground`, whose inheritance chain is `bigfoot_life` →
`wind_playground` → `bigfoot_playground` → `fidelity` (each script's first line).
This chain never creates `BigfootRoutine` or the new living controller. The only
reachable changed brain conditions add the `interest_choices_enabled` guard,
which defaults to true (`creature_brain.gd:21`); its sole writer is in the absent
`bigfoot_routine.gd:57`. Those conditions therefore have the same result as on
baseline. Motion, physics, animation, assets and test sampling in these scenes
are unchanged. Both original tests also fail on baseline, albeit at different
assertions. These are existing unstable native checks with source-equivalent
active logic, not green tests or exact diagnostic matches.

`test_display_fog.gd` and `test_native_drop_reactions.gd` instantiate plain
`studies/fidelity.tscn`, whose script is `fidelity.gd`, not `fidelity_life.gd`.
That scene creates neither CreatureBrain nor BigfootRoutine/living. Its
renderer, shaders, reactions, UI and assets are unchanged. The new optional store
hooks are guarded by methods that this plain scene does not implement; the new
reference-memory remap callback belongs to main-only migration, unused here.
Consequently no changed living gameplay/rendering path explains the unmatched
native signatures. The catalog reaction failure does match baseline; the
baseline's earlier empty-array abort gives no direct equivalent paused-count
assertion. The baseline fog run's width-640 bounds errors likewise do not prove
an identical round-trip-image failure. Preserve these precise limits while
classifying the source-equivalent failing checks as existing/native instability.

**Resident input and runner limits:** resident interaction waits for
`title_loaded`, so its failure is not an immediate-startup null case. The raw
baseline passed; raw current runs failed, including a repeat with windowed CLI
arguments. Observation-only copies preserving the original assertions were then
run on both versions using identical `--windowed --resolution 1440x900`; both
reported `RESIDENT INTERACTION failures=0`.

The diagnostics recorded fullscreen mode 3 on both versions despite the CLI
request, root/OS size 3024×1898, logical viewport 1512×949, content size 1440×960,
and scale factor 2. The project sets `window/size/mode=3`, and application display
settings override the requested mode/size. Injected pickup events used roughly
(756,454), while the live cursor remained (603,632) on current and (671,499) on
baseline. The unchanged `resident_interaction.gd:144–145` recomputes hover and
feedback from `get_viewport().get_mouse_position()`, rather than retaining the
synthetic event position. This supplies a concrete source of input/window and
real-frame dependence that the raw test does not control.

Current diagnostic ownership remained `living.enabled=false`, `current=""`, and
`phase=""`; pickup and gust assertions passed without activating living behavior.
The diagnostic evidence supports classifying this as unstable legacy native
input verification, not a demonstrated feature regression. It does not reproduce
and explain the exact first failure conclusively: logging itself can change
frame timing. No production input fix or permanent test-harness change was made,
and the original unsuccessful results remain recorded.

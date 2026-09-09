# Budgeted roaming decisions

The resident's transition from standing to choosing a walk could block the main thread. A seeded redwood-preset reproduction measured 58 ms for the reported decision, and 350–1854 ms for other choices. Instrumentation traced most of the worst case to route straightening: 1270 swept segment checks, about 1.69 seconds inside straightening alone. This was CPU work, independent of image capture.

## Change

- Shortcut smoothing searches at most eight nearby grid points with a bounded search, rather than repeatedly testing long chords back from the destination.
- Endpoint connections search nearby navigation cells instead of scanning the whole map.
- Habitat collision checks use spatial buckets but retain the original footprint, vertical clearance, and water checks.
- Automatic roaming decisions use `creature_route_query.gd`, yielding between terrain probes and graph expansions under a 1500-microsecond budget. Actor animation and rendering continue while a difficult decision completes. Explicit existing synchronous route APIs remain available to other callers.
- Pending decisions are discarded on pickup, pause, map changes, disabled AI, or a superseding decision. No partial route is published.
- F9 performance captures include whether a decision is pending and the last completed decision's peak slice and slice count.

## Validation

`tests/test_ai_decision_budget.gd` loads the actual Diorama redwood preset and exercises eight seeded choices. Before: 58.252, 1854.180, 1398.738, 349.466, 497.839, 36.577, 201.841, 35.582 ms blocking decisions. After: peak slices of 1.541, 1.577, 1.568, 1.555, 1.520, 1.526, 1.589, 1.521 ms. Difficult decisions now complete across frames; measured wall time was 77–1344 ms, during which gameplay continues. The regression asserts safe completed routes, an 8 ms ceiling with scheduling margin, and cancellation on pickup, pause, and map replacement.

`tests/test_route_query.gd` checks equivalent reachability for detours, complete walls and thin barriers, validates every published leg, and compares indexed clearance against the previous full scan at 10,404 positions/heights. Existing navigation, brain behavior, live editing, and main-world interaction tests also pass.

Measurements are from macOS on an M5 Pro, not Windows. The fix changes shared GDScript CPU work and is applicable to Windows, but Windows frame pacing still requires measurement there. A concurrent live-render run had a slower non-AI baseline, so it is not used to claim an FPS improvement. Use F9 on Windows to capture a representative session without recording images.

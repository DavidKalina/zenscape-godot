# Connected landscapes verification

Verified on 2026-09-08 with Godot 4.7.2, including native Metal rendering.

## Functional checks

All passed:

- `test_landscape_presets.gd`: seven families and 35 family/biome combinations,
  undo/redo, palette independence, biome editing and save roundtrips.
- `test_connected_formation_water.gd`: descending valid streams, channel clearance,
  individual pool levels and basin bounds, JSON roundtrips, animated cascade
  geometry, sculpted obstruction invalidation and undo recovery.
- `test_landscape_variations.gd`: four seeds across each family, reproducibility,
  retained family/biome/palette, connected/quiet switching and undo.
- `test_landscape_favorites.gd`: edited terrain and scene persistence, thumbnails,
  library reload, complete restore undo/redo, invalid input without mutation,
  actual panel saving, small-window layout and recoverable removal.
- Regression suites: curated looks, diorama flow, native stream editor,
  native range and command palette. Command palette ran with native rendering
  because it captures a viewport image and tests the mouse pointer.

Baseline channel stations obscured by the faceted ground: 0/83 valley, 0/34
plateau, 0/37 cone, 0/40 ridgeback, 0/34 horn, 0/83 canyon, 0/30 terraces.
This is sampled coverage, not proof of every point or every possible variation.

## Visual checks

All seven family previews were regenerated and inspected after adding cascades.
The gallery and Favorites were rendered at normal and 960×640 window sizes.
Opening the authoring panel hides competing build controls. Saved thumbnails
exclude the UI. Capture tools use isolated temporary libraries.

`connected-water-comparison.mp4` shows 96 frames at 24 fps, moving water left
and frozen water right. The scene and camera are held fixed. Frame 95 was
inspected against the control; changed water detail is visible in both terrace
cascades. Comparing frames 0 and 95 at a maximum-channel threshold of 0.025:
3,276 changed pixels in the flow reel, zero in the control. Raw results are in
`water-motion-proof.json`.

## Boundaries

Courses are curated downhill geometry with animated surfaces, not simulated
fluid mass or erosion. Four seeds per family were checked; the full variation
cycle was not exhaustively rendered. Water switching and generating another
composition reform the landscape, with one-step undo for prior edits.

Headless runs report the existing macOS certificate warning and some ObjectDB
shutdown leak warnings. Asset import completed; sandboxed editor shutdown could
not save global editor preferences. Native UI regression completed without
failures. `git diff --check` passed.

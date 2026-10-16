# Handoff: the slope tool reads in edit mode

**Cause.** The land does rebuild with the slope in edit mode. A scratch
driver dragged a slope through real mouse events on `editor_trap_demo` and
`editor_mountain`. Turf rays along the ramp matched `motif.ground()` within
0.15 m about 0.45 s after release. A coarse land comes first, then the
worker's full detail swaps in. Play's `rb.finish_now()` only makes that
swap happen sooner. The ramp just had nothing that made it read as a
slope. It is turf like the hill round it, flat-shaded in the grey look, and
steep (44-54 deg). From the editing camera it looked like a few terraces
gone, often behind a piece. In the coarse stage the terraces are gone
everywhere. You only felt it once he slid on it in play.

**Fix.** Each slope gets an edit-mode skin (`studies/motif_editor_slope.gd`
`mark` / `show_marks`). It is a warm translucent tint over the ramp's band,
fainter over the level run-out, with chevrons down the fall line (steps get
only the tint). The skin is a mesh with no collider. It is rebuilt in
`_after_land` on every stand (drag, undo, load), so it shows straight after
release even over the coarse land. It is shown while editing and hidden in
play through `_set_markers_visible`. Saves, strokes and the terrain are
unchanged.

**Proof.** The smoke of `studies/motif_editor.tscn` passes, with and
without `--load=editor_trap_demo`. The scratch driver `scratch/slope_edit.gd`
passes headless and rendered: marks after the drag, hidden in play, back in
edit, and gone after undo. Rendered stills: `scratch/shots/fr_sheet.png` is
before the fix, `scratch/shots/fix_sheet.png` and `fix2_sheet.png` are
after.

**Tests.** No existing test is known to break. The full suite was not run.
Not addressed: the coarse stage's whole-hill look for about 0.4 s after
any land edit on terraced isles (it loses the terraces until the detail
lands).

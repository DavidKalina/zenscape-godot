# Quick create: command palette

Launch `./run-nursery.command` in this worktree. The diorama starts clear, with a small current-tool / shortcut button at the bottom.

- **Command K / Control K:** open or dismiss focused search, including from Inspect.
- **All, Shape, Land, Plant, Miniatures, Water, Sky, Actions:** browse categories.
- **Type:** filter tools, actual low-poly miniature assets, weather presets and actions. “Pine” finds Tree.
- **Up / Down, Enter:** highlight and choose a result. Choosing closes the palette.
- **Escape or click outside:** dismiss without changing the current tool.
- **Previous / Next, Page Up / Page Down:** browse results. Eight cards per page, six in the minimum window. No scrollbars.
- **Drag a miniature:** the palette folds away and the existing terrain ghost carries the asset into the scene. Release to place; release outside the window to cancel.
- **Settings icon beside the launcher:** current tool controls and actions, paginated when needed. Sky settings is searchable under Actions.

Selected-object controls appear near the object. Advanced shape controls replace the basic page rather than extending a scrolling inspector. They hide while search is open. The existing placement, selection, undo and save implementations are reused.

The persistent sidebar and bottom asset tray were replaced by this palette following the user's revised direction. The other Bigfoot prototype and the original Electron Grow choreography remain separate work. No merge into main.

## Evidence and verification

`landscape.png` shows the closed UI. `plants.png`, `objects.png`, `all.png`, `search.png`, and `compact.png` are real Godot captures. `command-palette.mp4` shows opening, browsing, searching, choosing and placing.

- `tests/test_command_palette.gd`: open/dismiss, focused search, alias filtering, keyboard selection, all results reachable through pages, empty search, modal input exclusion, minimum-window bounds, and paginated settings without scrollbars.
- `tests/test_native_build_palette.gd`: existing tile selection, rendered portraits, drag placement, ghosts, cancellation, undo/save, mountain stamps, colors/actions and sky controls.
- `tests/test_native_selection.gd`: picking, moving, transformations, colors, duplication, undo/save and contextual settings bounds.

Capture with `Godot --path . --script res://tools/capture_command_palette.gd -- --film`. Frames are written to `/private/tmp/command-palette-frames` for encoding at 24 fps. Tests/captures run on Godot 4.7.2 / Metal / Forward+.

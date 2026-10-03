# Editing a diorama after placement

The first maker slice is existing-prop editing. In Build, choose **Place → Select** or press **V**, then click an authored tree, rock, flower, catalog prop, arch or Bigfoot tree. Click the visible mesh, including a canopy. Drag on terrain to move; releasing outside the terrain keeps the last valid position. A corner marker identifies the selected piece.

The compact inspector offers size, rotation, color, duplication and deletion. Shape & elevation exposes proportions, tilt and ground-relative elevation for ordinary props. Arch and Bigfoot tree retain their existing size/rotation restrictions. A duplicate appears nearby and becomes selected. Delete/Backspace removes the selection; Cmd/Ctrl+D duplicates it. Undo/redo groups a drag or inspector pointer gesture. Text fields retain normal text-editing keys.

The save format is unchanged. Selection and highlight are transient; object IDs, transforms, colors and positions survive Save/Open. Opening a file clears selection. Editing or duplicating generated flora makes it user-owned, so populating flora again preserves the customized piece; undo restores that ownership too.

## Hands-on scene

`run-selection-garden.command` (removed) opens the separate `selection-garden.json` demonstration made through computer use. It has a generated ridge, streams, waterfall, ground cover and 3,493 props. Two trees were customized through the inspector: an enlarged green tree at the front left and a taller gold copy at the front right. The ordinary garden save remains separate.

The live pass exercised canopy selection, drag, drag undo, size and rotation, duplication, color picker, proportions, deletion, undo/redo and saving. Automated integration additionally verifies reopening, live color preview, paused placement reactions, and inspector layout on shorter windows.

## Scope and next steps

This selects authored object records, including generated native flora. Captured source-scene decorations are not authored records. Mountains, painted cover, ponds and waterfalls are still edited with their existing terrain/water tools; editable landform entities and draggable inhabitants are later slices.

Next: evaluate everyday building with this editing loop before adding mountain identity or character interactions. Improve selection visibility in dense forests and direct manipulation controls based on use. Distinctive movement and placement charm can build on this foundation.

## Validation

All 81 GPU tests pass with Metal Forward+. The first surface-haze run printed PASS but timed out during engine shutdown; its isolated retry exited normally. `full-suite.json` retains both outcomes. Existing six-instance ObjectDB shutdown warnings also remain; this is not a leak-cleanliness claim. A separate capture reopened all 3,493 saved records and produced `inspector.png` and `landscape.png`.

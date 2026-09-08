# Contextual tool rail experiment

Run `run-nursery.command` to try the garden with the persistent rail.

- Select, Sculpt, Paint, Place, and Water are tool families. Each remembers its last tool; Place remembers the chosen catalog item.
- Cmd/Ctrl K still opens the searchable catalog. Closing it preserves the active tool.
- Ordinary placements stay active across clicks. Escape returns to Select.
- Flowers (including all four catalog flower forms) and Mountain support Drag to paint. Turn it off for individual stamps. Movement spaces the stamps; holding still does not pile them up. One drag is one undo step.
- Bigfoot is a single placement that returns to Select. Choosing him again moves the existing actor.
- Settings exposes the active tool's controls. Ground and Range have explicit whole-landscape actions here; selecting them no longer immediately forms the landscape. Use Mountain's drag mode to draw local ridges.

The old palette finished placement on mouse-down, resetting the tool and immediately closing brush transactions. Ordinary placements now leave tool selection intact; release closes the stroke.

Validation on Godot 4.7.2 with Metal / Forward+: `test_command_palette.gd`, `test_native_build_palette.gd`, `test_native_chunk_editor.gd`, and `test_native_editor_hotkeys.gd` all report zero failures. The palette suite also emits renderer null-material diagnostics during ghost cleanup. The headless editor test cannot validate its rendered water-map assertions, so the editor suite was rerun with rendering enabled.

![Rail with flowers selected](preview.png)

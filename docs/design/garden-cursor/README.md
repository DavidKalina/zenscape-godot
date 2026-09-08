# Garden glove cursor

A lightweight native Godot drawing, with cream fingers, a plum cuff and gold trim. The exact pointer location is a small gold target above the glove; it does not ease or lag. Only the hand pose animates.

- Open hand while hovering the world.
- Curled fingers while carrying a palette piece, dragging a miniature, or moving a selected object.
- A brief squeeze and expanding target ring on successful placement.
- Relaxed release on cancellation; a new grab immediately interrupts that release.
- Standard system cursor over UI, outside the viewport, when the window loses focus, and after leaving/freeing the editor. Captured mouse modes are not overridden.
- Dragging retains the world ghost, without a redundant thumbnail covering the hand.

`comparison.mp4` is a close crop of identical scripted pointer paths: animated glove left, plain drawn pointer right. Carry starts at 1.0 seconds, placement at 2.75, and cancellation at 4.375. `glove.mp4` shows the complete game view. Captured with `tools/capture_garden_cursor.gd`; this adapts the A/B film workflow to the native Godot renderer. The scene is shared between the two captures, with only the pointer changed.

Validation: command-palette integration suite passes, including placement feedback, carrying pose, cancellation, and restoring the system cursor. No image assets or dependencies are required for the glove.

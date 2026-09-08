# Floating nursery — first Godot pass

Run `./run-nursery.command` from this worktree. It opens the real fidelity scene directly in Build with the Arch miniature selected. The preview uses current game meshes, materials and placement paths.

The bottom dock uses brown-purple translucent stone, a mip-filtered backdrop blur and a feathered edge. Visible miniature portraits rotate at 0.28 radians/second (roughly 22 seconds per turn), rendering at most 24 updates per second. Offscreen tiles and hidden categories retain a static texture. Hover and press have a small scale response.

Shape, Land, Plant, Miniatures, Water and Sky keep the existing tool groups. Tune opens the current tool's settings and actions above the dock; it adapts to available height and scrolls in short windows. Undo/redo remain directly available. Scene opens the existing save/open and study controls; entering Build otherwise folds that large panel away. Placement, drag ghosts and history use the original editor implementation.

This pass establishes the dock's appearance and motion. Plant exposes the existing cover tools; it does not yet introduce the original Electron Grow choreography or the other prototype's draggable Bigfoot inhabitant. The existing Bigfoot-tree miniature remains available.

## Evidence

- `miniatures.png`: actual game capture, 1800 × 1200.
- `miniatures.mp4`: four seconds of the rotating shelf with the world paused.
- `rotation-comparison.mp4`: rotating shelf on the left, frozen first-frame control on the right.
- `plant.png`, `sky.png`, `tune.png`: additional toolbar states.
- `compact.png`, `compact-tune.png`: 960 × 640 minimum-window checks.

Capture with `Godot --path . --script res://tools/capture_nursery.gd -- --film`. The capture checks visible animation, hidden-category inactivity, hidden-dock inactivity and panel bounds. Its frame sequence is written to `/private/tmp/nursery-frames`. `miniatures_animate` allows the shell or capture code to disable rotation.

The existing `tests/test_native_build_palette.gd` exercises rendered portraits, selection/hotkeys, catalog pieces, per-tool settings/actions, drag placement, ghosts, cancellation, undo/save, mountain stamping and Sky controls. It also checks the detached Tune panel's input exclusion. All passed on Godot 4.7.2 / Forward+ / Metal.

Backdrop blur uses the screen's filtered mip chain and a soft distance mask, rather than a full-screen multi-pass Gaussian. This keeps the first iteration small; overall frame-time impact has not yet been profiled.

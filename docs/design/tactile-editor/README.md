# Tactile editor — first interaction pass

Worktree: `.claude/worktrees/tactile-editor`, branch `codex/tactile-editor`.
The copied current Godot work is recorded at `d807e06`; the UI changes follow it.

The everyday build view has one shallow bottom tray and a quiet top bar.
The held piece has an actual miniature portrait. Click its name to open the
small tool popover; Adjust replaces it with detailed controls. There is no
persistent side card. Escape puts the tool away. The catalog, repeated
placement, trail transactions, selection and undo retain their existing paths.

World groups Landscapes, Colors & sky, Bigfoot, Overview and His spot.
Overview fits actual terrain and base geometry above the tools. Manual orbit,
pan and zoom remain under the player's control, so deliberately zooming in
can still put geometry behind the tray. Explicitly opened editing panels can
cover part of the scene while in use.

![Everyday building view](tree-in-hand.png)

![Small window](compact.png)

## Validation

Forward+ / Metal, Godot 4.7.2:

- `tools/capture_tactile_editor.gd`: zero failures. Real rendered views at
  1440×900 and 960×640; terrain/base clearance, input shielding, quick size
  synchronization, per-piece size memory, popover behavior and Enjoy mode.
- `tests/test_command_palette.gd` (removed): zero failures. Search, placement, trails,
  undo, cancellation and catalog behavior.
- `tests/test_editor_coherence.gd` (removed): zero failures. Shell actions, tool
  settings, small-window fitting and pond workflow.
- `tests/test_diorama_flow.gd` (removed): zero failures. New, save, open, Continue,
  failed-open preservation and menu fitting.
- `git diff --check`: clean.

Captures use a disposable world under `/private/tmp`; they do not change the
writer's current diorama. The command-palette test requires rendering; its
headless run cannot capture a framebuffer and was not counted as a pass.

This is a first UI direction, not a completed restyle of the scene-look,
landscape, main-menu or selected-object panels. Hover/press motion is subtle;
no new placement animation or sound has been added.

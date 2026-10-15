# Game v1: the launcher and the title (2026-10-14)

Part of the v1 stitch round (`game-v1-brief.md`). Branch `feature/v1-launcher`.

## How to run it

Double-click `run-game.command` (Mac). Windows: the PowerShell line in
AGENTS.md "Running on Windows". It opens on the title; Space, Enter or a
pad's A starts the run; Escape or a pad's B quits. Extra flags win:
`./run-game.command --seed=7 --shape=ring`. Log: `$TMPDIR/zenscape-game-launch.log`
(the launcher flags a script error in it, as `run-underground.command` does).

## What was built

- `studies/game_title.tscn`, `scripts/roguelike/game_title.gd`: ZENSCAPE in
  the isle card's gilt inscription (`Splash.inscription_font`,
  `gilt_material`), a hairline, and "Press Space / A to begin" breathing under
  it. Everything fades up from black over 2.2 s; on begin the screen goes to
  black in 0.6 s, then `LaunchArgs.open_scene` opens `studies/run_layer.tscn`
  with the title's own launch flags.
- `shaders/game_title_backdrop.gdshader`: procedural underground backdrop:
  four ranks of columns going back into fog, a torch's pool low left that
  flickers, a pale shaft of far sky from above (the climb's goal), dust
  drifting up, vignette and grain. No textures.
- `run-game.command`: the launcher, shaped like `run-underground.command`.
- The name lives in `game_title.gd` `TITLE` (and the loading screen's own
  `title` export in `loading_screen.tscn`, which still reads ZENSCAPE).

## The flags and why

| Flag | Why |
|---|---|
| `--no-title` | Keeps the aqueduct isle base from its own title; our title is a separate scene. |
| `--shape=sprawl` | The run's first region; the run alternates sprawl and ring by depth by itself (`layer_shapes.gd` RUN). Under sprawl the run loop is on. |
| `--underground=torch` | The underground torch look. |
| no `--seed=` | `run_layer` draws a random seed each launch. The card's Space draws a new one, R keeps it. |
| no `--dragon-live` | No dragon. The plane is not in this scene. |
| nothing for the Olmec | Bodies are already on (`bodies` knob 1, `--body-chase` on by default). No new flag needed. |

The death card's retry is untouched.

## Proof

Headless import clean. Smoke: `studies/game_title.tscn` 400 frames, 0 errors;
`studies/run_layer.tscn -- --shape=sprawl --underground=torch --seed=3`
400 frames, 0 errors. Throwaway driver (`scratch/title_start.gd`, uncommitted):
a real Space key event on the title opens `run_layer`, which becomes
walkable with the shape carried and a seed drawn. A rendered still of the
title was judged by eye and iterated once (columns were flat slabs; now
rounded, lit from the torch side, sunk in the dark at their feet).
Headless cannot draw the canvas shader, so the title's look and the
fade-to-black timing were seen only in the one still.

## Existing tests broken

None known; not run (prototype round, no full suite).

## Seams

- The loading screen that follows the title is the daylight sky one
  (`loading_screen.gd`), so the cut from the dark title is a bright jump.
  Not mine to change here; a dark underground variant of it would match.
- Seed is drawn inside `run_layer` rather than passed in, so the launcher
  does not know it. `--seed=` still works if wanted.
- `begin()` carries every launch flag through `LaunchArgs.override`; a
  `static var` in the run that read flags before the title would not see
  them (none do: the title never loads `run_layer`).
- No pause/quit-to-title from the run; Escape in the run is whatever the
  study does today.

## Windows

There is no `.ps1` pattern, so this line is the Windows launcher. It belongs
in AGENTS.md's "Running on Windows" section. It was kept out of that file
for now because AGENTS.md has uncommitted edits from another session.

    & $env:GODOT --path . --rendering-method forward_plus --windowed --resolution 1440x900 studies/game_title.tscn -- --no-title --shape=sprawl --underground=torch

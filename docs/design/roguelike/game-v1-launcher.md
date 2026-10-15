# Game v1: the launcher and the title (2026-10-14)

Part of the v1 stitch round. Branch `feature/v1-launcher`.

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

## The 3D title (feature/v1-title-3d)

The procedural backdrop is gone from the scene (`shaders/game_title_backdrop.gdshader`
is kept, unused). The overlay (wordmark, hairline, breathing prompt, Space /
Enter / A begins with the fade to black, Escape / B quits) lies over two real 3D
shots, plus a soft dark wash down from the top so the wordmark holds on the clouds.

- **Shot 1, the dark city** (`scripts/roguelike/game_title_scene.gd`): the city
  kit's epic stair on pillar C, the causeway on from its summit to pillar A and
  its drum stair (the city kit gallery's arrangement), fire bowls along them
  (`city_kit_fires.gd` cresset, lit, supporting light only), painted grass
  (`GroundCover` "grass") on C's crown, eight far pillar-isles with lit beacon
  towers and a temple pyramid in the haze. The underground look in its haze
  preset (ambient 0.62, exposure 0.95, fog 0.0032 over the preset).
  Architecture is the subject.
- **Shot 2, the sky** (`scripts/roguelike/game_title_sky.gd`): the Aqueduct of
  Veyl (`studies/aqueduct_isle.tscn`, no title, scripted, HUD hidden, in its
  own SubViewport) orbited from above, the sunlit world over the dark one the
  run starts in. The title holds shot 1 for 11 s after the fade-in, goes to
  black for 1.1 s while the isle stands, then comes up on the sky and stays.
- **Orbits.** City: eye 62 m out and 36 m up from (0,6,-4) looking at
  (0,4,-26), swung +-0.8 rad either side of the stair's foot by sin(t*0.028),
  fastest turn 0.0224 rad/s (front_door's SPEED is 0.0230). Sky: front_door's
  orbit (SPEED TAU/60*0.22), POLAR 1.28, LIFT 8, DISTANCE 1.0, FOV 50.
- **Timing** (headless, M-series Mac): the city shot builds in about 1.3 s; the
  sky isle in about 2.6 s (the fixed cache of the art helps after the first
  launch), under black. The title is up in about 1.5 s.
- Flags: `--title-shot=sky|city` shows one shot alone (stills),
  `--orbit-t=<s>` starts the city sweep partway.
- **Seams.** The sky build freezes the frame for its 2-3 s, hidden by the black
  cut. The city shot's lights are the shared global shader params
  (`zs_under`); freeing the city backdrop resets them, and `GroundCover.grade("")`
  hands the shared grass back to the day before the sky isle stands. The sky
  isle plays its own ambient life (birds, wind) behind the title. The sky
  shot stays until a key; it does not cycle back to the city. Under run-game's
  `--underground=torch` flag the sky isle's args are stripped of it while it
  builds, then restored. Existing tests touching `game_title` not run.

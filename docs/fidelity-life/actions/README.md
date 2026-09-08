# Routine playback and authoring

- `routine-preview.mp4`: normal-speed highlights from the autonomous session.
- `autonomous-day.mp4`: four uninterrupted minutes in the full Fidelity world.
  Stone 0:08, tree 0:24, sitting 0:39, fishing 0:56, nap 1:10, second cycle,
  hibernation 2:41–3:44, and a final stone throw at 3:54.
- `stone-world.mp4`: real loose stone grasp and throw beyond the world edge.
- `tree-world.mp4`: actual trunk/canopy shaking, then restoration.
- `fish-world.mp4`: actual pond fish scoop and return.
- `sit-world.mp4`, `sleep-world.mp4`: bank resting and drifting sleep Zs.
- `animation-review.mp4`: authored action on the left, unchanged Idle on the
  right, matching camera and lighting. Sit/stand (0–5 s), stone (5–9.4), tree
  (9.7–14), fish (14.2–19), sleep (19.2–27.3), stand (27.3–29).

The action/control reel isolates animation; the world reels verify interaction.
The full session is neither sped up nor driven by action requests. Reproduce
with `tools/film_fidelity_day.gd` or `tools/film_fidelity_actions.gd -- --kind=fish`
using Godot Movie Maker, Forward+ and fixed 60 FPS. Encode the AVI output as H.264
with ffmpeg. Per-action PNGs capture selected contact/performance moments.

Authoring source: `art/blender/bigfoot/zenscape-bigfoot-routine.blend`.
Export: `assets/models/zenscape-bigfoot-routine.glb`.
Generator: `tools/animate_bigfoot_routine.py`. It opens the original interactions
rig and writes a separate copy. `--replace-generated` regenerates that copy;
do not use it after manually editing the generated Blender file.

Seven new clips: SitDown, Sit, StandUp, Sleep, StoneThrow, TreeShake, FishCatch.
`../routine-animation-validation.json` records floor/foot clearance and hand
samples. `tools/validate_bigfoot_routine.py` verifies exact original animation
sample preservation (`../existing-clips-preserved.json`). Runtime hand correction
matches actual object heights; resting alignment fits supported dry banks.

Full behavior, controls, limits and regression results: `../README.md`.

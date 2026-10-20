# Olmec look: the hunt stride and eye contact (lane olmec-look)

**Play:** `godot --path . res://studies/crag_reach.tscn -- --no-title --olmec`
(also olmec_field `--whole-olmec`, whole_body_chase).

- **The hunt stride** (`hunt_stride`, art/blender/headless_body/headless_body_build.py):
  whole and chasing, he walks on this clip instead of the arms-out `stride`. He stays upright
  (per the user's redirect: no hunch), chest up, stump level. His arms hang heavy at his sides,
  a little out, fists closed, and swing short and late. Each footfall drops his hips and holds,
  his shoulders roll over the planted foot, and the stump nods and counters the roll. The step
  length is the stride's (STRIDE_STEP), so the feet match the game's phase. The headless
  homing walk keeps `stride`, arms out for its head. The boss's `shoulder_run` is unchanged.
- **Eye contact** (`scripts/enemies/olmec_gaze.gd`): while he's whole and hunting, or sees
  you, his head turns on the stump to your eyes, a point between the wanderer's head and the
  camera. Only the head's skin turns. His facing, the draw's cone and the choices he makes are
  untouched. The gaze is sprung in the world, so it stays locked on you while the body turns
  under it. It moves in saccades: it holds still, then jumps when you are 4 degrees off. On a
  spot it holds still 0.12 s, then snaps with an overshoot. Held more than 50 degrees round for
  0.7 s, the head slowly cocks to one side. The turn is clamped at 125 degrees of yaw, 40 up
  and 32 down. It lets go in suck, gulp, swat, smash, scope, triumph, reach and feel.
- **Model:** the geometry is unchanged (only a clip was added), so none of the
  docs/art/model-budget.md tricks apply. The re-export stores constant channels as 2 keys
  (glb 4.4 to 3.8 MB). The clips are the same.
- **Proof (uncommitted, scratch/):** smoke passes for crag_reach `--olmec`, olmec_field,
  olmec_field `--phase=2` and whole_body_chase. A headless crag-reach log shows the gaze on
  through the climb, the mantle and the plant, and off in the suck. Sheets are in
  scratch/olmec_look/.
- **Tests at risk:** none found that reference these files. The full suite was not run.

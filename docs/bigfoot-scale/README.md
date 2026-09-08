# Bigfoot woodland size trial

117 trees, shrubs, ground-cover plants and rocks surround a central opening.
The deterministic seed is 1847. Trees use size 1.25–2.05; both images use the
same terrain, camera, light, feet position and frozen pose.

- `current.png`: existing visual size.
- `smaller.png`: 70% visual size.
- `woodland.json`: editable woodland with the resident at normal gameplay size.

The trial scales the visual rig only. Gameplay size, navigation clearance,
carrying, reach and animations have not been retuned or changed globally.

Reproduce with Godot `--path . --script tools/render_bigfoot_scale.gd`.
Append `-- --hold` to leave an interactive Current size / 70% size comparison
open. These controls use a frozen scene for a fair silhouette comparison.

The current worktree emits an unrelated existing parse error in
`native_formation_shape.gd` (inference for `mesa`); the renderer nonetheless
completed and its two output images were visually inspected. No formation
code was altered by this trial.

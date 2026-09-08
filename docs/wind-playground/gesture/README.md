# Wind gesture polish

Run `run-wind-playground.command`. Drag the ground to aim, then release to send
wind. The aiming arrow follows the endpoint ground heights. Escape cancels;
pause, focus loss and switching modes clear unfinished gestures. Right drag
still orbits. The existing Breeze / Gust / Blast choices control the force.

Pale ribbons flow along the actual wind direction. Their speed and width scale
with strength; opacity follows the same attack/decay envelope as the force.
The shader uses explicit simulation age, so pause freezes the visible flow.
Visuals subscribe to LocalWindField updates, including in the inherited
`bigfoot_life` editable-world scene. This pass does not add a wind tool to the
separate `fidelity_life` scene.

`comparison.mp4`: new feedback on the left; the same physical gust without the
new feedback on the right. Camera, world, seed and gust strengths are matched.
Aim appears at 0.5 s; a gust fires at 1.5 s; a gentler breeze fires at 4.83 s.
`gust.mp4` is the full-size effect reel. `tools/film_wind_gesture.gd` reproduces
both with fixed 60 FPS and Godot Movie Maker (`-- --control` for the control).

Validation: actual camera-projected drag direction and physical response;
Escape, pause and focus-loss cancellation; visual/force clock agreement;
expired/replaced gust cleanup; capacity remains bounded to eight active gusts.
`tests/test_wind_playground.gd` and `tests/test_wind_gust_visuals.gd` pass.
The underlying LocalWindField sampling test also passes.

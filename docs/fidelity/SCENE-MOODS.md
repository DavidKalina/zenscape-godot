# Scene moods

Three buttons near the top of the controls combine existing lighting, cloud,
wind and fog systems: Warm evening, Morning mist, and Aurora night. They stop
the day cycle at the selected time while motion continues. Individual controls
remain editable. Weather clears immediately; fog and wind ease to their targets,
and accumulated snow/ice retain their normal thaw behavior.

The CLI accepts `--mood=0`, `--mood=1`, or `--mood=2` for reproducible previews.
`scene-moods.jpg` shows evening, morning, and night from left to right. All three
were rendered and visually inspected at the normal camera, rather than judged
against source pixel differences. The evening time was moved earlier after the
first preview left too much of the landscape in darkness.

The morning preview exposed inversion paint whitening the below-ground diorama
base. Surface inversion now excludes positions below y=0; the imported landscape
floor is above that plane. This is a deliberate visual improvement for this
scene, not a universal rule for future terrain below sea level. Regression checks
retain inversion on landscape surfaces and verify the base stays unpainted.

These presets support the updated goal: close resemblance and a beautiful,
responsive native scene, with room for Godot-specific choices. The environmental
systems and interactions still need a broader hands-on pass before completion.

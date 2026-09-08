# Visible weather wind

Ambient wind now carries sparse animated wisps automatically in the shared
Fidelity weather system, including Fidelity Life and the editor/playground
subclasses. No drag gesture or gust button is needed. The existing Wind slider
controls their density and speed; new curves follow the smoothed weather angle. Curves stay anchored at their
birth position and height; the shader draws flowing strokes along their fixed
sine-wave shape, without translating or bobbing the whole ribbon.
Calm produces no wisps, and existing ones fade as the weather calms. Pause freezes
the explicit shader clock. Terrain reveal hides the layer
until the ground is present.

The visual layer does not inject physical gusts. Vegetation, water and creatures
retain their existing weather response. It uses a local deterministic random
source, a shared ribbon mesh and at most twelve live parcels. Terrain heights
come from the current editable native data.

`anchored-vs-moving.mp4` compares the revised anchored curves (left) with the
previous translating, terrain-following ribbons (right). `ambient-wind.mp4`
shows the current anchored animation.

`comparison.mp4` records the initial version: animated weather wind on the left, matching weather with the
visual layer hidden on the right. Full Fidelity world, wind 1.2, fixed camera,
ten seconds, no user input. Wisps are especially visible over the pond and lower
right forest around six seconds. 
Reproduce with `tools/film_weather_wind.gd`, fixed 60 FPS, Forward+ and Godot
Movie Maker; append `-- --control` for the control.

Checks: `test_weather_wind_trails.gd` covers automatic births, calm, anchored curves over changing terrain and wind, pause, bounded population, expiration/cleanup, missing terrain and absence
of injected gust events. `test_wind.gd` confirms the existing source wind strength,
travel and pause behavior. Both pass. Effect and control frames were inspected.

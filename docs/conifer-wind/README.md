# Gentle conifer wind

Editable pines now use a dedicated wind response instead of the crown's generic
foliage sway. Trunk and crown share a height-weighted bend: roots are fixed,
lower trunks barely move, and crowns follow the passing wind. Cone rims receive
a small crosswind flutter. World-space direction survives asset yaw and scale.

Three samples of the traveling field, delayed by 0, 0.7, and 1.4 seconds, soften
the atmospheric response. This is a shader approximation of a slow response,
not a spring simulation or stored motion history. Local gusts also bend pines.
No new per-tree CPU update or mesh instances are added.

`comparison.mp4`: new response LEFT, previous generic crown sway RIGHT. Same
camera and wind, with a gust at 0.5 seconds. Look at the pine just right of the
middle pool. Eight seconds at 24 FPS, filmed with `tools/film_conifer_wind.gd`.
The benchmark's copied reflection materials retain their initial settings in
both reels; the comparison isolates the directly visible pine materials.

`tests/test_conifer_wind.gd` passed on native Godot 4.7.2 / Metal. It checks
downwind crown movement, rotated/scaled instances, root anchoring, restrained
lower trunks, calm air, and unchanged pose with frozen clocks. Native recording
also verified integration with the terrain renderer.

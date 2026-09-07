# Native alpenglow checkpoint

Sun elevation now drives the original alpenglow strength, climbing shadow line,
post-sunset peak glow and sunset-facing direction. Cloud cover suppresses both
terms. Dawn runs the same elevation curve in reverse. The existing time slider
and day/night cycle control it; no extra user switch is needed.

reference_surface.gdshader preserves hemisphere emission while gating Lambert
and GGX direct diffuse/specular by the source noisy height line. Afterglow uses
source height, face orientation and partially desaturated albedo before tone
mapping. Native fog sunlight uses the same altitude line. The custom direct-light
function follows Godot's LIGHT_COLOR/PI convention:
https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html
This changes the material's direct-light implementation from Godot's built-in
GGX to the explicit Lambert/GGX expression; reflected sky lighting remains native.

export_alpenglow.mjs extracts source expressions into fixtures. Native
test_alpenglow.gd checks 36 dawn/dusk combinations across sun elevations and
cloud cover, normalized facing, and the diagnostic --no-alpenglow control.

alpenglow-comparison.png: Godot LEFT, original Three.js RIGHT. Both use the
saved seed-7 camera, phase .755, cloud .06 and wind .4, with mist dial .45.
Native and source images were visually inspected. The original browser was
advanced one second at fixed phase. Native capture advances real time until its
capture threshold, so wind/birds/water are not frame-matched. The summit's rose
paint is close; the waterfall and valley fog visibly differ. This still does
not verify the complete moving dawn/dusk transition.

The separate water/fall shaders now share the altitude direct-light gate and
inversion treatment. Remaining: source-matched fog and water lighting, and
moving sunrise/sunset comparisons. Terrain minimum currently uses the captured
scene's .15; procedural worlds need the full ground-range bus.

Dawn inversion was subsequently added; see INVERSION.md.

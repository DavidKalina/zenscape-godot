# One valley, nine moods

Run `./run-valley-palettes.command`. This study holds terrain, tree placement, river, and initial camera fixed while applying all nine existing SceneLookPresets.

Keys 1–9 select Alpine morning, Golden meadow, Copper autumn, Rosewater dusk, Enchanted forest, Halloween hollow, First snow, Nordic night, and After the rain. Sliders adjust hour, mist strength (0–3 times the mood setting), and cloud altitude. Selecting a mood restores its defaults. K toggles the new cloud banks; P freezes drift; C restores overview; F focuses Bigfoot; Space orbits. Geometry editing is disabled in this study.

## Findings

Snow, dusk, and night produce strongly distinct readings of the same geometry. Autumn changes the ground and forest palette, but with conifers alone it is more subdued than a forest with deciduous crowns. The dark canyon floor can lose tree detail under some daylight directions. Mist can conceal the river when pushed high; that is a useful composition limit rather than an automatic improvement.

Two prototype-specific overrides previously limited the palette: hard-coded cliff color replaced palette shading and weather snow, and local fog kept a constant glow at night. Separate study shaders now apply palette rock color before wetness/snow, and local fog uses the mood's fog tint and a daylight-dependent glow. Original mountain and valley studies remain unchanged. The nine authored mood definitions are reused unchanged.

## Verification

Native Godot Metal Forward+ captures compare all nine moods at a fixed camera and cloud time. The capture harness asserts byte-identical terrain snapshots after each mood, including planting and river records. It also revisits Alpine after all nine, exercises all three sliders, and captures the UI. No script/shader errors in the capture run; the inherited six ObjectDB exit leaks remain. Visual validation does not establish real-time performance.

[Comparison gallery](index.html). Generated captures stay local and can be regenerated with `tools/prototype_capture_valley_palettes.gd` in native Godot Forward+.

User verdict pending.

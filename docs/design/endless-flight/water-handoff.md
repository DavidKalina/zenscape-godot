# Endless flight water round

What changed: endless flight's sea is a new shader, `shaders/endless_sea.gdshader`, fed by `scripts/endless/endless_sea.gd`. EndlessLook wires it in.

- Waves: four Gerstner swells move the sheet near the eye. Two noise normal maps scroll at three scales for the chop. Each layer fades into roughness once it is finer than a pixel.
- Colour by real depth (sea level minus land height): a 512² map of the land's height over 4 km round the eye, baked on a worker each time the eye moves 900 m. Turquoise shallows run through mid blue and deep blue to an abyss blue.
- Reflection: fresnel toward the hour's sky, the cloud field mirrored from the cloud shade map, a short screen-space march for the land and the plane, a soft sun path and a crisp, hard-edged glitter.
- Foam: a broken line at the shore, slow bands rolling in over the shelf (out to 7 m deep), and a touch on the sharpest crests.
- Wake: the plane's last 40 points, one every 0.12 s while it flies under 7 m (full strength at 1.6 m). Only the nearest point of the track counts, so you get one V. The arms ride out at 0.3 of the plane's speed, with a short churned streak behind the plane, a softly stirred band between the arms and ripples. It fades out by 4.8 s.

Flags: `--water=old` brings back the earlier sea (`shaders/sky_ocean.gdshader`). `--no-wake` turns the wake off. `--sea-set=name:value;name:value` sets any of the shader's uniforms by hand, e.g. `--sea-set=shore_foam:0.9;wash_depth:9.0`. Launch: `./run-endless-flight.command`, or `godot --path . res://studies/endless_flight.tscn -- --no-title`.

Cost (3024x1898 window, vsync off, open sea, 600 frames): median frame 9.4-10.4 ms new against 8.8-11.8 ms old. The runs are noisy, because other windows were open, so call it about +1 ms at most. The GPU timer reads 0 on Metal, so the GPU share is unverified. The depth bake runs on a worker; the first bake is synchronous at start.

Captures: `captures/water/{new,old}_{coast_alt70_0,shore_30,opensea_sun_60,wake_chase_90,wake_high_90}.png`. Same seed (1) and hour; drivers `scratch/water_cap.gd` and `scratch/water_perf.gd`, run by `scratch/water_final.sh`.

What's left:
- The wake is hard to see from the default chase camera, because its arms fall outside the frame at grazing angles.
- The bands roll in smooth, not broken.
- The mirror shows faint dark specks of the plane behind it at about 6 m.
- The endless land has no lakes or rivers of its own: its inland water is land below sea level under the same sheet, so it takes the same depth colour and shore foam. I didn't capture an inland pool on its own.
- The wake doesn't know about land, so it can draw across a beach the plane skims.

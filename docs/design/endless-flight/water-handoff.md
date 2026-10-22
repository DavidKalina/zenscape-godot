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

## Surface round (finer ripples, reflections off the rippled normal)

Two fine ripple layers (1.3 m and 0.55 m tiles, `ripple_size`/`ripple_strength`, faded by pixel footprint like the other layers) and stronger chop (`detail_strength` 0.30/0.22/0.15). The sky mirror, fresnel (`calm_share` 0.9), soft sun path (`path_share` 0.7) and ray-march normal (`mirror_calm` 0.85) now see most of the detail slope, so reflections and glints break up. Swell, colour, foam, wake and motion untouched. `--sea-surface=old` restores the previous surface values; `--water=old` still gives the original sea. Syntax: `--sea-set=ripple_strength:Vector2(0.3,0.2);calm_share:1.0;detail_strength:Vector3(0.3,0.22,0.15);ripple_size:Vector2(1.3,0.55);path_share:0.7;mirror_calm:0.85` (values go through str_to_var; no ':' or ';' inside values). Cost: no measurable change (about 8.9 ms median both ways, CPU/vsync-bound; GPU timer reads 0 on Metal). Captures: `captures/water2/{new,old}_{opensea_sun_60,coast_alt70_0,close_60}.png`. Left: swell crests are still the same smooth Gerstner form (peakier, form-and-fade crests are the next round); the far sea reads fine but was not stress-tested for shimmer in motion.

## Motion round (a live surface instead of a shaken sheet)

`sea_motion` 1 (the default; `--sea-motion=old` gives the surface round, `--sea-surface=old` the first round, `--water=old` the original sea). In `shaders/endless_sea.gdshader`:

- Swell (`zs_swell_live`): eight Gerstner waves in two trains crossing `swell_cross.x` rad apart (the second at `swell_cross.y` of the height), slope divided by the sheet's squeeze so crests are peaked and troughs flat (`swell_peak`, 1 = cusp), crests bent by a slow phase warp, and each wave rising and dying in its own groups a few lengths long riding at half its speed (`swell_groups`, 0 = even). Live mode runs `swell` 0.75.
- Chop (`zs_chop_live`): the three noise layers cross-fade between two copies that live `flow_cycle` s (scaled by sqrt size) and jump, so lumps rise and fade as they drift; three directions, speeds from the deep-water law. The fine ripple noise is replaced by wave packets (`wavelet_size` 2.5..0.25 m, `wavelet_strength` 0.25, `wavelet_peak` crest sharpness, `wavelet_spread` rad round the wind, `wavelet_life` s per sqrt m): a packet per jittered grid cell per size, each swelling and dying and returning with a new heading, crests running through it. An analytic sum of 20-32 plane waves was tried first and beat into a visible diamond lattice from cruise height; the packets don't.
- Wind: broad drifting patches of rougher/calmer sea on top of the paws (`wind_patches`: size m, contrast).
- Distance: glitter keeps its crisp spot size; what the layers lose to the footprint widens it into a dimmer sheen lobe (`glitter_filter`), so the mid distance no longer frosts. Foam pattern octaves even out by footprint.
- Near water: `body_shade` (1.0 live) lightens the water body on slopes toward the sun so the chop shape reads where fresnel is low; live also sets `fresnel_floor` 0.08, `fresnel_power` 3.5.

Knobs, e.g. `--sea-set="swell_groups:0.9;swell_cross:Vector2(1.05,0.6);swell_peak:0.8;flow_cycle:2.6;wavelet_size:Vector2(2.5,0.25);wavelet_strength:0.25;wavelet_peak:1.0;wavelet_spread:1.25;wavelet_life:1.6;wind_patches:Vector2(380,0.35);glitter_filter:1.0;body_shade:1.0"`.

Cost: whole-frame median, 3024x1898 window, sun view, 600 frames: 9.8-10.0 ms new vs 9.0 ms `--sea-motion=old` (3 runs each), so about +0.9 ms. GPU timer reads 0 on Metal; GPU share unverified.

Captures: `captures/water3/cmp_{sun,coast,close,away}.png` (top old motion, bottom new), `captures/water3/{new,old}_{sun,coast,close,away}_motion.gif` (5 frames 0.13 s apart, camera and plane held, sea clock running). Raw frames and 2x2 crop sheets (`motion_*.png`) are on disk only. Drivers: `scratch/water3_cap.gd` (holds camera, steps `look.step`), `scratch/water3.sh`, `scratch/strip.py`/`quad.py`/`sheet.py` (PIL; on the Mac use `/usr/bin/python3`, the brew python lacks PIL).

Left: wavelet crests at grazing angles read as thin dashes, a touch stylised; the screen-space mirror shows a sharp inverted island at range; swell bands toward the horizon are softer but still there in calm patches; the wake and its V untouched.

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

## Body round (height, light across the wave, whitecaps)

`sea_body` 1 (the default; `--sea-body=old` gives the motion round, and `--sea-motion=old`, `--sea-surface=old`, `--water=old` still give the earlier ones). In `shaders/endless_sea.gdshader` `zs_swell_body`:

- Height: eleven Gerstner waves, a long swell in two crossing trains (118-52 m, heights scaled by `body_swell.x` m) and a wind sea along the steady wind (28-5.5 m, steepness `body_swell.y`), each rising and dying in its own groups. The squeeze is shared out so crests peak toward `body_swell.z` without folding; normals come from the full Jacobian. Crests reach about +1 m and troughs -1.3 m near the eye. The heave reaches `body_reach` (420 m, gone by 800 m) on a finer sheet (`EndlessSea.sheet()`: 1 m cells to 48 m, doubling ring by ring; about 65k vertices against 45k), so near swells hide the water behind them and the low horizon undulates.
- The plane: `EndlessSea.height_at(x,z)` mirrors the swell on the CPU (a sine-free hash, so its noise reads the same as the GPU's). `studies/endless_flight.gd` sets `plane.water` from it each tick, the camera's `_solid` keeps above it, and the wake's strength measures height over it.
- Light: troughs at `body_value.x` of the body's light, crests at `.y`, a touch greener up the crests; thin crests glow `sss_color` when the eye looks toward the sun (`sss_strength`). Deep tints are a little darker (tint_mid/deep/abyss set in endless_sea.gd).
- Whitecaps (`whitecaps`: amount, life s, streak): born on the wind sea's crests where the wave's group and the rough stretch are high, and clustered by a drifting gust field. They are left behind as the crest passes, fade over `life`, streak downwind and have ragged edges. Jacobian cusps add a few more. Past the pixel footprint they soften to a wash. Lighter, greener aerated water rings them. They show only in open water (over 4-12 m deep).
- Slicks and rough: one field (`zs_body_rough`, size `wind_patches.x`) drives the wind sea's height (`body_patch.x` in a slick, `.y` in the rough), the chop (`body_patch.z` contrast), the whitecaps and a slight darkening of the rough.
- Crinkles down: `detail_strength` (0.2,0.12,0.045), `wavelet_strength` 0.1, `wavelet_size` (3.2,0.7).

Knobs, e.g. `--sea-set="body_swell:Vector3(0.85,1.0,0.9);body_reach:Vector2(420,800);body_patch:Vector3(0.3,1.3,1.0);body_value:Vector2(0.6,1.2);sss_color:Color(0.1,0.8,0.62);sss_strength:0.8;whitecaps:Vector3(1.0,2.2,1.0);wind_patches:Vector2(320,0.35)"`. `debug_view:5` shows glow, height and squeeze. The CPU mirror reads the material's values, so swell knobs set through `--sea-set` move the plane's skim too.

Cost: whole-frame median, 3024x1898 window, sun view at 8 m, 600 frames, 2 runs each: 11.47 ms new against 9.90 ms `--sea-body=old`, so about +1.6 ms. The GPU timer reads 0 on Metal, so I couldn't split the GPU share out. Most of it is likely the denser sheet with the 11-wave vertex shader, plus the whitecap loop per pixel.

Proof: smoke passes with the defaults and with each of `--sea-body=old`, `--sea-motion=old`, `--sea-surface=old`, `--water=old` and `--no-wake`. In a throwaway drive through the real loop (`scratch/skim_drive.gd`), the plane was held nose-down onto the water for 900 frames. It stayed 0.82 m or more over the drawn swell (-1.34..+1.0 m) and never went under it; the rendered side shots in `captures/water4/skim_sheet.png` show it riding the surface.

Captures: `captures/water4/cmp_{sun,away,low,close,coast,high}.png` (top `--sea-body=old`, bottom new) and `{new,old}_*_motion.gif`. The drivers are `scratch/water4.sh` (adds `low`, 2 m toward the sun, and `high`, 170 m over open sea, to last round's views) and `scratch/water3_cap.gd`.

Left:
- Toward the sun the glow on the crests is broad green bands rather than thin rims.
- From high up, the crossing wind sea can read as a faint lattice in rough stretches.
- There are fewer whitecaps in the toward-sun view than from cruise. The count is a balance between the coast view, where rough stretches can still look busy, and open sea.
- The far sheet past 800 m is flat, with normals only.
- The wake's foam doesn't ride over a crest's shove: it sits at the rest xz, so it is fine at skim range.

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

## Foam round (whitecaps that linger and age into lace)

`sea_foam` 1 (the default; `--sea-foam=old` gives the body round's short-lived caps, and the older flags still work).

- Buffer: `scripts/endless/sea_foam.gd` keeps a 512 m square of foam (1024² RGBA16F, 0.5 m texels, centred 143 m ahead of the eye along the view), addressed by world position wrapped on its side, so moving it is free and what slides in starts clean. A compute pass, `shaders/endless_sea_foam.glsl`, runs as the camera's compositor effect before the opaque pass, ping-ponging two textures. Each frame it carries last frame's foam upstream to downstream (drift downwind plus the curl of a drifting noise, which pulls patches into streaks), spreads it, fades it, and lays new foam where the wind sea's crests are breaking. It finds those crests the same way the sea shader does, so a trail starts where the drawn cap stands. Channels: density, youth, churned water, the plane's wake (laid when it skims).
- Look: the crest's own cap is analytic, dense and bright for `foam_fresh` s. The foam it leaves opens from a solid patch into marbled veins (crossing ridges of a bent noise, stretched downwind) with a thin milky film between them, then thins and goes, over `whitecaps.y` (6 s). Fresh foam is a little brighter and lit by its slope, there is a faint lighter churned halo, and far off the lace evens out into its mean cover. Past the buffer the same trail is worked out per crest (the last two crests of each wave), cross-faded over the last 40 m of the square.
- More caps: `whitecaps.x` 1.6, caps start lower (`foam_caps.x` 0.42), more stand outside the gusts, and slicks keep a few in their wave groups' peaks (`foam_caps.z`). The rough stretches are capped as before, so they don't turn into a blanket. The crest glow is down a little (`sss_strength` 0.65); the palette is unchanged.

Knobs (`--sea-set`, quoted): `"whitecaps:Vector3(1.6,6.0,1.0);foam_caps:Vector3(0.42,0.4,0.5);foam_fresh:0.5;foam_flow:Vector4(0.45,0.35,14.0,0.9);foam_spread:Vector2(0.03,0.3);foam_lace:Vector4(2.8,1.0,1.0,1.0)"`. `foam_flow`: drift m/s, swirl m/s, swirl size m, youth s (solid to lace). `foam_spread`: foam and churned-water diffusion, m²/s. `foam_lace`: vein size m, vein thickness and film, how far the veins bend, halo strength. `debug_view:6` shows density, youth and the buffer's reach; `debug_view:7` turns the buffer off (per-crest foam everywhere). The compute pass reads the material's values each frame, so the knobs reach the buffer too.

Cost (3024x1898 window, 600 frames, three runs each): about +0.3 ms whole-frame median at the low sun view (12.10 ms against 11.81 ms), about +0.5 ms at cruise (`--alt=70`, 10.93 against 10.40). The GPU timer reads 0 on Metal, so the compute pass's share is unverified.

Two Metal problems, both fixed and worth knowing:
- Sampling (`texture()`) in the compute pass the texture it had written the frame before hung the GPU a few seconds in, whether it was dispatched from `call_on_render_thread` or from a compositor effect. Reading it with `imageLoad` and filtering by hand fixed it.
- The first version put the whitecap code, with an inner loop over crests, inside the 11-wave loop. The first run after each shader edit then sat in the Metal shader compiler for over 8 minutes at 100% CPU. Moving the caps into their own loop over waves 5..8, with a helper per crest, brought it back to a normal start. Watch for this when growing `zs_swell_body`. Apart from that, I saw a rare capture hang that happens with `--sea-foam=old` too.

Proof: smoke passes with the defaults and with each of `--sea-foam=old`, `--sea-body=old`, `--sea-motion=old`, `--sea-surface=old`, `--water=old` and `--no-wake`. A rendered 900-frame run through the real flight loop with `--sea-set` foam knobs gave no errors.

Captures (`captures/water5/`): `cmp_{sun,away,low,close,coast,high,cap}.png` (top `--sea-foam=old`, bottom new); `life_cap_life.png` and `life_cap_motion.gif` (a cap's life, 16 frames 0.4 s apart, 9 m over a rough stretch: break, then veins and film, then gone) against `oldlife_cap_life.png`; `cmp_play_loop.png` (real loop, old on top). The driver is `scratch/water5.sh` (adds the `cap` view; `N=` frames, `E=` frames apart), with `scratch/crop8.py` (a grid of crops) and `scratch/cmp.py`.

Left:
- Fresh caps are still flat cream shapes with fairly clean edges. They could use a frothier rim, or a lift off the surface.
- The far sea past about 400 m shows caps only as a faint wash; from the high view the distance reads calmer than the near sea.
- The veins follow only the uniform drift, not the buffer's swirl, so in a long look the lace slides a little against its envelope.
- The wake laid in the buffer is one blob round the plane each frame; it isn't shaped into the V's arms.
- Shore foam is untouched and doesn't use the new lace.

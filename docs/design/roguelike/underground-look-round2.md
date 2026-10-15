# Underground look, round 2

Round 1 (underground-look-round1.md) built the look in the motif yard. Round 2 puts it on the generator and removes everything made up.

## What changed

- `--underground=torch|haze` now works in `studies/run_layer.tscn` (run_layer is a kit isle, so `Underground.attach` already ran; the work was hiding the open sky's life and fitting the real layer).
- Under the flag the abyss sky, fog/haze, dim light, wanderer torch and glowing Olmec eyes (heads, and the whole Olmec body that spawns) are on. Hidden every frame: the sky's clouds, gulls/life, motes, airships/traffic/ferry/drone/serpent route, plane tokens, sun disc (the day objects). The layer's own isles (`sky.motifs`) stay as the depth.
- Removed: the stepped-pyramid pillars, the far bridge, the far eye pairs (from the yard too).
- Far rock shaft wall: DROPPED (and `shaders/abyss_rock.gdshader`). At 1-2 km in haze it still read as noisy cloud. Haze and darkness do the work.
- The next region's far silhouette (a real part of the layer, `next_region_lod`) glowed pale blue in the dark: its shader goes into the day's sky globals and ignores fog. Under the flag it gets a copy shader (`shaders/underground_next.gdshader`) that fades into the preset's horizon colour, with dark stone colours. Knobs `next_reach`, `next_most` (re-applied every 20 frames, so it holds across regions and restarts).
- Fog: torch 0.0016 (was 0.0032), a little lighter murk/ambient, so other isles stay readable as silhouettes. Haze 0.0016 unchanged.
- `run-underground.command` launches the generator: sprawl, seed 7, torch; extra flags win. L still flips the presets (the yard's `step_look` hook works in the layer too).
- Checked headless with a driver (scratch, uncommitted): new layer via `request_layer(11)` keeps the torch, the fog, the tinted next region and hidden clouds.

## Play

    ./run-underground.command
    ./run-underground.command --underground=haze --shape=ring --seed=3
    <godot> --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=7 --underground=haze

## Stills (docs/design/roguelike/underground-round2/)

`wide_haze.png`, `wide_torch.png` (isles across the layer fading, the next region's silhouettes), `start_*.png` (from the start; poorly framed, against the base wall), `head_haze.png`, `head_torch.png` (a whole Olmec with glowing eyes at seed 7's east isle).

## Tune next

- Torch preset is very dark for far isles; raise `sky_horizon`/ambient or lower fog further. The haze reads better.
- Terrain turf stays saturated orange under the dim light (round 1 note).
- A small cloud puff remains at the far left of the wide stills (not found; some layer-owned cloud). 
- The hidden sky parts are only hidden, not stopped; fine for a look, wasteful if kept.
- Ring shape, the dragon (`--dragon-live`) and a real key press for L were smoke-checked only, not looked at.

## Existing tests broken

None expected; the flag-off path is unchanged. Full suite not run.

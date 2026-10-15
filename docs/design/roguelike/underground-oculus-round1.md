# Underground look: the oculus (round 1)

A look round, not a lock-in. The underground city read drab next to the old sky world. This round adds a third preset, `oculus`, beside `torch` and `haze` (both untouched): a vast opening in the cavern roof with the real sky in it, a warm raking key light and shafts from it, a cool jade fill, and a mist sea in the abyss. It also makes the opening the destination: it sits over the exit gate and grows as the run climbs.

## Play it

    ./run-underground.command --underground=oculus
    ./run-underground.command --underground=oculus --region=2     # region 2: nearer, larger, brighter
    <godot> --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=7 --world=under --underground=oculus

L flips torch, haze, oculus live. `--under-look=oculus` makes every underground region of a plain run wear it. It is not the default; the user judges that.

## What it is

- **The opening** (`shaders/oculus_sky.gdshader`, a sky shader traced from the camera): a roof plane at a real world height with a round, lobed hole of a real radius above the gate. Through it, an opal sky with clouds seen from below, edges lit warm. The rim is a dark rock edge with a thin warm lip; the roof round it catches spill and fades to dark slabs and faults. Because it is a real place, it has parallax, is foreshortened when off to one side, and grows as the wanderer walks toward the gate.
- **Going up.** The opening is above the gate (pulled 30% toward the start so the light rakes in at about 40 degrees, not straight down). Region by region (1 to 2) it comes 40% lower, 40% wider and 30% brighter; inside a region it brightens with his nearness to the gate. Only underground regions use the preset, so there is nothing for sky regions.
- **The mist sea**: a cloud floor under the lowest isle (void_y minus 40 m), pale pearl crowns and jade hollows, going to a pale haze line at the horizon. The isles read dark against it; it is warmed under the shafts. It is in the sky shader, so it costs one fullscreen pass of noise.
- **Light.** The existing surface light becomes the warm key (low energy, shadows, raking along the shaft). A jade directional fill with no shadow comes from the other side. Ambient is jade. Two shadowed spot lights make the pools: one on the start, one at the gate. Between them the city stays dark. The torch is as before.
- **Shafts** (`shaders/oculus_shaft.gdshader`): three soft additive cones from the opening (start, middle over the void, gate), streaked and drifting, fading at the sides, ends, near the camera (no wall when inside one) and where they meet stone.
- **Dust** (`shaders/oculus_dust.gdshader`): 220 motes round the wanderer, only lit inside a shaft.
- **Fog**: the existing depth fog (jade), volumetric fog (the key scatters in it) and a height fog band (`height_fog`) that thickens toward the abyss.

Everything is in `scripts/underground/underground.gd` (`PRESETS.oculus`, the `_oculus_*` section); parts are built when the preset is on and freed when it is off.

## Knobs

`--underground-<name>=<value>`, oculus defaults: `moon` 0.7 (key), `fill` 0.45, `pool` 9 (spot energy), `shaft` 0.12, `glory` 0.6 (the opening's brightness), `sea` 0.55 (mist light), `oculus_h` 380 (m over the gate), `oculus_r` 190 (m), `height_fog` 0.012, plus the usual `fog`, `volume`, `ambient`, `exposure`. Constants at the top of the oculus section: `OCULUS_PULL`, `OCULUS_LOWER`, `OCULUS_WIDER`, `SEA_BELOW`, `SHAFT_*`, `POOL_BACK`.

## Frame cost

`tools/bench_run_layer.gd`, rendered, Apple M5 Pro, 1440x900 window (3D at the 720 cap), `--walk`, sprawl seed 1, 120 frames, wall median ms (other agents' windows may have been open, so read it as rough):

| view | torch | oculus | delta |
|---|---|---|---|
| spawn | 28.0 | 30.8 | +2.8 |
| mid | 19.6 | 20.4 | +0.8 |

Draw calls 1273 to 1421 at the spawn (shaft cones, dust, two spot lights); the two spots with shadows cost about 2.5 ms at the spawn. The volumetric fog is the largest single cost in both presets (about 7.5 to 9 ms, from the project's 256 volume), and the oculus keeps it as the torch preset does. The sky is one fullscreen shader pass (roof, clouds, sea): under the bench's resolution cap its cost is small. If it needs paring: drop the start pool's shadow, `--underground-volume=0.004`, or shrink the dust amount.

## Stills

Not committed (the repo ignores doc images); kept at `docs/design/roguelike/underground-oculus-round1/`: `up_region1.png`, `up_region2.png` (looking up from the start, one and two regions in), `gate_up.png` (from the gate), `sea_out.png` (across the mist sea), `wide.png` (isles and shaft against the mist), `play.png` (the high play camera at the start).

## Checks

Headless import and `tools/smoke.py studies/run_layer.tscn` on sprawl seed 7 with the preset: pass, 0 errors. A scratch driver cycled L through all three presets live (parts built and freed, no errors). No tests written or run. Existing tests I expect to break: none (the preset is additive; torch and haze paths are unchanged). Not checked: the ring shape, a run going through the gate to region 2 live (region 2 was looked at with `--region=2`), the Olmec's light-sight (`scripts/enemies/light_level.gd`) under the key and pools.

## Open questions

- The Olmec's sight reads the light level; the key and the two pools change who is seen where. Worth a look before it becomes the default.
- The game's own gate beam goes straight up and the opening is offset 30%; they read as a pillar and a slanted shaft. Fine or align?
- The start's floor stone is warm tan under the pool, not weathered basalt; the key shows its pits only from a low angle.
- The three shaft footprints are fixed (start, middle, gate); a pool over the route's isles would need the plan's route points.
- The vault is painted (no geometry): it has no occlusion, so the key light casts no shadows from the roof, only from isles.

# Endless flight: valley fog (first pass)

A low fog layer now lies along the valleys, between the ridges, inside the
clouds' own march. It is patchy along a valley, thicker in pockets and
wide floors, has a soft billowed top the ridges rise out of, thins near
the ground, drifts slowly on the wind, and is lit by the mood's sun and sky
in the cumulus palette. The land shape, collision, the clouds' look and the
distance haze are unchanged. With `--no-valley-fog` every pixel is as
before.

## Launch

- `./run-endless-flight.command [flags]`, or
  `godot --path . res://studies/endless_flight.tscn -- --no-title [flags]`
- Down a valley: `--seed=1 --at=400,-1065 --heading=22 --alt=35`
- In the fog, on the floor: `--seed=1 --at=430,-1000 --heading=22 --alt=12`
- A range: `--seed=1 --at=-700,-300 --heading=66 --alt=90` (sunrise: add `--hour=6.6`)
- High up: `--seed=1 --at=200,900 --heading=95 --alt=150`

## Flags and knobs

| Flag | What it does |
|---|---|
| `--no-valley-fog` | No fog. `--valley-fog=0` does the same. |
| `--valley-fog=X` | Density, default 1. 2 is twice as dense. |
| `--valley-fog-depth=M` | How deep the fog lies over a floor at most, default 40 m, before the patches thin it. |
| `--valley-fog-steps=N` | Steps in the fog's march, default 32. |

The fog runs with the clouds, so `--no-clouds`, the C key, `--plain-look`
and headless runs turn it off too.

Knobs:
- `scripts/endless/endless_clouds.gd`:
  - The map: `FOG_TEXELS` (384), `FOG_SIDE` (12 km), `FOG_MOVE` (1.4 km).
  - The reach: `FOG_REACH` (4.4 km), faded over `FOG_FADE`.
  - `FOG_DEPTH`, `FOG_STEPS`, `FOG_DRIFT` (the share of the clouds' wind it drifts at, 0.3).
  - In `fog_image`: how far up a valley's sides the fog reaches, and the weights for ranges against hills and for wide floors.
- `shaders/endless_cloud_march.glsl`, the "valley fog" block:
  - The patches: `FOG_PATCH`, `FOG_PATCH2`, `FOG_PATCH3`, `FOG_GATE`, `FOG_MORPH`.
  - The top: `FOG_BILLOW*`, `FOG_TOP_SOFT`.
  - The thin layer near the ground: `FOG_GROUND`, `FOG_UNDER`.
  - The light: `FOG_SIGMA`, `FOG_SUN_SIGMA`, `FOG_SKY`, `FOG_BOUNCE`, `FOG_PHASE`, `FOG_SHADE_AT`.
- `shaders/endless_cloud_composite.gdshader`: `FOG_COOL` and `FOG_LIFT` (fog in shade cooled toward blue and brightened).

## How it works

- **The fog map** (`endless_clouds.gd` `fog_image`) is baked off the land
  shape on a worker, the way the ground map is. It is 384 texels over 12 km
  (31 m texels), remade when the eye moves 1.4 km, and takes about 230 ms
  per bake. Each texel holds four values:
  - the ground's y;
  - the nearest valley's floor y;
  - how much fog the valley holds there, 0 to 1: 1 along its middle,
    fading up its sides, more through the ranges than the hills
    (`lerp(0.3, 1)`), and more where the floor widens into a pocket;
  - how much of a range stands round it (this deepens the fog).

  It is bound to the march's unused binding 2 (the isles' swells slot).
  The parameter block's spare slots 56 to 67 carry its square, the knobs
  and the drift.
- **`land_field.gd`** adds one read-only field, `last_floor`, the nearest
  valley's floor y, set in `sample`. Heights are unchanged.
- **The march** (`endless_cloud_march.glsl`):
  - Before the clouds, a short march runs over the slab the fog can fill:
    from the sea up to the highest floor in the map plus 1.6 times the
    depth. It stops at the ground (the depth buffer) and at the reach.
    Steps are spaced finer near the eye and coarser far off.
  - Density: the map's amount times the patches, under a top that sits
    the depth over the floor. The patches are three scales of the noise's
    wisps, drifting and slowly morphing, contrast-stretched so about a
    third of a valley is open. Their thickness also lifts and lowers the
    top. The top is billowed and soft, there are wisps inside, and the
    fog thins to 12% over the first 2 to 18 m above the ground.
  - Light:
    - the cloud's octave scattering with a flatter phase;
    - self-shade from its own depth;
    - the ridges' shade (4 taps of the map's ground along the light), with
      30% of the light kept in shade;
    - the sky from above, and a little bounce.
  - It writes the same light terms as the clouds, plus its own share in
    the fourth term, which is 0 for cloud.
  - It is merged with the cloud: whichever is nearer goes over the other.
- **The composite** cools and lifts the shade term by that share only. A
  pixel with no fog is as before.

## Stills

All are in `captures/valleyfog/` in this worktree (git-ignored). Before
(`--no-valley-fog`) is on the left, after on the right:

- `final_valley_sheet.png`: down a valley
- `final_range_sheet.png`: a range
- `final_high_sheet.png`: ranges from high up
- `final_inside_sheet.png`: on the floor, inside the fog
- `final_sunrise_sheet.png`: low sun at 06:36
- `final_above_sheet.png`: a free camera over the valley
- `knob2_sheet.png`: the range at `--valley-fog=1` and `=2`
- `steps16_sheet.png`: 32 steps and 16 steps
- `land_sheet.png`: the hand landing at 30, 15 and 6 m, and stopped

The scripts are in `scratch/` (git-ignored): `vf_shoot.sh`, `vf_final.sh`,
`vf_map.gd` (the map's numbers and a picture), `vf_land.gd` and
`vf_perf.gd` / `vf_perf.sh`.

## The hand landing (play loop)

`python tools/drive.py scratch/vf_land.gd --rendered -- --shots=captures/valleyfog/land --scene-args --seed=1 --at=400,-1065 --heading=22 --alt=40`

The driver uses real input: F for the flaps, then the stick on a sink
controller, then the brake.
- Ahead along the heading, 610 m of the floor is flat.
- The fog map's amount was 1.0 all along the path and at the touchdown.
- The plane touched down at 5.5 m/s with a sink of 0.5, graded a greaser,
  with 0 bounces, and stopped.
- In the stills the floor stays visible all the way down.

## Cost

Measured on the M5 Pro at 1440x900, uncapped. Fog on, fog off and clouds
off took turns every 24 frames in one run, with the plane held still, 270
frames each. These are medians:

| spot | clouds off | fog off | fog on (32) | fog on (16 steps) |
|---|---|---|---|---|
| down the valley | 18.3 ms | 20.4 | 22.7 (+2.3) | 21.2 (+0.8) |
| in the fog on the floor | 20.7 | 23.0 | 24.5 (+1.5) | 23.8 (+0.8) |
| high, ranges | 12.5 | 15.8 | 16.4 (+0.6) | 16.0 (+0.2) |

The machine was busy (load 5 to 20 from other runs), so the absolute times
are higher than the earlier rounds' and the numbers are noisy; the
differences between the fog settings are what matter. The fog costs
0.6 to 2.3 ms, most when looking down a fogged valley.

What would cut the cost:
- `--valley-fog-steps=16` halves it, and the valley still looks about the
  same (`steps16_sheet.png`; not judged in motion).
- March the fog at half resolution, as `--cloud-half-res` does.
- Skip the empty stretch of the slab where the map has no fog, using a
  coarse distance field.
- Stop early once the fog is opaque (it already stops at 98%).

## Not verified

- Motion: drift, morph, grain or shimmer while flying, and ghosting in the
  resolve on fast turns. The fog is fully marched every frame and shares
  the clouds' temporal resolve.
- Other seeds and moods. Seed 1 only, alpine morning, and one sunrise.
  `--hour=18.2` was already night: the fog reads as bright, moonlit white,
  maybe too bright, judged from one still.
- Whether the gaps are always close enough to land: the patches are on the
  GPU only, with no CPU mirror yet. One landing was flown, through a
  fogged stretch.
- Retina or full screen, Windows, and other GPUs.
- How far fog reads in the distance: it fades out at 3.3 to 4.4 km.

## Known looks to take on next

- Fog in a ridge's shade over a dark slope still reads as a flat pale
  sheet up close (the right side of `final_valley_sheet.png`).
- From high up the fog is subtle. `--valley-fog=1.5` to `2` reads better
  there, but is thicker on the floor.
- The fog has no "in fog" HUD state and no CPU `fog_at`.

## Existing tests this breaks

None known. No test covers the endless clouds' shaders or scripts. The
`land_field.gd` change is a new field that does not change any height. The
full suite was not run.

Smoke (headless): `endless_flight.tscn` as is, with `--no-valley-fog`, and
with `--valley-fog=2 --valley-fog-depth=60` all PASS with 0 errors.
Headless runs no clouds, so the fog's code is proved by the rendered runs
above, which had 0 script errors (only the usual exit-time "shaders never
freed" line).

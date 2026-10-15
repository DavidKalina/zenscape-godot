# The city run, perf round 1 (2026-10-15)

> On `perf/city-run`, from `roguelike` at b9f49fb2 (with PR #29's noise
> bus and the Olmec's hearing). Not merged.

The user played `run-game.command` (the underground city, torch look) and
found it "atrocious". This round measured where the frame goes, fixed what
could be fixed without changing the picture, and put one visible trade behind
an off-by-default knob.

## How it was measured

`tools/bench_run_layer.gd`, rendered, Forward+ on Metal, Apple M5 Pro, a
1440x900 window on the Retina screen, the user's own kept settings
(`user://look.cfg`: render cap 720 lines, MetalFX spatial upscale, so 3D at
1146x719; MSAA 4x from project.godot), vsync off and uncapped (the game itself
caps macOS at 60):

```sh
Godot --path . --rendering-method forward_plus --windowed --resolution 1440x900 \
  -s res://tools/bench_run_layer.gd -- --no-title --shape=sprawl --world=under \
  --under-look=torch --seed=1 --window=1440x900 --no-next --walk --procs [--parts=...] [--stills --out=DIR]
```

New in the bench this round: underground parts to take away (`lights`,
`light_shadows`, `torch_shadow`, `flames`, `particles`, `bodies_drawn`,
`bodies_step`, `hearing`, `vol_fog`, `env_fog`, `cover_skins`, `flora_other`,
`sun_lights`, `physics`), `olmec` and `fires` views, `--walk` (he paces, so
his footfalls go through the noise bus to the bodies' ears), a lights/env
census line, p95 and physics columns, and the worst single call per script in
`--procs`. Metal reports no GPU time (`gpu_ms` is 0), so GPU cost is read
from `draw` (pre-draw to post-draw on the main thread: submit plus the wait
for the GPU) and from what taking a part away saves.

Columns: wall (median frame, ms), p95, before (physics plus the study's
tick: pilot, enemies), process (node `_process`), draw.

## Baseline (roguelike b9f49fb2, seed 1)

| view | wall | p95 | before | process | draw | draw calls | primitives |
|---|---|---|---|---|---|---|---|
| spawn (the landing, looking over the city) | 59.7 | 63.6 | 6.3 | 5.0 | 48.6 | 1285 | 2.16 M |
| gulf | 18.9 | 22.6 | 7.6 | 2.4 | 9.2 | 424 | 0.53 M |
| mid | 15.5 | 20.5 | 5.0 | 2.3 | 8.5 | 1034 | 1.08 M |
| next | 10.0 | 20.5 | 5.9 | 2.1 | 2.7 | 63 | 0.08 M |
| olmec (near a body, grass round it) | 59.9 | 60.2 | 10.4 | 5.1 | 44.4 | 373 | 2.48 M |
| fires | 13.8 | 20.1 | 5.2 | 2.3 | 6.6 | 191 | 0.20 M |

GPU-bound where grass is in view (17 fps at the landing), CPU-bound
elsewhere (~10 ms), with a 19-21 ms hitch every 20th frame everywhere.
The layer: 22.5 M triangles in the scene (14 M of them instanced grass),
3342 drawn nodes, 80 lights (57 visible, 5 with shadows), 120 particle
systems, 469 physics bodies.

## What costs what (baseline, ms saved by taking each away, wall)

| part | spawn | olmec | gulf | mid | fires |
|---|---|---|---|---|---|
| **grass (kit flora tufts)** | **37.3** | **31.1** | 5.6 | 0.1 | 0.1 |
| all multimesh flora | 41.1 | 37.0 | 5.7 | 2.1 | -0.4 |
| MSAA 4x | 30.3 | 7.8 | 0.4 | 2.3 | 0.8 |
| other flora (flowers, ferns, mushrooms) | 0.0 | 12.4 | -0.3 | -0.2 | 0.2 |
| volumetric fog | 3.5 | 6.2 | 5.9 | 3.8 | 6.6 |
| all omni lights (draw) | 10.1 | ~0 | ~0 | 0.6 | 1.7 |
| moon (directional) shadows | 5.4 | 3.1 | 1.1 | 0.7 | 1.9 |
| fire lights' shadows (5) | ~0 | ~0 | ~0 | ~0 | ~0 |
| flame volumes | ~0 | ~0 | ~0 | ~0 | 0.4 |
| fire particles (sparks, smoke) | ~0 | ~0 | ~0 | ~0 | 0.3 |
| Olmec bodies + heads drawn | ~0 | ~0 | ~0 | 0.2 | 0.2 |
| Olmec stepping (CPU, "before") | 3.0 | 7.4 | 5.8 | 3.5 | 3.7 |
| their hearing (noise bus) | ~0 | ~0 | ~0 | ~0 | ~0 |
| kit stone ("Mesh") | ~0 | 2.9 | 0.4 | 1.2 | 2.8 |
| physics server | ~0 | ~0 | ~0 | ~0 | ~0 |
| SSAO / glow / env fog | <1 | <1 | <1 | <1 | <1 |

(Negative and small numbers are noise; a part that saves draw while the
frame is CPU-bound shows as ~0 wall.)

Why the grass: with the same geometry on a plain lit shader it cost 2-4 ms,
unshaded 1-3 ms. The cost was the shader: `shaders/reference_surface.gdshader`
is one uber-shader for grass, flowers, ground, rock, trees and more, picking
its paths by `uniform bool`s and carrying discards (sea cut, leaf fall, tree
tread, char) that grass never takes but the GPU must allow for. On Apple
GPUs a shader that may discard loses hidden-surface removal, and grass
overdraws a lot. MSAA multiplied it (a thin blade is shaded wherever it
covers any sample). The rest of the grass cost is its fade: a tile in its
80-95 m fade band draws alpha-blended, in the transparent pass.

The hitch: `underground.gd` walked the whole layer with
`find_children("NextRegion")` every 20th frame (11-12 ms).

Not the problem: the fire (flames, sparks, smoke, their lights and the 3
shadowed braziers) is under 1 ms anywhere; the Olmec's meshes ~0; the noise
bus and hearing ~0; physics ~1 ms; SSAO/glow/env fog under 1 ms.

## What this round changed (all image-neutral)

1. **Shader switches folded** (`scripts/shader_fold.gd`, new). A material's
   `uniform bool`s become `const bool`s at its own values, in a shader shared
   by every material with the same switches, so the compiler drops the paths
   not taken; the discards it can never take go too (the sea cut with
   `sea_cut` unset, the tree tread off, the char with fire off and
   `object_fire` unset, the leaf fall where the caller says the season never
   drops leaves). Floats, colours and textures stay live uniforms, so the
   underground grade, the seasons and the wind work as before. Applied where
   the switches are set once: `SkyIslets._plant_material` (all sky and kit
   flora; leaf fall folded only for keys whose `SceneLook.leaf_season(key).y`
   is 0) and `KitLook.ground_material` / `rock_material`. 27 materials, 8
   shader variants. `--shader-fold=0` turns it off for A/B. Folding the bools
   alone took the landing from 60 to 40 ms; the discards from 40 to 28.
2. **The 20-frame hitch** (`underground.gd`, `next_region_lod.gd`): the
   NextRegion silhouette joins a group, found by `get_nodes_in_group`.
   p95 everywhere dropped from ~20 ms to its median.
3. **The aqueduct isle's hidden life** (`studies/kit_isle.gd`): its life
   (leaf litter, chaff, birds) is not advanced while it is hidden (the city's
   layers put that isle away): ~1 ms a frame of CPU.

Stills before/after at each view (scratch only) look the same to the eye; the
scene moves (wind, flicker, the Olmec), so they are not pixel-compared.

## After (same bench, `--walk`)

| view | wall before | wall after | p95 before | p95 after | draw after |
|---|---|---|---|---|---|
| spawn | 59.7 | **28.3** | 63.6 | 29.4 | 20.0 |
| gulf | 18.9 | **11.1** | 22.6 | 11.3 | 4.6 |
| mid | 15.5 | **10.9** | 20.5 | 11.4 | 4.4 |
| next | 10.0 | **9.4** | 20.5 | 9.8 | 3.3 |
| olmec | 59.9 | **16.8** | 60.2 | 17.1 | 8.4 |
| fires | 13.8 | **11.6** | 20.1 | 12.0 | 2.9 |

(Standing rather than walking, the olmec view is 10.3 ms: walking wakes the
bodies, see CPU below.) Every view but the landing now runs well over 60 fps
uncapped; the landing ~35 fps.

## Visible trade behind a knob (off by default)

`--flora-fade=pop` (`KitFlora.fade_mode`): the kit grass and flowers stop at
their range instead of fading out over the last 15 m. Landing 28.3 -> **13.3
ms**, olmec 16.8 -> 15.1, others unchanged. From the landing the fade band is
hidden anyway (the still is the same), but in motion a pop line can show at
80-95 m. A candidate for a lower preset, or for the next step below.

## What's left, ranked (after this round)

At the landing (28 ms): the grass fade band ~13-15 ms (mostly tiles hidden
behind the plaza), MSAA ~12 ms (overlapping with the grass), volumetric fog
~7 ms, omni lights ~6 ms, moon shadows ~4 ms. CPU everywhere: ~9-11 ms a
frame, of which the Olmec bodies and heads stepping 3-5 ms (more when they
hunt), the pilot and stage tick, life 0.9 ms, `_advance_look` 0.6-0.9 ms,
physics ~1 ms.

Hitches: building the layer is behind the loading screen (stream median
50 ms, worst frames 1.7-2.7 s at the start, 120-160 ms while isles stand and
their flora and life go up). Not studied further this round.

## Recommended next steps

1. **Grass fade by dither, not blend** (near image-neutral): fade the tufts
   in the folded grass shader by a screen-door/alpha-hash over the same
   80-95 m instead of `VISIBILITY_RANGE_FADE_SELF`, so fading tiles stay in
   the opaque pass. Should take most of the 13 ms `pop` shows. Check the band
   by eye in motion.
2. **Occluders for the city** (image-neutral): turn on occlusion culling and
   give the big kit stone (plazas, walls, platforms) `BoxOccluder3D`s when a
   piece stands. Most of the grass drawn at the landing is behind its plaza.
3. **Throttle far Olmec AI** (image-neutral at range, gameplay to check):
   step bodies and heads far out of sight and hearing every 2nd-4th frame.
   3-5 ms of CPU, the biggest CPU item.
4. **Fold more materials** (image-neutral): the same fold for the ruin
   growth shader, the underground cover skins and the stone, where their
   switches are set once.
5. **MSAA 4x -> 2x or off at 720 lines under MetalFX** (visible trade, a
   preset knob): saves up to 12 ms at the landing; 2x saved little.
6. **Volumetric fog at a smaller froxel grid** (visible trade): 48 or 32
   wide saved ~7 ms at the landing, same as turning it off there; judge the
   murk by eye before offering it.
7. **Lights fading by 40-50 m** (visible trade): ~6-8 ms at the landing.

## Not measured

GPU time per pass (Metal gives none); Windows; a full play-through
(only seed 1, fixed spots, with the pilot pacing); the next-layer streaming
(`--no-next`); the title screen.

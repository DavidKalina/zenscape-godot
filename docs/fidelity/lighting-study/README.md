# Controlled lighting study

The tested lighting changes do **not** convincingly resolve the reported overall
flatness. Reducing hemisphere fill makes existing shadows darker. A material-path
change enables subtle contact shading, and screen-space indirect lighting adds a
small local contribution. This is a useful compatibility finding, not an accepted
new art direction. Production defaults and saved worlds were not changed.

Open `index.html` for a wipe comparison, individual effect comparisons, native
tree/rock crops, and the paired camera film. Original images remain available at
1920 × 1200. The film is variant LEFT / control RIGHT, downsampled to 960 × 600 per
side for presentation. No generated imagery or color correction is used.

## Controls and variants

Godot 4.7.2, Metal Forward+, Apple M5 Pro. The reference fidelity scene supplies
the unchanged control: phase 0.48, paused world, no automatic orbit, Balanced
quality, 4× MSAA, existing filtered directional shadows, fog 0.02, haze 0.03,
shroud 0, clouds 0.06 and wind 0.4. This fixed reference scene is not the user's
unverified current saved garden. Camera distance is 43 or 18; target (0,3,0),
polar 1.13, yaw 1.8893. Light direction, exposure, geometry, palette and atmosphere
stay fixed across variants within each view.

| Variant | Hemisphere energy | Material path | SSAO | SSIL |
|---|---:|---|---|---|
| control | 100% | original emission | off | off |
| less-fill | 55% | original emission | off | off |
| contact | 55% | original emission | on | off |
| indirect | 55% | original emission | on | on |
| ambient-path | 100% | ambient irradiance | off | off |
| ambient-contact | 100% | ambient irradiance | on | off |
| ambient-indirect | 100% | ambient irradiance | on | on |

SSAO radius 0.65, intensity 0.7, direct-light affect 0.12. SSIL radius 3,
intensity 0.5. Glow stays disabled. The ambient-path experiment moves only the
hemisphere term of `reference_surface.gdshader` from EMISSION into IRRADIANCE;
albedo multiplication remains equivalent. Authored emission and afterglow stay
in EMISSION. Shader code is changed in memory inside the study process, restored
afterward, and never saved. This avoids adding an ambient term on top of the
existing simulated fill. Other shaders, including unshaded falling leaves and
water, retain their existing paths.

## What the renders establish

Both repeated control images are pixel-identical after restoring the original
shader and settings. All eight captures per view have the same camera transform,
phase and physical viewport size. `captures.json` records those invariants.

Mean absolute channel differences in the close image, on the 0–255 RGB scale:

| Comparison | Mean difference | Interpretation |
|---|---:|---|
| control → repeated control | 0 | no measured still-capture noise |
| control → less-fill | 2.606 | reduced fill visibly darkens shaded areas |
| less-fill → contact | 0 | SSAO has no effect on the original material path here |
| contact → indirect | 0.293 | SSIL reaches the original surfaces, subtly |
| control → ambient-path | 0.000000145 | baseline preserved to one channel level in one pixel |
| ambient-path → ambient-contact | 0.060 | SSAO now reaches the hemisphere contribution |
| ambient-contact → ambient-indirect | 0.216 | additional indirect-light contribution |
| control → ambient-indirect | 0.252 | small combined change, not a major depth improvement |

`pixel-differences.json` also records maximum differences and channel fractions
over 8 levels. These numbers establish an effect, not visual preference. The
tree crop changes by 0.59 levels on average and the rock crop by 0.40. Inspect
the native crops rather than relying on a reduced whole-scene thumbnail.

The three-second film follows a prescribed 90-frame camera path with the world
paused. The second reel replays the first reel's camera transforms exactly;
`film-poses.json` retains both. It is an offline visual check, not a real-time
benchmark. It does not establish performance, display pacing, input latency,
or stability during arbitrary camera movement. No production adoption is
recommended, and no new real-time performance claim is made.

## Why this method, and its limits

The original shader implements hemisphere diffuse light as albedo-scaled
emission. Godot's ambient source is disabled, and the runtime Balanced selector
also disables SSAO. Merely selecting SSAO therefore cannot occlude that emitted
hemisphere term. The experiment preserves its color/energy while routing it
through Godot's ambient path. The engine applies SSAO and SSIL there, as shown
in the [Forward+ shader implementation](https://github.com/godotengine/godot/blob/4.7/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl).

[IRRADIANCE](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)
provides the material hook. [SSIL](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html)
was chosen for this bounded experiment because it needs no geometry bake and can
use visible edited terrain and foliage. It is screen-space local indirect light,
not a replacement for world-space GI; offscreen and occluded surfaces are absent.
The still evidence does not rule out a better result from world-space lighting.

VoxelGI and SDFGI were not enabled or benchmarked. VoxelGI adds a geometry-bake
lifecycle; SDFGI does not include dynamic geometry in GI generation. Editable
terrain, shader-displaced vegetation, and the remaining emission-based materials
need a separate compatibility study before either is adopted. See the
[SDFGI geometry constraints](https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/using_sdfgi.html).

## Reproduce

From the Godot repository, `./run-lighting-study.command` regenerates the stills
and metadata. `./run-lighting-study.command --study-film` writes the two reels
to `/tmp/zenscape-lighting-control` and `/tmp/zenscape-lighting-ambient-indirect`.

```sh
ffmpeg -y -framerate 30 -i /tmp/zenscape-lighting-ambient-indirect/%04d.jpg \
  -framerate 30 -i /tmp/zenscape-lighting-control/%04d.jpg \
  -filter_complex '[0:v]scale=960:600[l];[1:v]scale=960:600[r];[l][r]hstack=inputs=2[v]' \
  -map '[v]' -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart \
  docs/fidelity/lighting-study/comparison.mp4
```

The capture explicitly draws frames because an occluded native window may not
emit `frame_post_draw`. It uses the Window resource API after native transitions
settle and asserts 1920 × 1200 at every capture. Preliminary runs with mismatched
window sizes were rejected and overwritten. Final engine runs compiled the
temporary shader successfully; some runs reported six ObjectDB instances leaked
on exit. Their cause was not investigated in this visual prototype.

The study is throwaway. Retain the findings; delete or rewrite its runtime shader
patching when a visual direction is chosen. User verdict remains pending.

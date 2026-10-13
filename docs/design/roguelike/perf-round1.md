# The generator's layer, perf round 1 (2026-10-13)

> On `perf/run-layer` (from `roguelike` d737180c). Builds on perf/frame-budget
> (baked sea swells), perf/lower-world, and RenderCap (0252c64f).

The user is on an M5 Pro (Elden Ring runs at about 45 fps at 1080p) and said
"our game is struggling a little bit." They asked for fluid play, streaming
work, fewer triangles without losing quality, and a 540p/720p upscale for
weaker machines.

## Play it

```sh
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
godot --path . res://studies/run_layer.tscn -- --no-title --shape=ring --seed=1
```

Settings > Render resolution picks the cap (Native, 1440p, 1080p, 900p,
720p, 540p). Your kept choice is 720p (`user://look.cfg`).

Measure it:

```sh
Godot --windowed --path . -s res://tools/bench_run_layer.gd -- --no-title \
  --shape=sprawl --seed=2 --cap=1080 --caps=0,720,540 --stills --out=/tmp/zs-bench
```

Options: `--parts=shadows,kit,growth,stone,grass,sky_isles,msaa,ssao,lod_off,all_3d`
prices each part by taking it away; `--procs` times every node's `_process`;
`--census` counts triangles by isle and node. See the tool's header.

## How it was measured

`tools/bench_run_layer.gd` (new) loads the layer, records every frame until
it stands whole, then holds the camera at four spots worked out from the
plan:

- **spawn**: behind the pilot at the spawn, looking where he faces.
- **gulf**: from the rim of the first neighbourhood toward the last one.
- **mid**: 12 m over the isles in the middle, looking back.
- **next**: from the gate toward the next region's silhouette.

At each spot the pilot is ticked as in play (standing still) and the time
of day is held. It takes the median of 60 frames with vsync off.

- **Window**: fullscreen Retina, 3024×1898. The `--windowed` size request
  did not take, but this is how you play.
- **1080p cap**: 1708×1080 internal, upscaled by MetalFX spatial.
- **Upscale settings**: same window, cap 720 (1139×720) and cap 540
  (854×540).

Another agent was running test suites through most of this round, with load
averages from 5 to 45 on 18 cores. Numbers from contended runs swung by
±30 %. The table uses the one pair (before, then after) run at a load of
about 5. Read every number as ±10 %.

**GPU time is not available.** On Metal, `viewport_get_measured_render_time_gpu`
returns 0. The split below is the main thread's phases instead:

- **script**: `process_frame` to `frame_pre_draw`.
- **draw**: `frame_pre_draw` to `frame_post_draw`. This is the render CPU
  plus any wait on the GPU.

Whether a cost is GPU-side was judged by sweeping the resolution and by
taking parts away.

## Before / after

Sprawl, seed 2, 1080p cap. Each cell is before → after. Primitives count
every pass: depth prepass, colour and shadow.

| View | Frame ms | Script ms | Draw ms | Draw calls | Primitives |
|---|---|---|---|---|---|
| spawn | 40.0 → 37.9 | 11.3 → 10.4 | 26.1 → 26.6 | 2116 → 1956 | 7.22 M → 6.87 M |
| gulf | 14.8 → 13.5 | 8.5 → 5.8 | 5.5 → 8.2 | 1109 → 938 | 2.48 M → 2.36 M |
| mid | 22.2 → 21.3 | 13.1 → 3.8 | 9.1 → 18.0 | 1146 → 1050 | 5.41 M → 5.36 M |
| next | 8.7 → 6.8 | 5.6 → 3.3 | 2.6 → 1.6 | 109 → 109 | 0.17 M → 0.17 M |

Render resolution, same pair (frame ms, before → after):

| View | Native (1898 lines) | 1080p | 720p | 540p |
|---|---|---|---|---|
| spawn | 46.1 → 42.4 | 40.0 → 37.9 | 38.0 → 35.4 | 37.5 → 36.0 |
| gulf | 21.7 → 21.2 | 14.8 → 13.5 | 15.8 → 13.3 | 15.1 → 14.0 |
| mid | 33.1 → 33.8 | 22.2 → 21.3 | 17.9 → 17.9 | 20.6 → 17.2 |
| next | 10.4 → 10.3 | 8.7 → 6.8 | 9.4 → 6.9 | 9.4 → 7.4 |

Ring, seed 1 (contended pair, load about 44; frame ms at the 1080p cap):

| View | Before | After |
|---|---|---|
| spawn | 30.7 | 26.8 |
| gulf | 17.4 | 12.7 |
| mid | 22.4 | 19.1 |
| next | 13.0 | 10.4 |

How to read it:

- **Script time fell 2-10 ms a frame.** The mid view went from 13.1 to
  3.8 ms. Under contention the drop was bigger (gulf 20.5 → 10.7, spawn
  32 → 21), because the old per-frame script work grows when frames get
  slower.
- **Frame time fell less, because the frame is now GPU-bound.** In mid,
  the time the scripts gave back reappears as draw time spent waiting on
  the GPU, so the frame only went from 22.2 to 21.3 ms. On a machine whose
  CPU is busy (as it was most of this round), the script savings do show
  up in frame time.
- **The resolution cap barely matters where the frame is geometry-bound.**
  At spawn, 540p is only 2-4 ms faster than 1080p. Looking over isles
  (mid, gulf), native 1898 lines costs 8-12 ms more than 1080p.
- **The upscale is already the right shape.** RenderCap draws the 3D at
  the cap and upscales it with MetalFX spatial (FSR 1 elsewhere). The HUD
  stays at the window's full resolution. It is user-facing, with 540p and
  720p already offered. Nothing was added. MetalFX temporal and FSR 2 exist
  in this Godot (4.7.2) as `SCALING_3D_MODE_METALFX_TEMPORAL` and
  `SCALING_3D_MODE_FSR2`, but the earlier round chose spatial so drifting
  cloud and swaying grass never ghost. They were not measured (see
  Unverified).

## Where the frame goes

These numbers come from the parts priced at the 1080p cap, mostly in
contended runs, so read them as rough sizes.

| Part (taken away) | Saves at spawn | Saves at gulf | Saves at mid |
|---|---|---|---|
| Ruin kit meshes (stone and growth) | 9-14 ms, 4.6 M prims | 7-10 ms | 7-12 ms |
| …the growth surface alone | 8-12 ms, 3.5 M prims | 4-5 ms | 7-8 ms |
| …the stone alone | about 1 ms | about 3 ms | about 3 ms |
| Kit as shadow casters | about 5 ms | about 3 ms | about 4 ms |
| Grass multimeshes | up to 11 ms (noisy) | <1 ms | 3-4 ms |
| MSAA 4× | 3 ms | 0 | 2-3 ms |
| SSAO | 2 ms | 0 | 1.5 ms |
| All 3D | 28-34 ms | 7-12 ms | 11-12 ms |

Per-script time before the change, timed per node over 120 frames at
spawn:

| Script | Cost |
|---|---|
| The isles' small life | 6.7-7.7 ms |
| …loose leaves, per isle | 0.9-1.8 ms |
| …chaff | 0.1-0.8 ms |
| …songbirds | 0.25-0.5 ms |
| …butterflies | 0.1-0.2 ms |
| The base isle's life | 2.2-2.7 ms |
| The look (`_advance_look`) | 1.9-2.5 ms |
| The pilot and stage tick | 3.9-4.4 ms |
| Rope bridges | 0.6 ms |
| Wind horns | 0.4 ms |

Draw calls (about 1000-2100) are not the bottleneck on Metal. The cost is
triangles, most of them the ruins' growth: ivy, vine curtains of
2-triangle leaves on 3-sided stems, and moss. The ruins near the eye draw
it at full detail, in the colour pass and the shadow pass.

Streaming hitches, before:

| Cause | Cost |
|---|---|
| Each placed isle's tokens built a HUD only to free it | 60-160 ms once per isle, rendered |
| Undergrowth multimeshes built with two renderer calls per instance | 20-30 ms per tile, rendered |
| Ground grid read a whole row of rays per slice | 15-40 ms per slice |
| Big collision parts standing (the colonnade spine's "Spine": 9254 convex hulls) | 40-50 ms, unchanged |
| The aqueduct base's first build | 9-16 s at load, unchanged |
| The Broken Viaduct built on the main thread when a layer stands | 5.7 s headless, unchanged |

## What changed

- **Small life holds still when it can't be seen**
  (`scripts/kit_isle/kit_life.gd` `advance(delta, gap)`; callers in
  `motif_isle.gd` and `studies/kit_isle.gd` `_life_gap`).
  - Leaves, chaff, kicked blades and butterflies are a few cm. More than
    `SMALL_NEAR` (60 m) from the isle's edge they are under a pixel at
    1080 lines, so they stop and hide.
  - Songbirds do the same past `BIRDS_NEAR` (150 m).
  - Fireflies and tokens are untouched.
  - This cut script time by 2-10 ms a frame, more on a busy CPU.
- **Placed isles share the sky's token HUD.** `kit_tokens.gd` `setup`
  asks the isle for `token_hud` (`motif_isle.gd`) instead of building a
  HUD and freeing it. This removes a 60-160 ms hitch per isle.
- **The undergrowth and ground grid keep to their slice.**
  - Undergrowth placement checks the clock every try instead of every 16.
  - Its multimeshes are uploaded as one buffer (`KitFlora.batch_buffer`).
    It is checked identical to the per-instance setters.
  - The ground grid is read 8 cells at a time (`_col`).
- **The ruin kit has levels of detail** (`scripts/ruin_lod.gd`, new).
  - **Stone**: Godot's own simplifier, `ImporterMesh.generate_lods`. Its
    first level is about 39 % of the triangles, so the stone loses little
    on screen.
  - **Growth**: whole faces are kept or dropped, never reshaped. Stems are
    dropped at error 0.15 m (about 115 m). Leaves, mats and cushions are
    thinned to 50 / 25 / 10 % at about 230 / 540 / 1200 m, picked by a
    fixed hash.
  - Godot picks the level by on-screen error (1 px), for the shadow map
    too.
  - It runs on the isle's build worker. For the base and the viaduct it
    runs off the main thread (`add_async`).
  - It costs about 190-290 ms of worker time per isle and about 0.5 s for
    the viaduct.
  - A first, bolder version dropped stems at about 45 m. In the
    before/after captures the vine curtains under the spawn's floating
    stones read as broken strings of dots, so it was pulled back.
  - Measured with `--parts=lod_off`: LODs save 0.5-0.8 M primitives and
    2.6-2.9 ms at spawn and gulf.
- **Isles label their sky-budget spend** with the stage
  (`motif_sky.gd`, only while `SkyCommits.recording`). The bench uses this
  to name the work in its worst frames.
- **`tools/bench_run_layer.gd`** (new; committed for future rounds).

## Before/after captures

Captures were taken from the same spots in both builds, with the time of
day held (`--stills`, in `/private/tmp/zs-ab/s2` and `/private/tmp/zs-ab3/s2`).

- The turf, stone and silhouettes match.
- The differences in the diff images are drifting clouds, the moving
  airship, swaying growth and the wind ribbon. These run on time and are
  not frozen.
- The only LOD-made difference seen was the stem drop at 45 m, which was
  pulled back as described above.
- With the final levels (`/private/tmp/zs-ab3/s2`), 1:1 crops match by
  eye: the vine curtains under the floating stones at spawn, and the gulf
  view's far ruins.

## Geometry tricks (docs/art/model-budget.md)

One model family was changed: the ruin kit's built meshes, at runtime. No
art was changed.

| Trick | Applies? | Assessment |
|---|---|---|
| Import LODs (with visibility ranges for far copies) | **Applied** | Godot's `generate_lods` on the stone. Its LOD1 is about 39 % of 94-115 k triangles per isle. Custom face-thinning LODs on the growth (150-415 k triangles per isle, viaduct 417 k), at 73 / 50 / 25 / 10 %. Measured 0.5-0.8 M fewer primitives a frame and 2.6-2.9 ms. Visibility ranges were not used: the kit is one mesh per piece or merged run, and a range would pop whole ruins. |
| Vertex-colour grime | **Strong next step** | Bake the growth's colour into the stone's vertex colours for a far version. The growth could then go to 0 % past about 300 m instead of 10 %. Estimate: another 1-2 M primitives at spawn and mid, about 3-5 ms. |
| Sculpt high, bake low | Not here | The kit is procedural and faceted, with no textures. Baking normal maps would change the look and the pipeline. |
| Silhouette geometry | Already | The kit's chips and breaks are real geometry, and the simplifier keeps the outline (it simplifies by error). |
| Rigid parts on bones | Not applicable | No skinned models were changed. |
| Parallax depth | Not applicable | The stone has no textures, and the growth is cards. |

## What's left, by expected payoff

1. **Growth near the eye (GPU, about 5-8 ms).** Ruins within about 100 m,
   at spawn especially the base isle and the viaduct, draw full-detail
   growth twice, once in colour and once in shadow.
   - Split growth into its own instance so it can stop casting shadows
     past about 40 m (shadows stop at 140 m).
   - Or do the vertex-colour bake above.
   - Merged runs pick their LOD by their nearest point, so a long merged
     mesh stays at full detail. Splitting merges into chunks would let
     their far ends thin.
2. **Viaduct build on a worker.** It takes 5.7 s on the main thread when
   a sprawl layer stands (`layer_hazards.gd` `_build_viaduct`). It is the
   biggest hitch left.
3. **Grass (GPU, up to 4 ms in mid and more at spawn).**
   - Base and isle grass draws out to 95 m plus a 15 m fade.
     `VISIBILITY_RANGE_FADE_SELF` draws the fading band through the
     transparent pass.
   - Try a dithered fade or a shorter range for tufts past about 60 m,
     judged by eye.
4. **Big collision parts standing (40-50 ms hitches).** The colonnade
   spine's "Spine" has 9254 convex hulls; Temple and Mesa have
   thousands.
   - Add the bodies a few hundred shapes per slice.
   - Or simplify the hulls (fewer, bigger) for the walker.
5. **Layer change on the main thread** (`start_layer`, stage setup): spikes
   of 100-230 ms when a new layer stands.
6. **MSAA 4× → 2×** as a setting (2-3 ms in mid). It is a visible
   trade-off, so it is the user's call.
7. **Load**: the aqueduct base's 9-16 s first build.
8. **Scripts left**: the pilot and stage tick is 4 ms, the look 2 ms,
   rope bridges and wind horns 1 ms.

## Unverified

- **GPU time on Metal is unmeasured.** The driver gives no timestamps, so
  GPU cost was inferred from the resolution sweep and from taking parts
  away. It is not a split.
- **Most runs were contended** (load 5-45). Treat every number as ±10 %
  at best.
- **The streaming hitch counts (frames over 50 ms) are noise-dominated.**
  The removed causes were confirmed directly with stage traces:
  - tokens HUD: 60-160 ms gone;
  - undergrowth tile: 20-30 ms gone;
  - ground row: 15-40 ms gone.

  No clean run was made of the whole stream after the last commit.
- **The upscalers weren't measured:** MetalFX temporal / FSR 2 (not
  offered).
- **Three seeds per shape were not measured cleanly.** Only sprawl 2 had a
  quiet pair. Ring 1, ring 2 and sprawl 8 were contended.

## Tests

No new tests (prototyping). Targeted existing tests on this branch:

- **Pass**: `test_aqueduct_isle_life`, `test_ruin_growth`, `test_ruin_kit`,
  `test_aqueduct_isle_sky`, `test_ledger`.
- **Fails on the base too**: `test_motif_sky` ("dragon_roost stands whole":
  the roost has no life, and `.tokens` on null at
  `tests/test_motif_sky.gd:58`). This change did not cause it.

The full suite was not run. No existing test is known to break.

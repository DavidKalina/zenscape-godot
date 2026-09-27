# The water brush

Phase 3, slice 2 (branch `feature/water-brush`, 2026-09-26). Press `2` while creating (or pick Water on the creation palette) to take the water brush; `1` returns to the land brush. Water is one of the creation brushes in `scripts/genesis_canvas.gd` `BRUSHES`: it extends `scripts/creation_brush.gd` as a settling brush, and the editor's "land" tool holds it like the others (`docs/scenic/brushes.md`).

## What it does

- **Drag to pour.** Nothing changes while the button is down except the stroke feedback. The dabs are recorded, and nearby ones merge.
- **Release and the water settles** (`scripts/water_brush.gd`, `plan`), with gentle physics:
  - Each dab's water runs down the land by steepest descent to the low ground it drains to.
  - Each basin fills from its lowest point with the water poured into it. A pond already there counts as water already held, so pouring into a pond raises it.
  - Water past a basin's spill level runs over the lowest saddle, down the far side as a stream, into the next basin. Two basins that spill into each other become one lake above the saddle.
  - Water poured well above where it pools (0.3 m higher and 1.5 m from the shore) runs down to it as a stream. This is how water on a hilltop runs down and pools.
  - Lost water is water that would run off the plate's edge, or would spread too thin for a pond. It scoops a soft hollow where it last came to rest: the lowest point on its way down that is clear of the rim. The hollow is sized to hold it, and the water settles again. A pour on open ground therefore always leaves a pond. This is intent honoured by the land; hand-shaped land elsewhere is not touched.
  - **A pond at the rim rises.** Water poured into a pond that already brims at the plate's rim raises a soft lip on the rim beside it (`_lip`), and the pond rises, up to `LIP_RISE` per pour. The lip grows over up to three settles as the rising pond reaches more of the rim. A lip that raises no pond is dropped. Water the lip cannot hold scoops a hollow as before. New water that runs off the edge still scoops a hollow; it does not build a lip.
  - **Streams carve shallow beds** (`_carve_beds`). Each new stream lowers a soft (1 − t²)² trough under its course, `BED_DEPTH` deep and at least `BED_HALF_WIDTH` to either side, and its surface drops into the bed. Ground at or above a nearby pond's level is never cut below that level, so a bed cannot open a pond's bank. If a bed would still break a new pond's surface, the pour keeps its uncarved ground.
- **The ground moves first.** When a pour reshapes the land (a scooped hollow, stream beds, a rim lip), the ground sinks or rises into place over `WATER_SHAPE_SECONDS` (0.7 s), and then the water starts to fill (`NativeChunkEditor._shape_water_ground`). The ground moves with the light refresh a paint stroke uses, at 30 Hz. Another stroke, an undo or a new pour lands the shaping pour at once first.
- **Shift-drag or right-drag drains.** Ponds and streams under the brush are removed.
- **One undo** removes the whole pour: the ponds, the streams, any hollow, beds and lip.
- **Water fills; it never appears.**
  - A pond rises from its bed over `FILL_SECONDS`.
  - A stream's front runs down its course at `FLOW_SPEED`.
  - A pond fed by a stream starts to rise when the stream arrives, and an overflow leaves once its pond is 80% full.
  - Both run on the emergence clock (`zs_emergence_time`) and are drawn by the water shader (`shaders/reference_water_body.gdshaderinc`):
    - a pond carries its birth and rise in `UV`;
    - a stream carries its birth and run time in `CUSTOM1.zw`.
  - Births live in `GardenView.water_births`. Like emerged plants' births, they are neither saved nor undone, and water without a birth stands full.
- **Stroke feel.** A pour parts the fog over the stroke and swells the air softly (`SWELL_WATER`). There is no tremor and no growth wave (`scripts/stroke_feedback.gd`).
- **Life follows.** The settled water's rect is handed to emergence, so grass creeps out from new shores.

## Tunables

All tunables are constants at the top of `scripts/water_brush.gd`.

| Constant | Value | Meaning |
|---|---|---|
| `RATE` | 2.4 m³/s | Water poured per second at strength 1 with a 3 m brush. It scales with radius². |
| `SPILL_MARGIN` | 0.04 m | How far a full pond sits below its spill level, so it keeps a bank. |
| `MIN_DEPTH` | 0.06 m | Water shallower than this soaks in rather than making a pond. |
| `STREAM_DROP`, `STREAM_REACH` | 0.3 m, 1.5 m | How far above and away from its pond a pour must be to draw a stream. |
| `STREAM_WIDTH` | 0.32–0.85 m | Stream width, which grows with the square root of the water it carries. |
| `STREAM_LIFT` | 0.06 m | Stream surface above its bed on uncarved ground. |
| `SCOOP_MIN` | 0.5 m³ | The least lost water that scoops a hollow. |
| `SCOOP_RADIUS` | 1.8–4.5 m | Hollow radius (1.4 + 0.9·√V). |
| `SCOOP_DEPTH` | 0.15–0.9 m | Hollow depth, sized so the (1 − t²)² bowl holds the water. |
| `SCOOP_RIM` | 1.5 m | How far a hollow stays inside the plate's rim. |
| `MAX_PONDS`, `MAX_STREAMS`, `MAX_SCOOPS` | 6, 6, 2 | Per-stroke caps. |
| `BED_DEPTH`, `BED_HALF_WIDTH` | 0.14 m, 0.9 m | A new stream's bed: depth at its centre, and least half-width (or 1.1 × the stream's width). |
| `BED_SINK` | 0.75 | The share of the carved depth a stream's surface drops into its bed. |
| `BED_GUARD` | 0.03 m | How far above a nearby pond's level a bed stops cutting ground that stood above it. |
| `LIP_WIDTH` | 2.2 m | How far in from the plate's edge a rim lip reaches. |
| `LIP_RISE`, `LIP_FREEBOARD` | 0.5 m, 0.1 m | The most a rim pond rises in one pour, and how far the lip stands above the water it holds. |
| `LIP_PASSES` | 3 | Settles a lip may grow over. |
| `WATER_SHAPE_SECONDS` | 0.7 s | How long reshaped ground takes to move into place before the water fills (in `native_chunk_editor.gd`). |
| `FILL_SECONDS` | 3.2 s | Pond rise time. The shader reads it as `pond_fill_seconds`. |
| `FLOW_SPEED` | 2.4 m/s | Stream front speed. |
| `OVERFLOW_AT` | 0.8 | The share of its fill a pond reaches before its overflow leaves. |

Brush size (`radius`, 1–8 m, default 3) and flow (`strength`, 0.25–3) live on the brush, as the meadow, forest and path brushes keep theirs. `[` and `]` set the size, and Shift with `[` or `]` sets the flow.

## Pipeline

Nothing heavy runs on the main thread when a pour settles.

1. **Release.** `finish_stroke` snapshots the heights and hands the dabs to a worker. This takes about 1 ms.
2. **Plan.** `WaterBrush.plan` runs on the worker against a detached height copy. It samples a 57×57 grid, fills basins, validates each pond with the same mesh flood the renderer uses, and traces streams (`NativeWaterCourse.trace`, falling back to the grid path). Then it raises rim lips, scoops hollows and carves stream beds, settling again after each lip and hollow. It takes 25–70 ms, and up to about 135 ms when a rim lip needs three settles.
3. **Apply.** The plan applies as one undoable edit. If the land, the ponds or the streams changed while the worker ran, the plan is dropped and the status line asks for another pour. When the plan reshaped the ground, the edit's stroke stays open while the ground moves into place over `WATER_SHAPE_SECONDS`. Each 30 Hz tick is a light refresh of 1.5–3.8 ms. Then the ponds and streams land and the stroke closes.
4. **Settle.** The yielding refresh runs.
   - On a world without a recipe (the plain), `GardenView` floods the ponds, samples depth and shore fetch, lays the streams and assembles the pond arrays on a worker (`_sample_plain_water`).
   - Recipe worlds already flood their ponds on a worker. Since `feature/phase3-polish` they lay their streams there too, against a private copy of the recipe (4.3 ms to 0.4 ms on the main thread on seed 184).
5. **Reflections.** `planar_water.gd` no longer re-creates its views synchronously when water changes.
   - A live re-setup is spread over frames, and the previous views keep rendering until the new set is ready.
   - Prop and plant changes recopy geometry the same way.
   - The clip shader's level is now a uniform, so a new pond level only duplicates materials; it never parses a shader.
   - Only the two largest pond levels get a reflection view (`MAX_VIEWS`), because each view renders the scene again. The other ponds keep the ordinary surface (`planar_levels`).
   - **Clip shaders compile ahead.** Once the scene has grown, `_warm_shaders` walks it in 1 ms slices for the shaders its copies would clip. It compiles one clip shader per idle frame (`Shader.get_rid()` parses it). Frames while the hand paints, the world forms or a refresh runs are skipped. On the plain, four shaders compile in 3–7 ms each, on the first frames after the scene grows. Before this, each one cost 4–7 ms when a pour's first reflection setup handed it to a material. Compiled clip shaders now stay while their source shader lives, so water that drains and comes back compiles nothing.
   - **Materials sync by change.** Copies of one source material share one record. Each frame re-reads only the parameters seen to change (on the plain, only `planar_levels`) and checks a rolling 300 of the rest (`DISCOVERY_READS`, about 20 frames around the plain's 84 sources). A new copy snapshots its source, so nothing is pushed until a value changes. Copies' visibility, transform and mesh are written only when they differ.
6. **No-op rebuilds.** A rebuild that changes no water input, such as cover creeping in, keeps the water nodes and `GardenView.revision`, so nothing downstream re-derives from unchanged water.

## Measured

These are headless CPU main-loop intervals (`tools/profile_stroke.gd -- --mode=water --plain-seed 7`; `--mode=water` is short for `--mode=land --brush=water`). `--sync-water` restores the old main-thread water path and synchronous reflection setup for comparison.

| Case | Before (`--sync-water`) | After |
|---|---|---|
| Pour, then a second pour 3 frames later (`--then=restroke`) | 54.4 ms frame in the first settle; 41.7 and 24.7 ms frames in the second | 18.5 ms max, from the session's first reflection setup; the second settle's max is 13.6 ms |
| Pour, then 25 s of emergence (`--watch=25`) | 15 frames over 16.7 ms: 54.8 ms at settle, then about 25 ms every emergence step that adds plants | 3 frames over 16.7 ms: 18.8 and 20.1 ms (first reflection setup) and 36.1 ms (emergence's first plan, which is not water) |
| Release frame | 0.4 ms | 0.4–1.3 ms |

On seed 184, a raise stroke across the pond (a recipe world) loses its 24 ms settle frame in `content`. Its remaining 20–28 ms settle frames are in the recipe mesh build (`mesh` stage), which predates this slice.

### Water polish (`feature/water-polish`, 2026-09-26)

These are the same headless runs, before and after, on the same machine on the same day. Other agents' Godot runs shared the CPU, so single frames vary by a few ms.

| Case | Before | After |
|---|---|---|
| Pour, `--watch=20`: frames over 16.7 ms | 3: 18.6 and 18.7 ms (first reflection setup), 36.9 ms (emergence's first plan) | 1: 40.5 ms (emergence's first plan). The worst water frame is 13.3 ms. |
| Pour, `--then=restroke`: worst settle frame | 18.5 ms | 13.9 ms |
| Planar reflection `sync` per frame with ponds (median, p95) | 4.79, 4.98 ms | 0.58, 0.71 ms |
| Clip shader compiles inside a pour's settle | 4, 4–7 ms each (shader handed to a material) | 0. The 3–7 ms compiles move to idle frames after the scene grows. |
| Release frame | 0.8–1.7 ms | 0.8–1.4 ms |

What the three slow frames were, traced with per-frame marks:
- **18.6 ms.** This was the first reflection setup. Copying the terrain handed its new clip shader to a duplicated material, which compiles it (7.3 ms).
- **18.7 ms.** This was the setup's last frame. Its first `update_views` pushed all 10,760 material parameters to the copies, and then ran the per-frame sync again.
- **36.9 ms.** This is emergence's first plan, `BiomeBlend.live` plus planning, on the main thread. It is not water, and it belongs to the settle-hitch work. It measured 35–47 ms across runs on both builds, and its blend step took 14.6 ms before and 19.4 ms after. The machine was shared, so the difference is not attributed.

The per-frame reflection cost was the material loop. It made 10,760 `get_shader_parameter` calls a frame (168 copied materials, about 64 parameters each). Only `planar_levels` ever changed.

Probe (`tools/probe_water_brush.gd -- --plain-seed 7`, then with `--land`). A new last case pours twice into the pond nearest the rim:

| Case | Before | After |
|---|---|---|
| Plain: long pour into the hollow's rim pond | Level stays at -0.001 (the pour only deepened it) | Rises to 0.233, with 2 lip passes |
| Plain: into the rim pond (11, 6), twice | 0.128 → 0.128 | 0.128 → 0.367 (the second pour spills over an inland saddle, so it adds nothing) |
| `--land`: into the rim pond (-9.5, -11), twice | 0.18 → 0.18 | 0.18 → 0.404 |
| Plans that carved stream beds | – | Every plan that drew a stream |

`tools/probe_water_brush.gd -- --plain-seed 7 [--land]` prints each plan: a hollow, a hilltop, a long pour, a stroke across the plain, and two pours into the rim pond. For each it lists scoops, lips, beds, and the level over the pour point.

## Unverified

Only headless checks were run: parse checks, the profiles above, the probe, and a launch check. The launch check drove key `2`, a press, the settle, undo, key `1`, and Craft and Create. Nothing was rendered, so all of the following are unverified:

- Whether ponds read as rising from below. The rise uses the same lowered-surface trick as the regrow fill, so the bed hides the water until it arrives.
- Whether stream fronts run cleanly down their courses.
- Whether the scooped hollows look natural, and whether the 0.7 s of ground moving before the water reads as the land making room, or as a delay.
- Whether stream beds read as beds at the terrain's resolution. The vertices are about 0.6 m apart, so a bed is a soft swale, and its streams' banks follow it.
- Whether a rim lip reads as a natural bank. It is a raised strip up to 2.2 m in from the plate's edge.
- Whether copied materials that lag a parameter's first change for about 20 frames ever show in a reflection.
- Whether warming clip shaders ahead also warms the GPU pipelines. Only the shader parse was moved. Pipeline compilation under the Forward+ renderer was not measured.
- How the double-buffered reflections behave, and whether the brief window after a pour, while the new reflection views are prepared, reads. During that window a new pond shows the ordinary water surface.
- Whether the Fidelity palette and clearer sky on the plain match the reference.

## Later

- ~~Emergence's first plan (35–47 ms headless) is the last frame over 16.7 ms after a pour.~~ It runs on a worker since `feature/settle-hitches`.
- A sculpt or new stroke that lands while a pour is still planning (25–135 ms after release) drops the pour and asks for another. Replanning against the new ground would keep it.
- A pond whose spill is an inland saddle cannot be raised by more water; the overflow runs on as a stream. A pour could also dam the saddle, but none does.
- The streams' carve is not animated separately from the stream front. The whole bed forms in the 0.7 s before the water runs.

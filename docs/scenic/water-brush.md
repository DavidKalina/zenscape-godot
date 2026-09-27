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
- **Shift-drag or right-drag drains.** Ponds and streams under the brush are removed.
- **One undo** removes the whole pour: the ponds, the streams and any hollow.
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
| `FILL_SECONDS` | 3.2 s | Pond rise time. The shader reads it as `pond_fill_seconds`. |
| `FLOW_SPEED` | 2.4 m/s | Stream front speed. |
| `OVERFLOW_AT` | 0.8 | The share of its fill a pond reaches before its overflow leaves. |

Brush size (`radius`, 1–8 m, default 3) and flow (`strength`, 0.25–3) live on the brush, as the meadow, forest and path brushes keep theirs. `[` and `]` set the size, and Shift with `[` or `]` sets the flow.

## Pipeline

Nothing heavy runs on the main thread when a pour settles.

1. **Release.** `finish_stroke` snapshots the heights and hands the dabs to a worker. This takes about 1 ms.
2. **Plan.** `WaterBrush.plan` runs on the worker against a detached height copy. It samples a 57×57 grid, fills basins, validates each pond with the same mesh flood the renderer uses, and traces streams (`NativeWaterCourse.trace`, falling back to the grid path). It takes 20–70 ms.
3. **Apply.** The plan applies as one undoable edit. If the land, the ponds or the streams changed while the worker ran, the plan is dropped and the status line asks for another pour.
4. **Settle.** The yielding refresh runs.
   - On a world without a recipe (the plain), `GardenView` floods the ponds, samples depth and shore fetch, lays the streams and assembles the pond arrays on a worker (`_sample_plain_water`).
   - Recipe worlds already flood their ponds on a worker.
5. **Reflections.** `planar_water.gd` no longer re-creates its views synchronously when water changes.
   - A live re-setup is spread over frames, and the previous views keep rendering until the new set is ready.
   - Prop and plant changes recopy geometry the same way.
   - The clip shader's level is now a uniform, so a new pond level only duplicates materials; it never parses a shader.
   - Only the two largest pond levels get a reflection view (`MAX_VIEWS`), because each view renders the scene again. The other ponds keep the ordinary surface (`planar_levels`).
6. **No-op rebuilds.** A rebuild that changes no water input, such as cover creeping in, keeps the water nodes and `GardenView.revision`, so nothing downstream re-derives from unchanged water.

## Measured

These are headless CPU main-loop intervals (`tools/profile_stroke.gd -- --mode=water --plain-seed 7`; `--mode=water` is short for `--mode=land --brush=water`). `--sync-water` restores the old main-thread water path and synchronous reflection setup for comparison.

| Case | Before (`--sync-water`) | After |
|---|---|---|
| Pour, then a second pour 3 frames later (`--then=restroke`) | 54.4 ms frame in the first settle; 41.7 and 24.7 ms frames in the second | 18.5 ms max, from the session's first reflection setup; the second settle's max is 13.6 ms |
| Pour, then 25 s of emergence (`--watch=25`) | 15 frames over 16.7 ms: 54.8 ms at settle, then about 25 ms every emergence step that adds plants | 3 frames over 16.7 ms: 18.8 and 20.1 ms (first reflection setup) and 36.1 ms (emergence's first plan, which is not water) |
| Release frame | 0.4 ms | 0.4–1.3 ms |

On seed 184, a raise stroke across the pond (a recipe world) loses its 24 ms settle frame in `content`. Its remaining 20–28 ms settle frames are in the recipe mesh build (`mesh` stage), which predates this slice.

`tools/probe_water_brush.gd -- --plain-seed 7 [--land]` prints each plan for a hollow, a hilltop, a long pour and a stroke across the plain.

## Unverified

Only headless checks were run: parse checks, the profiles above, the probe, and a launch check. The launch check drove key `2`, a press, the settle, undo, key `1`, and Craft and Create. Nothing was rendered, so all of the following are unverified:

- Whether ponds read as rising from below. The rise uses the same lowered-surface trick as the regrow fill, so the bed hides the water until it arrives.
- Whether stream fronts run cleanly down their courses.
- Whether the scooped hollows look natural.
- Whether streams on uncarved ground drape well on side slopes.
- How the double-buffered reflections behave, and whether the brief window after a pour, while the new reflection views are prepared, reads. During that window a new pond shows the ordinary water surface.
- Whether the Fidelity palette and clearer sky on the plain match the reference.

## Later

- Carve a shallow bed under new streams. Today they drape over the ground.
- Animate the scooped hollow, rather than landing it with the water.
- A pour into a full pond at the rim deepens it but cannot raise it. Consider letting it spill over the edge visibly.
- Planar reflections still cost about 4.6 ms of CPU per frame while ponds exist (`_update_view_list` syncing every material parameter). This is a steady cost, not a hitch, and predates this slice.
- The session's first reflection setup parses one clip shader per material (5–9 ms slices). A shader warm-up (Phase 4) would remove it.

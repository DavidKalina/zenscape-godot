# The water brush

Phase 3, slice 2 (branch `feature/water-brush`, 2026-09-26). Press `2` while creating (or pick Water on the creation palette) to take the water brush; `1` returns to the land brush. Water is one of the creation brushes in `scripts/genesis_canvas.gd` `BRUSHES`: it extends `scripts/creation_brush.gd` as a settling brush, and the editor's "land" tool holds it like the others (`docs/scenic/brushes.md`).

## What it does

- **Drag to pour, and the water arrives under the hand** (`feature/live-water`, see "Live pour" below). The dabs are recorded, and nearby ones merge. Every 0.2 s while the button is down the pour so far is planned again, and the latest plan shows: ponds rise on from where they stand, streams run on, and ground a pour reshapes moves first. Release plans the last dabs and closes the pour.
- **The water settles** (`scripts/water_brush.gd`, `plan`), with gentle physics:
  - Each dab's water runs down the land by steepest descent to the low ground it drains to.
  - Each basin fills from its lowest point with the water poured into it. A pond already there counts as water already held, so pouring into a pond raises it.
  - Water past a basin's spill level runs over the lowest saddle, down the far side as a stream, into the next basin. Two basins that spill into each other become one lake above the saddle.
  - Water poured well above where it pools (0.3 m higher and 1.5 m from the shore) runs down to it as a stream. This is how water on a hilltop runs down and pools.
  - Lost water is water that would run off the plate's edge, or would spread too thin for a pond. It scoops a soft hollow where it last came to rest: the lowest point on its way down that is clear of the rim. The hollow is sized to hold it, and the water settles again. A pour on open ground therefore always leaves a pond. This is intent honoured by the land; hand-shaped land elsewhere is not touched.
  - **A pond at the rim rises.** Water poured into a pond that already brims at the plate's rim raises a soft lip on the rim beside it (`_lip`), and the pond rises, up to `LIP_RISE` per pour. The lip grows over up to three settles as the rising pond reaches more of the rim. A lip that raises no pond is dropped. Water the lip cannot hold scoops a hollow as before. New water that runs off the edge still scoops a hollow; it does not build a lip.
  - **Streams carve shallow beds** (`_carve_beds`). Each new stream lowers a soft (1 − t²)² trough under its course, `BED_DEPTH` deep and at least `BED_HALF_WIDTH` to either side, and its surface drops into the bed. Ground at or above a nearby pond's level is never cut below that level, so a bed cannot open a pond's bank. If a bed would still break a new pond's surface, the pour keeps its uncarved ground.
- **The ground moves first.** When a pour reshapes the land (a scooped hollow, stream beds, a rim lip), the ground sinks or rises into place, and then the water lands (`NativeChunkEditor._shape_pour`). While the hand pours a replan's ground moves over `POUR_SHAPE_SECONDS` (0.3 s); the plan at release takes `WATER_SHAPE_SECONDS` (0.7 s). The ground moves with the light refresh a paint stroke uses, at 30 Hz. On a recipe world's first sculpt it lands at once with the yielding refresh instead, because a light refresh would shade the whole mesh on the main thread (about 40 ms). Another stroke, an undo or a new pour lands the shaping plan at once first.
- **Shift-drag drains.** Ponds and streams under the brush are removed. Right drags belong to the camera in the creation shell.
- **One undo** removes the whole pour: the ponds, the streams, any hollow, beds and lip, however many plans showed while it poured.
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
- **Quiet guidance** (slice 8, `docs/scenic/guidance.md`). A new pond may sit up to 5 cm lower when that trims a thin fringe. A scooped hollow may move up to 1.5 m to leave no sliver of land beside other water, and is a soft oval along the contour instead of a circle. `--no-guidance` restores the plain plan.

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
| `WATER_SHAPE_SECONDS` | 0.7 s | How long the release plan's reshaped ground takes to move into place before the water fills (in `native_chunk_editor.gd`). |
| `POUR_REPLAN` | 0.2 s | Least time between plans while the hand pours (in `native_chunk_editor.gd`). A plan also waits for the last one to show. |
| `POUR_SHAPE_SECONDS` | 0.3 s | How long a replan's reshaped ground takes to move while the hand pours (in `native_chunk_editor.gd`). |
| `FILL_SECONDS` | 3.2 s | Pond rise time. The shader reads it as `pond_fill_seconds`. |
| `FLOW_SPEED` | 2.4 m/s | Stream front speed. |
| `OVERFLOW_AT` | 0.8 | The share of its fill a pond reaches before its overflow leaves. |

Brush size (`radius`, 1–8 m, default 3) and flow (`strength`, 0.25–3) live on the brush, as the meadow, forest and path brushes keep theirs. `[` and `]` set the size, and Shift with `[` or `]` sets the flow.

## Pipeline

Nothing heavy runs on the main thread while a pour shows or settles.

1. **Pour.** The first dab starts the pour (`NativeChunkEditor._pour_live`). It snapshots the heights, ponds and streams, after any land weathering still in flight has landed. No undo step opens yet.
2. **Plan.** At most every `POUR_REPLAN`, and only once the last plan has shown, the dabs so far go to a worker. `WaterBrush.plan` runs there against a detached copy of the snapshot's heights, so every plan is the whole pour from its start, never a pour on top of a pour. It samples a 57×57 grid, fills basins, validates each pond with the same mesh flood the renderer uses, and traces streams (`NativeWaterCourse.trace`, falling back to the grid path). Then it raises rim lips, scoops hollows and carves stream beds, settling again after each lip and hollow. It takes 25–70 ms, and up to about 135 ms when a rim lip needs three settles.
3. **Show.** The first plan that changes anything opens the pour's undo step (`data.begin_stroke`). Each plan's ground moves toward its heights with 30 Hz light refreshes (1.5–3.8 ms each on the plain), then its ponds and streams go into the data with fill births that carry on from what is showing (below), and the yielding refresh publishes them. Plants an earlier plan's water withdrew come back before the new plan's water withdraws its own, so only plants under the water showing are gone. If the land, the ponds or the streams changed under the pour, it closes on what is showing and the status line asks for another pour.
4. **Release.** `finish_stroke` hands over the dabs (about 1–2 ms); the undo step stays open. The last plan runs, shows with `WATER_SHAPE_SECONDS` of ground movement, and the step closes (`_commit_pour`): one undo removes the pour, emergence hears its rect, and `water_settled` fires. A new stroke, an undo or a world change while that last plan is on the worker closes the pour at once on the plan showing, without the last 0.2 s of dabs.
5. **Settle.** The yielding refresh runs.
   - On a world without a recipe (the plain), `GardenView` floods the ponds, samples depth and shore fetch, lays the streams and assembles the pond arrays on a worker (`_sample_plain_water`).
   - Recipe worlds already flood their ponds on a worker. Since `feature/phase3-polish` they lay their streams there too, against a private copy of the recipe (4.3 ms to 0.4 ms on the main thread on seed 184).
6. **Reflections.** `planar_water.gd` no longer re-creates its views synchronously when water changes.
   - A live re-setup is spread over frames, and the previous views keep rendering until the new set is ready.
   - Prop and plant changes recopy geometry the same way.
   - **While a pour shows they hold** (`NativeChunkEditor.water_pouring`, `planar_water.gd` `_hold`). Re-setting up every replan would never finish. Views whose level still stands keep rendering; a view whose pond level moved is hidden and its level unmarked, so that pond draws the ordinary surface. The views re-set up once, after the refresh that closes the pour.
   - The clip shader's level is now a uniform, so a new pond level only duplicates materials; it never parses a shader.
   - Only the two largest pond levels get a reflection view (`MAX_VIEWS`), because each view renders the scene again. The other ponds keep the ordinary surface (`planar_levels`).
   - **Clip shaders compile ahead.** Once the scene has grown, `_warm_shaders` walks it in 1 ms slices for the shaders its copies would clip. It compiles one clip shader per idle frame (`Shader.get_rid()` parses it). Frames while the hand paints, the world forms or a refresh runs are skipped. On the plain, four shaders compile in 3–7 ms each, on the first frames after the scene grows. Before this, each one cost 4–7 ms when a pour's first reflection setup handed it to a material. Compiled clip shaders now stay while their source shader lives, so water that drains and comes back compiles nothing.
   - **Materials sync by change.** Copies of one source material share one record. Each frame re-reads only the parameters seen to change (on the plain, only `planar_levels`) and checks a rolling 300 of the rest (`DISCOVERY_READS`, about 20 frames around the plain's 84 sources). A new copy snapshots its source, so nothing is pushed until a value changes. Copies' visibility, transform and mesh are written only when they differ.
7. **No-op rebuilds.** A rebuild that changes no water input, such as cover creeping in, keeps the water nodes and `GardenView.revision`, so nothing downstream re-derives from unchanged water.

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

### Live pour (`feature/live-water`, 2026-09-27)

The user: "You have to release for the water to appear. I'm instinctively feeling like I'm painting, but as I'm dragging, nothing's happening until I release." Water now arrives while the button is held.

- **Continuity.** Every plan replans the whole pour from its start, so a pond's record changes as the pour grows. Its fill birth carries on from the level showing rather than rising from its bed again (`_pour_births`). The shader lowers a pond by drop·(1 − f)², f over `FILL_SECONDS`; a pond an earlier plan raised (its seed lies in the new region, or the new seed in its region) gets a birth that starts at the level showing now and rises as fast as it was rising, or faster when the new rise needs it. An unchanged record keeps its birth. A stream whose head is within 1.2 m of one already running keeps its birth, so its front runs on. New water waits its plan's delay as before.
- **What the hand sees.** On the plain the ground starts to sink about 0.25 s after the press, and the first water is published about 0.5 s after it (0.27–0.5 s in the runs below), then rises over `FILL_SECONDS`. A 3 s pour publishes about 8 plans.
- **Audio.** `genesis_audio.gd` `_on_water_settled` now counts births still moving, not only births from the last 0.05 s, so ponds a pour started while held still sound their fill after release.
- **Fire.** `fidelity.gd` `_advance_fire` re-seeds the fire field's water mask when the surface map changes, polled every 2 s. That rebuild costs 19–25 ms on seed 184, and every replan republishes the map, so it now waits until the pour closes. It is not new: `main` pays it once, about 1 s after a pour settles on a recipe world (21.8 ms with `--watch=4`). It is outside the plain's budget and still to move off the main thread.

Headless CPU main-loop intervals (`tools/profile_stroke.gd -- --mode=water --plain-seed 7`, 2.2 m brush, strength 2), before (`main` 772dc3c) and after, on the same machine the same day, shared with other agents' runs. The profiler now also prints `first_water_ms` (press to the first frame with the pour's water published), `stroke_publishes` and `slow_stroke_stages`.

| Case | Before | After |
|---|---|---|
| 3 s pour (`--dabs=90`): water while held | none until release | first at 0.49 s, 8 publishes |
| 3 s pour: worst frame while held | 10.3 ms | 13.5 ms (light refreshes while the ground moves) |
| 3 s pour: worst settle frame | 13.9 ms | 13.6 ms |
| 1 s pour (default 30 dabs): worst held / settle frame | 10.2 / 14.2 ms | 11.9 / 14.1 ms |
| 3 s pour, `--then=restroke` (second pour 3 frames after release) | – | 14.3 ms held, 12.4 ms settle; 2 undo steps |
| 3 s pour, `--watch=20` | – | 0 frames over 16.7 ms; worst 15.0 ms (emergence, `content`) |
| 2 s pour, `--then=undo` | – | 13.0 ms held, 10.1 ms settle; the undo takes the whole pour |
| 2 s pour, `--then=shift` (a drain back over it) | – | 12.6 ms held, 13.9 ms settle; the drain 12.1 / 10.6 ms |
| Seed 184 (recipe world), 3 s pour | 10.0 ms held, 12.1 ms settle; 21.8 ms fire re-seed about 1 s later | 13.3 ms held, first water at 0.14 s; the fire re-seed (25.0 ms) lands in the settle once the pour closes |
| Release frame | 0.4–1.3 ms | 0.03–2.3 ms |

Before the recipe-world gates, a pour on seed 184 had a 29–42 ms frame (a light refresh shading the first sculpt's whole mesh) and a 19–21 ms frame (the fire re-seed) while held.

The final plan is the same as `main`'s for the same dabs and start: seed 184 settles to the same ponds and streams. The plain at `--plain-seed 7` differs between runs on both builds, because its start heights differ from run to run. `tools/probe_craft_tools.gd -- --plain-seed 7` passes all 26 checks, including a sculpt landing a shaping pour first and one undo taking the pour whole.

### Water ball (`feature/water-ball`, 2026-09-27)

The user: "imagine a swirling ball of water with fish in it, and you drop it into the geometry to create either a river, lake, pond, waterfall, depending on the geometry." Water is a thing you hold and let go, and the land decides what it becomes. The ball is the Water brush's default; `--pour-water` brings back drag-to-pour (`NativeChunkEditor.water_ball`). Shift-drag still drains as before.

- **Hold** (`scripts/water_ball.gd`). With water in hand a left press condenses a ball over the ground point, its underside `HOVER` (1.6 m) up. It fills while held at the rate a pour of the brush's size and flow would (`WaterBrush.RATE` × strength × (radius/3)² m³/s), from `BALL_MIN_VOLUME` (0.6 m³) to `BALL_MAX_VOLUME` (24 m³, about 10 s at the defaults). Its radius is ∛(3V/4π), at least `MIN_RADIUS` (0.28 m): a full ball is 1.8 m across the radius. It condenses with an ease-out-back overshoot, swells past each new size on a spring and settles, trails the pointer on an underdamped spring, bobs, and stretches along its speed. The water wobbles more after a jolt and rings down.
- **The look** (`shaders/water_ball.gdshader`). The ponds' own colours: the depth ramp from GardenView `sample_ponds` (79ae9b to 245a5c over the chord through the ball) × `zs_palette_water`, with the pond's fresnel, sky reflection, hemisphere light and sun glint (the non-planar path of `reference_water_body.gdshaderinc`). It looks through to what is behind and inside, bent like a lens and tinted by the ponds' absorption, so its fish show. Three spiral arms and a finer counter-swirl wind round the axis and climb, bending the normal and catching a little foam white.
- **Fish.** 2 + V/5 of them (at most 5) circle inside at their own depths and paces, half of them the other way round. They are LandLife's own fish meshes and swim material (`LifeModels.fish`, tail beat on), from one pond company (koi, or wild fish), and grow in as the ball grows.
- **Release.** A small hop (anticipation), then gravity (18 m/s²) straight down. On the ground it squashes flat over 0.14 s and bursts: a ring runs out, 14 droplets fly, and each fish leaps out on its own arc and dives in. The landing hands its water to the pour pipeline as one dab (`WaterBrush.drop`, then `_release_pour`), so the settle, fill, streams, scoops, lips, beds, emergence, undo and `water_settled` are the poured stroke's own. One undo takes the whole drop back, waterfalls included.
- **What the land made of it** (`_ball_falls`, `ball_settled`). Before the pour's undo step closes, every new stream's steepest stretch that drops at least `FALL_DROP` (1.2 m) within `FALL_REACH` (2.5 m), at `FALL_SLOPE` (0.8) or steeper, becomes a waterfall object (`NativeTerrainData.add_waterfall`, drawn by `NativeGardenFalls` with its plunge and mist), at most `FALL_MAX` (2) per drop. The drop is then named, first match: *waterfall*; *stream* (a new stream at least `RIVER_LENGTH`, 5 m, long); *lake* (a pond at least `LAKE_AREA`, 40 m², from at least `LAKE_VOLUME`, 12 m³, or one that swallowed others); *pond*; or *soaked*. The status line says it ("The water found a way down.").
- **The fish stay** (LandLife `carry_fish`). The ball's fish go to the pond it made: the new fish sites nearest the biggest new pond take them, in the ball's own kinds and markings, and come in `CARRY_DELAY` (2 s) after the site opens, while the pond finishes rising. A small ball's pond may hold no water as deep as the survey's 0.22 m; its own fish then settle in water at least `CARRY_DEPTH` (0.1 m) deep. Fish no site takes within `CARRY_SECONDS` (30 s) are gone.

`tools/probe_water_ball.gd` drives the real input path on the plain (press, the editor's own `_process` following the pointer, release) for four drops and prints each:

| Drop | Held | V (m³) | Radius | Fish | Became | Fish arrived | Worst frame held / settling |
|---|---|---|---|---|---|---|---|
| Plain (-3, 2) | 1.5 s | 4.2 | 0.98 | 2 | pond, 67 m² | 2 of 2 in 1.8 s | 9.2 / 10.4 ms |
| Plain (2.5, -1.5) | 6 s | 15.0 | 1.52 | 5 | stream: two ponds joined by a 5.8 m stream | 5 of 5 in 2.4 s | 11.4 / 11.4 ms |
| Plain (0.5, 1), past the cap | 12 s | 24.0 | 1.79 | 5 | lake: two ponds, 57.5 m², two short streams | 5 of 5 in 2.3 s | 10.3 / 11.3 ms |
| Top of an alpine peak (8.6 m) | 3 s | 7.8 | 1.22 | 3 | waterfall: a 7.6 m stream with one fall, into ponds of 53 m² | 3 of 3 in 2.4 s | 13.9 / 20.8 ms |

The plain's start heights differ from run to run, so the same drop can come out a little differently: in an earlier run the 15 m³ drop left a 1.1 m stream and read as a pond. Each drop added one undo step, and one undo restored heights, ponds, streams and objects exactly. Release costs about 0.2 ms. The one frame over 16.7 ms (20.8 ms, the peak drop's settle) lands in the refresh's `maps` stage. A Shift press with water in hand makes no ball and paints (drains) as before. Headless, so none of the look or motion was seen.

Unverified (nothing was rendered):

- The ball's whole look: whether it reads as the ponds' water rather than glass, the swirl, the lens and tint on what is behind it, the fish inside it, the foam streaks; whether `water_ball.gdshader` compiles at all (headless does not compile shaders).
- The motion: condense, swell, follow, bob, stretch, hop, fall, squash, burst, ring, droplets and the fish leaping out.
- The fish meshes in a MultiMesh of one outside LandLife's batches, and their scale inside the ball.
- The waterfall on a brush stream: it appears when the pour closes, before the stream's front reaches it, and draws over the stream's own mesh along the same stretch.
- The gap between the fish diving in and arriving (about 2–4 s while the pond rises and the survey reads it).

Known gaps:

- On open ground a drop never makes a lake by itself: water that would spread thinner scoops a hollow of at most `SCOOP_RADIUS` (4.5 m), about 63 m². A lake comes from a basin the land already has, or from ponds joining.
- A carried fish keeps its look only until the place is saved and loaded: saved life stores sites, not looks, so it comes back as the pond's own kind.
- A ball dropped while an earlier ball's pour still settles closes that pour on the plan showing, as a new stroke does.

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
- The live pour (`feature/live-water`) was only run headless, where the emergence clock stands still under the profiler, so the fill continuity was checked by its arithmetic, not seen. Still to judge on screen:
  - whether ponds rise smoothly across replans, or pulse every 0.3–0.5 s;
  - whether a hollow that grows and shifts as the pour goes on reads as the land making room;
  - whether a pond's level stepping down a few centimetres reads badly. As a pour grows, its hollow widens and the planned level can fall, about 7 cm over a 4 s pour on the plain. The fill cannot sink water, so a pond that already stood above the new level drops to it at once.
  - whether ponds whose reflections are held show the ordinary surface for the length of the pour.

## Later

- ~~Emergence's first plan (35–47 ms headless) is the last frame over 16.7 ms after a pour.~~ It runs on a worker since `feature/settle-hitches`.
- ~~A sculpt or new stroke that lands while a pour is still planning drops the pour.~~ Since `feature/live-water` it closes the pour on the plan showing. That plan misses at most the last 0.2 s of dabs.
- A live pour plans only after the last plan has shown, so the worker sits idle while the ground moves and the refresh publishes. Planning the next one alongside would publish about twice as often.
- The fire field's water re-seed (19–25 ms on recipe worlds) runs on the main thread.
- A pond whose spill is an inland saddle cannot be raised by more water; the overflow runs on as a stream. A pour could also dam the saddle, but none does.
- The streams' carve is not animated separately from the stream front. The whole bed forms in the 0.7 s before the water runs.

# Live water

Branch `feature/water-flow` (2026-09-28). The user asked for water that is physics-based above all: "I want a user to be able to create a mountain, add a waterfall to it, and then, with that water, if they thumb carve, the water can fill the areas where they thumb carved, and fill into a pond if they depress that area with the palming tool." They chose a real flow simulation over running the water brush's one-shot plan again.

Under `--modeless` a dropped water ball feeds a live shallow-water simulation instead of the one-shot plan (`docs/scenic/water-brush.md`). `--water-flow` turns it on without `--modeless` (the water brush's ball then feeds it too), and `--planned-water` keeps the plan for A/B.

Checked headless (`tools/probe_water_flow.gd`, `tools/probe_water_flow_modeless.gd`) and filmed (`tools/film_water_flow.gd`, see "Look pass" below).

## What it does

- **Water runs, pools and spills.** Water runs downhill, fills a thumb's groove as a channel, pools in a hollow or a palm-pressed basin, and spills over the lowest point of the rim into the next low ground.
- **It follows the land.** Every step reads the ground under each cell again from the terrain's heights. A trench cut out of a pond drains it into the trench; a basin pressed beside a stream takes the stream; a peak raised under a pond throws the water off. There is no hook to miss: a sculpt, the clay, an undo, a mountain springing and a new world all move the water the same way.
- **The plate's edge drains, and pours.** Water that reaches the plate's outer ring of cells falls off the plate. A basin holds its water until the water tops the lowest point of its rim; only then does it run on, and off the edge if nothing lower stops it. This keeps water from ever building up against the rim, and needs no lip. What leaves over each edge cell is counted (m³/s, smoothed), and where it leaves, a waterfall pours down the block's side into the void ("Edge falls" below). A thumb groove run out through the rim notches it into a spillway for this (`docs/scenic/modeless.md`, "The thumb at the rim").
- **Water soaks and evaporates.** Every wet cell loses `evaporation` a second, and thin water (under `soak_depth`) loses up to `soak` more, so a front soaks in as it runs. A steady spring therefore levels off: in the probe, a 0.084 m³/s spring's water holds at about 12.6 m³ over about 50 m² after four minutes. A pond without a source lasts a long while (a 6 m³ pond, about 15 minutes); a puddle on flat ground soaks in within a minute.
- **Springs and bursts.** A ball that lands 1.2 m above the plate's low ground (`SPRING_RISE`; the low ground is the plate's 20 % height quantile), or on ground steeper than `SPRING_SLOPE`, **stays as a spring**, pouring `SPRING_SHARE` of its volume each second. The spring rises just down the slope from where the ball landed (only as far as its footprint needs to lie on one flank, at most `SPRING_SET`, 1 m), and the ball's own water wells out of it over `SPRING_HEAD_SECONDS` (10 s). Where the spring's course levels off on open ground, the water wears a rill down to a pool at the foot (see "Drop legibility" below). A ball anywhere else lets its water go once, over `BURST_SECONDS` across `BURST_RADIUS`. The user will refine where springs come from.
- **Water from the sky** (`--modeless`). The water ball had no door under `--modeless` (left presses on the land are clay). Now a tuft torn from the sky's cloud and carried over the land condenses a water ball there, and it fills from the cloud while held (`docs/scenic/sky-cloud.md`; before that, any drag from the void did). Letting go drops it. A click in the void is still the snap. The void's hint says so.
- **Undo, drain, save.**
  - A spring is its own undo step: undo removes it and redo brings it back. Springs ride the terrain history (`history_captured`, `state_restored`), as the forest wish does.
  - A burst is not undone: its water is already on the land, and it soaks away.
  - The water itself is not part of undo. Undoing a sculpt puts the land back, and the water flows to fit.
  - The water brush's Shift-drag drains live water and any spring under it.
  - Saved places carry an optional `water_flow` field: the springs, and the depth grid deflated as float32 in base64. Saves without it load dry. Depth saved on a different grid (the other build) is dropped, but the springs are kept.
- **Life follows.** Every second the standing water is read (pools deeper than 0.15 m and slower than 0.12 m/s, over at least 12 cells):
  - A pool that appears, goes, or changes by 2 m² or more is reported, at most every 3 s. It goes through `_stroke_ended("water")` to emergence, and through `water_settled` to life and sound, as a settled pour is.
  - Life's survey reads the live water's still surface with the ponds' (`still_water_triangles`), so fish, frogspawn and waders find it.
  - Emergence gets the wet cells (`flow_wet`), and nothing emerges under the water.
  - A ball's fish wait up to 90 s for a pool within 12 m of where it landed, and go to the nearest one.

## Design

| | |
|---|---|
| Grid | Regular, over the terrain's bounds (the 28 m plate, x and z −14 to 14). 0.25 m cells natively (112 × 112 = 12,544 cells), 0.5 m in the GDScript mirror (56 × 56). The terrain mesh has 2,025 points about 0.6 m apart, so the grid is finer than the ground it sits on. |
| Ground | Each cell's centre is mapped once to the terrain triangle under it and its barycentric weights (`WaterFlow.map_cells`, 12 ms on a worker). Each step then reads the ground as three weighted heights, which is `NativeTerrainData.sample`'s arithmetic. Cells off the mesh are walls. |
| Method | Virtual pipes (O'Brien & Hodgins 1995; Mei, Decaudin & Hu 2007). Each cell keeps an outflow through a pipe to each of its four neighbours. The outflow is accelerated by the drop in surface height (ground plus water), through a pipe as wide as the cell and as deep as the water it leaves, so the flow accelerates at g × slope whatever the cell size. Friction slows it (λ = `friction` + `drag`/depth, solved implicitly), so a thin sheet runs slower than a deep channel. The outflows are scaled so no cell gives more than it holds, and then each depth moves by what came in less what went out. Velocity comes from the mean flux across each cell over its mean depth, capped at `max_speed`. |
| Timestep | Fixed, apart from the frame: 1/60 s natively and 1/30 s in the mirror, at most 4 steps a frame. A slow frame slows the water rather than piling up work. Both are well inside the pipes' stability limit for water under about 5 m deep. |
| Edge | The ring of plate cells at the grid's border (or beside a wall) drains. What arrives there is counted as `drained` and removed. The ring is the outermost 0.25 m, so water leaves at the lip, not a cell or more short of it (the probe finds the channel wet to the cell beside the edge). Each edge cell also keeps what it drained over the step as a rate, eased with `edge_smooth` (0.5 s), the brink depth that rate makes (critical depth, (q²/g)^⅓ for q per metre of lip) and the velocity of the cell inward of it (its own is meaningless: it never holds water). `stats()` adds the total as `edge_flux`; `drained` still counts every litre. |
| Losses | Per wet cell per second: `evaporation` + `soak` × max(0, 1 − depth/`soak_depth`). |
| Where it runs | On the main thread, in `NativeChunkEditor._process` (`_flow_process`). A step costs about 40 µs natively, so a worker round trip would cost more than it saves. |

### Rendering

`scripts/water_flow_view.gd`, a child of the garden view (`LiveWater`), draws with copies of the garden view's own pond and stream materials (`_water_material`, `_stream_material`), so the look is today's. The copies follow their sources' parameters (bound through the reflection's material sync), and carry what is live water's own: the planar view and the moving water's edge fade.

- Every 1/30 s (0.1 s on the mirror), when the water has stepped, the depth field becomes two meshes (`ZenScapeWaterFlow::surface` with `under`, about 0.1–0.2 ms natively):
  - **Still water** (`FlowStill`) goes through the pond material, and covers **all** the wet quads, moving ones too (calm quads first; `calm` counts their indices, and only those are still water for life's survey). Depth is in UV2 for the shallows and shore foam. The depth palette (`79ae9b` to `245a5c`, as `GardenView.sample_ponds`) is in COLOR. Shore fetch in eight directions is in CUSTOM0/1 for the lake chop, in half-metre steps up to 9 m as `pond_fetch`. UV is zero, so it stands full: the water rises by itself.
  - **Moving water** (`FlowMoving`) lies over it through the stream material (`render_priority` 1, so it always draws after). Water faster than `flow_on` (0.22 m/s, with hysteresis down to `flow_off`) is drawn here. UV runs along and across the local flow, so the stream shader's streaks and wave run downstream. Foam (`0.65, 0.80, 0.79`) is blended into COLOR from `foam_from` to `foam_to` m/s. CUSTOM0.w is −1 so the stream shader's growth and front never hide it. CUSTOM1.x is how fast the vertex runs, 0 at `flow_off` to 1 at `flow_on` (a bank corner takes its fastest wet neighbour's), and the shader's `flow_edge_fade` multiplies the stream's alpha by it. So where a stream slows into a pond its streaks fade out over the pond's own surface, instead of two colour ramps meeting at a hard line. A library older than `under` (no `calm` in its output) turns the fade off and draws the two apart, as before.
- **Reflections** (`scripts/live_water_reflection.gd`, `LiveReflection`, which extends `scripts/planar_water.gd` for its geometry copying and material sync). One planar view for all live water:
  - It is set up (over a few frames, as the planned views are) when standing water of at least `MIN_AREA` (1.5 m²) appears in the pools the editor reads each second, and dropped when none is left.
  - It follows the largest pool's level: a move of more than `LEVEL_STEP` (1 cm) moves the mirror camera and sets the clip level on the copies' materials. That costs no setup, so a filling pond keeps its reflection all the way up. The followed pool is kept unless another is `SWITCH_SHARE` (1.6×) larger.
  - Still water further than `BAND` (0.3 m) from the view's level fades to the ordinary surface (shader `planar_band`, `planar_level`), so a second pond at another height, or water on a slope, does not take a displaced reflection.
  - With the view, the pond shader's planar path does what the planned ponds get: the reflected land and sky, the bed seen through the shallows with caustics, and the shore foam line from the true per-pixel depth.
  - Plant, prop and stream changes are copied over a few frames while the old copies keep showing (`_refresh_geometry_live`), as for the planned views. The live water's own meshes are not copied (`skip_reflection`), and neither are other reflections' views (`planar_water.gd` skips SubViewports with their own world).
  - `--no-live-reflection` turns it off, for A/B and profiling. It needs the Forward+ renderer, like the planned views.
  - One vertex stands per cell centre, and a quad is drawn when any corner is wet (over `wet`, 1.2 cm). A dry corner of a drawn quad takes its wet neighbours' mean surface, or sits 2 cm under its own ground where that is lower, so the sheet runs into the bank and the terrain draws the shoreline. Quads split along the flatter diagonal.
- **The brink.** An edge cell water is leaving over (more than `edge_on`, 0.0005 m³/s) is drawn wet at its brink depth, with its vertex moved out to the rim, so a stream runs right to the lip instead of dipping under the ground a quarter metre short of it.
- **Falls** (`scripts/flow_falls.gd`, `FlowFalls` on the scene). Traced from the flow and sized by its flux; see "Waterfalls" below.
- **Edge falls** (`scripts/edge_falls.gd`, `EdgeFalls` on the scene). Where water leaves the plate; see "Edge falls" below.

## Tunables

In `scripts/water_flow.gd` (`PARAMS` and constants) unless noted. The native defaults in `water_flow.h` match, and `PARAMS` is always sent.

| Constant | Value | Meaning |
|---|---|---|
| `CELL`, `FALLBACK_CELL` | 0.25 m, 0.5 m | Grid cell, native and mirror. |
| `DT`, `FALLBACK_DT` | 1/60 s, 1/30 s | Fixed step. |
| `MAX_TICKS` | 4 | Most steps one frame runs. |
| `gravity` | 9.81 m/s² | |
| `friction` | 0.6 /s | Damps still water's sloshing. |
| `drag` | 0.06 m/s | Bed friction that grows as water thins (λ = friction + drag/depth). |
| `evaporation` | 0.0004 m/s | Lost from every wet cell. |
| `soak`, `soak_depth` | 0.004 m/s, 0.03 m | Extra loss from thin water, fading to nothing at `soak_depth`. |
| `max_speed` | 4 m/s | Velocity cap (for the velocity field, not the fluxes). |
| `edge_smooth` | 0.5 s | Time constant of each edge cell's outflow rate. |
| `SPRING_RISE`, `SPRING_SLOPE`, `LOW_SHARE` | 1.2 m, 0.45, 0.2 | A ball is a spring this far above the plate's `LOW_SHARE` height quantile, or on ground this steep. |
| `SPRING_SHARE`, `SPRING_MIN`, `SPRING_MAX` | 0.012 /s, 0.03, 0.25 m³/s | Spring rate as a share of the ball's volume each second. |
| `SPRING_RADIUS`, `MAX_SPRINGS` | 0.35 m, 8 | A spring's footprint; the oldest goes when a ninth comes. |
| `BURST_SECONDS`, `BURST_RADIUS` | 1.2 s, 0.8 m | How a burst ball's water leaves it. |
| `SPRING_HEAD_SECONDS`, `SPRING_SET`, `SPRING_BACK` | 10 s, 1 m, 0.03 m | How a spring ball's own water leaves it; how far down its course the spring rises at most, and how far the ground `SPRING_RADIUS` behind it must stand over it (`spring_set`). |
| `COURSE_STEP`, `COURSE_FLAT`, `COURSE_FLAT_STEPS`, `COURSE_RIM` | 0.5 m, 0.08, 2, 2 m | A spring's course (`descent`) and where its foot is. |
| `RILL_DEPTH`, `RILL_HALF_WIDTH`, `POOL_RIM`, `POOL_HOLLOW` | 0.3 m, 1 m, 1.5 m, 0.25 m | A spring's bed (`spring_bed`): the rill, the pool's distance from the rim, and how deep a hollow at the foot already holds the water. The pool's size is the water brush's hollow (`WaterBrush._scoop_radius`, `SCOOP_DEPTH`). |
| `SPRING_BED_SECONDS` (`native_chunk_editor.gd`) | 1.2 s | How long the bed takes to wear in on screen. |
| `THIN` (`water_flow_view.gd`) | 1.2–5 cm | Moving water this thin fades from wet ground to the stream's look (shader `live_thin`). |
| `POOL_DEPTH`, `POOL_SPEED`, `POOL_CELLS` | 0.15 m, 0.12 m/s, 12 | What counts as standing water for life. |
| `WET_DEPTH` | 0.05 m | Water that stops emergence. |
| `SURFACE` (`water_flow_view.gd`) | wet 1.2 cm, lift 1.2 cm, flow on/off 0.22/0.12 m/s, foam 0.8–2.2 m/s, depth scale 0.45 m, under | Surface build. |
| `MIN_AREA`, `LEVEL_STEP`, `BAND`, `SWITCH_SHARE` (`live_water_reflection.gd`) | 1.5 m², 1 cm, 0.3 m, 1.6 | When the reflection view stands, how far the pond moves before it follows, how far from its level water still reflects, and when it changes pond. |
| `SURFACE_SECONDS`, `FALLBACK_SURFACE_SECONDS` (`water_flow_view.gd`) | 1/30 s, 0.1 s | Surface rebuild interval. |
| Waterfalls (`flow_falls.gd`) | see "Waterfalls" | Detection, easing, look. |
| `edge_on` (`SURFACE`, default in the kernel) | 0.0005 m³/s | An edge cell leaving more is drawn to the lip at its brink depth. |
| Edge falls (`edge_falls.gd`) | see "Edge falls" | Spills, easing, course, look. |
| `FLOW_READ_SECONDS`, `FLOW_REPORT_SECONDS`, `FLOW_AREA_CHANGE` (`native_chunk_editor.gd`) | 1 s, 3 s, 2 m² | Reading and reporting pools. |
| `FLOW_FISH_SECONDS`, `FLOW_FISH_REACH` (`native_chunk_editor.gd`) | 90 s, 12 m | A ball's fish waiting for a pond. |

## Code

- `native/terrain_kernels/water_flow.h`: `ZenScapeWaterFlow`, registered by `kernels.cpp`. It holds `configure`, `set_params`, `step` (resample the ground, then run the ticks with the sources), `add_water`, `drain`, `get_depth`/`set_depth`, `get_ground`, `get_velocity`, `wet_cells`, `stats`, `surface`, `pools`, `falls` (the old point search, unused by the view), `cascades` (the waterfalls), `edge_outflow` and `spills` (the edge falls). Rebuild the library after changing it (`native/terrain_kernels/README.md`).
- `scripts/water_flow_reference.gd`: the GDScript mirror, with the same methods and arithmetic. Keep the two in step.
- `scripts/water_flow.gd`: the owner. It holds the grid and cell map, the fixed clock, springs and bursts, `drop`/`drain`, and undo, save and load.
  - It takes the mirror when the library is missing, when it lacks the newest method (`spills`, so a stale build falls back instead of failing), or under `--gdscript-kernels`.
  - `native` says which one runs, and the probes check it.
- `scripts/water_flow_view.gd`: the surface meshes; it stands the falls.
- `scripts/flow_falls.gd` and `shaders/flow_fall.gdshader`: the waterfalls.
- `scripts/edge_falls.gd` (and the same shader's `break_from`/`break_length`): the edge falls. `scripts/native_chunk_editor.gd` `skirt_mesh_for`, `_rim_slices`, `_sliced_soup`: the earth sides refitted to a notched rim.
- `scripts/live_water_reflection.gd`: the live ponds' planar view.
- `shaders/reference_water_body.gdshaderinc`: `planar_band`/`planar_level` (the reflection's fade by level) and `flow_edge_fade` (moving water's fade over still water). Both are off by default, so planned water draws as before.
- `scripts/native_chunk_editor.gd` "Live water": setup (`flow_wanted`, `_setup_flow`), `_flow_process`, pool reports, `_flow_landed`, `ball_from_sky`, `still_water_triangles`. `_ball_landed` hands over to the flow when it is on. `_ball_step` fills a ball at the water brush's own size and flow whatever brush is in hand.
- `scripts/hand_reach.gd` `_void_drag`: the sky's door.
- `scripts/native_terrain_data.gd` `load_document`: accepts the optional `water_flow` field (`WaterFlow.decode`).
- `scripts/emergence.gd` `flow_wet`, and `scripts/land_life.gd` (the survey reads `still_water_triangles`).

## Measured

Headless, on the Mac, with other agents' Godot runs sharing the CPU.

| | Native (0.25 m, 12,544 cells) | GDScript mirror (0.5 m, 3,136 cells) |
|---|---|---|
| One step (median, p95) | 43 µs, 47 µs | 1,567 µs, 1,612 µs |
| Per second of water | 60 steps: about 2.6 ms | 30 steps: about 47 ms |
| Surface build | 0.1–0.2 ms | about 4 ms |
| Cell map (once, on a worker) | 12 ms | 7 ms |

In the product scene (`probe_water_flow_modeless.gd`, dummy renderer), with a spring running into a full pond, the frame's water work was about 0.2 ms: a 40 µs step, a 124 µs surface build and a 14 µs mesh publish. CPU frame gaps over 300 frames were 12.5 ms at most, with a mean of 1.9 ms. Mesh upload on a real GPU is not measured.

### Probe: peak, groove, basin

`tools/probe_water_flow.gd -- --plain-seed 7` shapes the cozy plain directly. It raises a 4 m peak at (−6, −1) over 6 m, and cuts a groove 0.9 m deep and 2.5 m wide from high on the peak's flank (−4.6, −1) down to a palm-pressed basin at (3, −1), 1.2 m deep over 3 m. A 6 m³ ball dropped at the groove's head is a spring (0.072 m³/s):

| Time | In the basin | In the groove | Anywhere else | Basin surface |
|---|---|---|---|---|
| 5 s | 3.05 m³ | 1.44 m³ | 0 | −0.64 m |
| 15 s | 4.93 m³ | 0.19 m³ | 0 | −0.34 m |
| 30 s | 5.53 m³ | 0.18 m³ | 0 | −0.29 m |
| 60 s | 6.73 m³ of 6.91 | 0.18 m³ | 0 | −0.21 m |

The rest of the probe:

- **Trench under the pond.** With the spring stopped, a trench cut from the full basin to a second, lower basin moves the water: the first basin goes from 6.80 to 2.53 m³ (its surface from −0.21 to −0.59 m), and the second takes 3.63 m³ within 30 s.
- **Burst.** A 4 m³ ball on flat low ground is a burst, not a spring. It spreads, and it has soaked in after a minute.
- **Steady spring.** Five minutes of the spring: 7.8, 10.0, 11.9, 12.5 and 12.6 m³ at the end of each minute, about 49 m² wet, nothing over the edge.
- **Save, load, undo.** Save and load bring back the spring and every litre. A drain takes the spring. Undo takes a second spring back, and redo returns it.
- **Mirror.** The GDScript mirror at 0.5 m gives the same picture: 6.44 of 6.64 m³ in the basin at 60 s, and 12.1 m³ steady.

`tools/probe_water_flow_modeless.gd -- --modeless` (with `--fixed-fps 60`) runs the whole path in the product scene:

- The live water is set up on the native kernel.
- A press in the sky dragged onto the groove's head becomes a held ball, and the hand cups it. Let go, it falls and becomes a spring, and no one-shot plan runs.
- After two minutes 11.6 of 11.9 m³ stands in the basin. The view draws it, life's survey sees it, `water_settled` reports its rect, and emergence's wet mask covers it.
- A real thumb groove (`land_clay.gd`, 0.28 m deep) cut from the pond outward takes 0.66 m³ from it within 10 s.
- One undo takes the groove back, and the next takes the spring back.
- `--planned-water` leaves the live water off.

## Look pass (2026-09-29)

The user filmed the first version and liked it, but the live ponds read flat, dull dark grey beside the planned ones.

**Why they were dull.** A planned pond drawn by a planar view goes through the pond shader's planar path. That path does more than reflect: it raises the Fresnel term (0.16 + 0.72(1 − cos)³ against the lake's 0.02–0.72 × 0.72), reads the bed through the water from the screen texture with absorption and caustics, and draws the shore foam from the true per-pixel depth. Live ponds had no view, so they took the plain path. That is a nearly opaque body colour lit by the lake lighting, with only the sky gradient reflected at grazing angles. Seen from above in a deep basin, this reads as a flat grey-teal disc. The mesh data was not the cause: depth (UV2), palette (COLOR) and fetch (CUSTOM0/1) match `GardenView.sample_ponds`, apart from the palette being mixed in linear rather than sRGB (slightly lighter mid-depths).

**What changed:** the reflection view above; still water under moving water with the edge fade; and the film. The film now uses the water-ball film's mood (Alpine daylight) with fog 0.04 and haze 0.06 held, the overlays hidden, and the camera closing on the groove (18 m) and then on the pond (13 m). It cuts the second groove only once the pond stands up to the groove's start, from inside the pond outwards. It saves `pond_live.png`; with `--planned-water` it stops on `pond_planned.png` from the same camera instead.

**Measured** (rendered film, M-series Mac, 1280×720 window):
- The reflection's CPU cost is about 0.33–0.35 ms a frame while shown (`last_sync_usec`). Most of it is the per-frame walk of the copies and the material sync, the same work `planar_water.gd` does per planned view. Level moves are included.
- The GPU cost is one extra scene render at the reflection width (512 × aspect on the default quality), the same as one planned pond's view. It is not measured separately (the Mac's GPU timers do not report). Nothing is added while no live pond stands.
- Surface build and publish are unchanged in order (still under 0.3 ms). The still mesh now also carries the moving quads.

**What the frames show:**
- The live pond now reads like the planned one from the same camera: the bed shows through, darkening with depth, and the far wall reflects along the far shore.
- A thin foam line runs round the shore.
- The inflow's streaks fade into the pond without a line.
- The second groove takes about 2 m³ within 8 s of film.
- At a low grazing camera the pond turns pale grey. It then mostly reflects the hazy sky, and the haze also lies over the land.
- Both the planned and the live ponds in a palm-pressed basin sit in a steep pit, so the water is seen against its dark walls.
- **Fixed since (2026-09-29, waterfalls pass): thin sheets read milky white.** Water only a few centimetres deep, such as an overflow spreading on flat ground, lay wholly inside the shore-foam band (`zs_look_shore`, depth under about 3.5 cm), so the whole sheet took foam. Now the still surface carries each cell's distance from dry ground (a chamfer distance, 0 on the bank corners) in UV.x (UV2.y is taken: it is `cut_face`), and with `shore_distance` on (live still water only) the lap band fades out from 0.2 to 0.55 m from the bank. A thin sheet keeps a foam edge and shows water inside it.
- **Still off: water in a deep, narrow trench reads as grey haze.** It takes the sky's grey at the planar Fresnel.
- **Each take differs.** The palm's basin depth varies with the synthesized strokes: −1.5 m in one take and −0.55 m in the next, where the pond spilled onto the plain.

## Waterfalls (2026-09-29)

The user: "The waterfall is very lacking. We're almost gonna have to detect if there's a bunch of vertical flow, and then turn that part with the vertical drop-off into a waterfall. It might have to be more of a prop. It's got to have the foam coming out, the mist, and it's got to fill the actual waterfall. It looks a little dainty." And: the Electron falls "were kind of one-dimensional, but they look great. We could take something like that and improve upon it."

The first version stood the stock authored fall (a fixed ring shape, plunge and spray) wherever moving water dropped steeply, whatever the flow. Now each fall is traced from the flow and drawn by it.

### What the Electron fall does

`~/Documents/Projects/zenscape/waterfall.js` `buildStrand` and `buildWater`:
- A **strand** is a swept 12-sided tube flattened into a sheet (thickness at most 0.55 of the half width), traced down the rock from a notch to the pool, with rings bunched where it drops (`resample`, 85 % weight on descent). The frame is parallel-transported so it stays plumb over a cliff.
- **Aeration** is an integrator over travel time (`tau`, distance / (1 + 3·steep)): `a = min(1, a·0.5^dt + steep·dt·1.15)`. Glass at the lip, white below. Colour is a seven-step ramp from `#2f7f9c` to `#f2f7f8`, one colour per facet, with fixed per-column whiteness (striations) and foam bands running down (`fract(tau·1.8 − t·1.6)`). Fresnel sky only on the glass.
- **Width** necks under the lip and spreads as it breaks up (`(1 − 0.16·steep)(1 + 0.5·aer)`, change per ring 0.94–1.18), capped by the channel. **Thickness** `(0.06 + 0.45·steep)(0.5 + 0.4·flow)`. The inlet pinches to a slit, ring 0 sinks under the lip, and every ring stands off the rock by its thickness.
- **Foam**: 4 + 3·flow flat-shaded icosahedra round the impact, bobbing; small clusters at ledges.
- **Mist**: 40·flow + 5 per emitter point sprites (impact weight 3, aerated rings), rising (0.9 + 0.6·flow) with an ease-out, drifting with the wind, alpha 0.3.
- It is opaque, casts and takes shadows, and has a dim emissive so it does not go black in a notch.

What was taken: all of the strand (the ring shader `reference_fall.gdshader` was already its port), the foam clusters and the mist recipe. What is new: every input comes from the sim and is eased; the flow's strength tears or fills the sheet; a white break at the lip; fast streaks; froth painted into the water; glow for aerated water.

### Detection

`ZenScapeWaterFlow::cascades` (mirror `water_flow_reference.gd`), read by `scripts/flow_falls.gd` every `READ_SECONDS` (0.25 s) with `DETECT`:
- A wet cell (deeper than `wet`, 4 mm; 1 cm before the close-up pass) running faster than `min_speed` (0.3 m/s) is **steep** when its surface falls `slope_on` (0.8, 39°; was 1.0) or more per metre over `run` (0.5 m) down its own flow. It stays steep until that slope is under `slope_off` (0.55; was 0.7): per-cell hysteresis.
- Steep cells group 8-connected. A group of `min_cells` (3) or more is a **fall** when its lip stands `min_drop` (0.7 m) or more over its plunge and it carries `min_flux` (0.006 m³/s).
- **Flux** is the larger of what the pipes carry into the group from outside and what they carry out (m³/s, from the sim's own fluxes).
- **Lip**: the depth-weighted mean of the group's cells within `lip_band` (0.3 m) of its top, and their mean flow direction. Its width is the larger of the lip cells' spread across that direction and the wet channel walked across from the lip's middle.
- **Plunge**: the flux-weighted mean of the cells the group pours into, with the water's depth there (a pool gets ripple rings).
- **Course**: the group's cells binned by height every `band` (0.3 m); each bin's centroid, and its half width across the course from the bin's second moments (√3·σ).
- At most `max` (6), the largest flux first. It costs about 50 µs on the 112 × 112 grid.

### Easing (`flow_falls.gd`)

- Each answer is matched to the falls already known by lip or plunge within `MATCH` (1.5 m).
- A fall stands once found for `HOLD` (0.75 s), grows in over `GROW` (1.2 s), and once missing for `GRACE` (0.5 s) fades over `FADE` (2 s) and goes. At most `MAX_SHOWN` (4).
- Its course (resampled to `RINGS`, 14, by descent, then smoothed three passes so band centroids do not zigzag), flux, drop and pool depth ease with a time constant `SMOOTH` (0.6 s).
- Strength is √(flux / `FULL_FLUX`), `FULL_FLUX` 0.2 m³/s (the largest spring pours 0.25), at least 0.15.

### The prop

- **Curtain** (`shaders/flow_fall.gdshader`, one draw, casts a shadow). The source strand's rings, rebuilt every frame from the eased course (aeration at the source's rate × (1 + strength), so a strong spring breaks white over a few metres of face as the source's long falls do): width from the channel (never less than 0.8 of the lip's), necking then spreading; thickness `(0.06 + 0.45·steep)(0.3 + 0.7·strength)`; grown in with presence. `veil` = 1 − smoothstep(0.15, 0.85, strength·presence) tears a trickle into falling strands with gaps (discard, so it stays opaque and depth-writing); `streak_speed` 0.6·√(2g·drop), 2.5–7 m/s; a white break over the first `crest` (0.3 m) of travel; aerated water glows a little (`0.08 + 0.4·aer`).
- **Plunge**: 7 foam blobs (4 + 3·strength shown, emissive so they do not go black in shadow), a GPU droplet burst (48, `amount_ratio` by strength), four ripple rings when the plunge's water is deeper than about 5 cm, and froth in the water itself: `fall_foam` points (plunge and lip) on the live still and moving materials, a churning core with patches drifting outward (`reference_water_body.gdshaderinc`).
- **Mist**: the source recipe (impact and the lower half's aerated rings), up to `MIST` (48) sprites through `studies/fall_mist.gd`, with `mist_strength` and `mist_scale` added to its shader: strength `presence·(0.3 + 0.4·strength)`, scale `(0.35 + 0.3·strength)·clamp(0.6 + 0.2·drop)`, rise `(0.9 + 0.6·strength)·clamp(0.5 + 0.25·drop)`. The shader drifts it with the scene's wind (`zs_wind_direction`, `zs_wind_at`).
- `--no-live-falls` leaves the falls out, for A/B and profiling.

### Measured and seen

`tools/film_hand_world.gd` (rendered, 1280×720, M-series Mac; it now ends closing on the tallest fall and saves `fall_close.png`, and `--falls-only` skips the tour):
- Two falls stand, found within a second of the springs and steady for the rest of the take (same ids, lip still to a centimetre): the tall peak's, 0.16–0.26 m³/s over 2.7–3.0 m, 0.63 m wide; the far peak's, 0.11 m³/s over 1.4–1.6 m, 1.0 m wide.
- CPU: the read is about 50 µs (native) every 0.25 s; the per-frame update (easing, rings, uniforms, blobs, mist placement) about 0.1 ms for both falls, 0.2 ms during camera moves. A fall's first frame costs 11–16 ms once (its nodes and materials are made); that hitch is a follow-up (pool the nodes).
- Per fall: 4 draws (curtain, foam blobs, droplet burst, ripple rings) plus the curtain's shadow pass and one mist canvas draw of up to 48 sprites; 48 droplet particles. The froth in the water adds no draw. The GPU cost is not measured (the Mac's GPU timers do not report).
- `tools/probe_water_flow_modeless.gd` still passes; its groove (0.28 m deep, on a gentler flank) now stands no fall, where the old point search stood one or two.

What the frames show: from the overview both falls read as white-blue ribbons with foam at their feet; close, the curtain fills the channel, whitens down the drop, and froths where it lands. Still off: the curtain is smoother and bluer than the source's (which is in full sun and many metres tall), and still reads a little like a tube close up; the lip is a narrow point rather than a broad crest; the mist is faint; ripple rings only show in standing water, and neither film's falls land in a pool.

### Close-up pass (2026-09-29)

The user, close to a fall: "The waterfall looks a bit strange up close. And it doesn't attach as high as I'd like on the mountain." What drew each piece, and why:

| Seen | Drawn by | Why |
|---|---|---|
| An opaque, flat-white, faceted sheet with blocky folds | the curtain, `shaders/flow_fall.gdshader` | Opaque (the source's choice), flat-shaded from screen derivatives, and the aerated chop (±11 % and ±8 % of the ring) folded a few-metre sheet into crumples. White because it aerates within a metre or two. |
| A hard jagged lip in mid-air | the curtain's last ring (`flow_falls.gd` `_rings`) | The course ended at the steep cells' end, at full thickness, an open tube standing off the face where the water ran on down a gentler slope. |
| A second translucent veil beside it | the live moving water, `FlowMoving` (`reference_water_body.gdshaderinc`, stream path, alpha 0.4–1) | The water on the face the curtain does not cover, and under it, drawn pale and glassy with the sky's Fresnel. |
| Hair-thin aliased lines on the sides, fanning out at the plunge | the moving water's streak and foam waves | Its UV is each vertex's position along its *own* flow direction (`ZenScapeWaterFlow::surface`), so where the flow turns or fans out, UV jumps metres across one facet and the waves alias into hairs. (The curtain's torn streaks, `across × 22/47` round the tube, added more.) |
| Big faceted white balls | the foam blobs, `flow_falls.gd` (the source's foamCluster: flat-shaded 6-sided spheres) | Sized for the source's many-metre falls; beside a 3 m fall seen close they read as snowballs. |
| Small grey beads | the spray, `flow_falls.gd` (GPU particles, opaque StandardMaterial spheres) | |

**Why it hung low.** Measured with `tools/probe_fall_attach.gd` (headless; a 6 m pinch horn, a ball dropped on its summit):
- The spring was set a flat `SPRING_SET` (1 m) down the steepest descent. On a horn's steep top that is 2.2 m down: the water started at 3.57 m under a 5.78 m summit.
- The detector only took water 1 cm deep. Near a spring the water runs at the 4 m/s cap only 2–6 mm deep, so the top of the fall was dry to it.
- The curtain's inlet opened over 2.5 rings (thickness) and 1.6 rings (width), so its visible top hung about 0.5 m under its lip.
- On rounder mountains the 45° threshold (`slope_on` 1.0) left the upper flank as a stream.

**What changed:**
- `water_flow.gd`: the spring moves down only until its footprint lies on one flank (`spring_set`: the ground `SPRING_RADIUS` behind it stands `SPRING_BACK` over it), at most `SPRING_SET`. The rill starts at the spring and does not cut ground above it, so the summit is no longer worn down.
- `flow_falls.gd`: `DETECT` `wet` 0.004, `slope_on` 0.8, `slope_off` 0.55. The inlet opens within one ring. Over running water (no pool) the last rings thin to 35 % and the shader fades the last `END_FADE` (0.35 m) out; into a pool the last ring goes 0.2 m under and the pool's surface draws over it. The foam blobs are soft billboard puffs that rise, swell and fade (`PUFF_SECONDS` 1.6 s); the spray is the water ball's lens beads (2.2 cm). `CURTAIN_PRIORITY` −1 (before the live water), `SPRAY_PRIORITY` 2.
- `flow_fall.gdshader`: glass is translucent (alpha 0.42–0.62 with more at grazing angles), aerated water and the white break opaque; only the half of the tube facing the eye draws (`sheet_normal`), so it never shows its own back wall; facets shade half way to the smooth sheet normal; the chop is about half; tears and streaks are antialiased coverage, and every noise fades to its mean where it is finer than a pixel (`fall_detail`, as the rainbow). `depth_draw_always`.
- `reference_water_body.gdshaderinc`: the moving water's streak and foam waves fade to their mean where finer than a pixel; live moving water deeper than about 3 cm on a face steeper than about 37–63° takes white-water foam and opacity (`cascade`), so it agrees with the fall beside it.
- `edge_falls.gd`: the same curtain priority, and lens beads (3 cm) for its droplets.

**Measured** (`tools/probe_fall_attach.gd -- --no-title`, steady state at 25 s; heights in metres):

| Mountain | Summit | Spring before → after | Curtain's visible top before → after |
|---|---|---|---|
| 6 m horn | 5.8–5.9 | 3.57 → 5.11 | 3.37 → 4.60 |
| 3.5 m horn | 3.3–3.5 | 1.66 → 2.80 | no fall → 2.91 |
| 4 m dome | 3.9–4.0 | 3.50 → 3.91 | 2.36 → 3.33 |
| 3 m mesa, ball 2.4 m from the middle | 3.25 | 2.08 → 2.99 | 2.24 → 2.90 |

**Unverified:** none of the look has been rendered. The shader edits need a windowed compile check (Metal's varying limit: the curtain now has 12 custom varying floats) and a rendered look close and far; transparent sorting against other transparent things behind the fall, and whether the translucent curtain still casts its shadow, are unseen. Lower detection thresholds may stand falls on steep streams that had none (`probe_water_flow_modeless.gd`'s groove).

## Edge falls (2026-09-29)

Branch `feature/edge-falls`. The user: "It would be awesome if you could thumb your way to the edge so the water could actually flow and actually spill over the edge of the chunk like a waterfall — a waterfall for the chunk itself, into the void."

Before, water reaching the plate's edge ring silently vanished, and the thumb's groove faded to nothing over the plate's last metres, so no channel could reach the rim. Now a thumb stroke heading out through the rim notches it into a spillway (`docs/scenic/modeless.md`, "The thumb at the rim"), the sim counts what leaves over each edge cell, and each run of edge cells water leaves over stands a fall down the block's side and on into the void.

### Spills

`ZenScapeWaterFlow::spills` (mirror `water_flow_reference.gd`), read by `scripts/edge_falls.gd` every `READ_SECONDS` (0.25 s) with `DETECT`:
- Along each side, edge cells leaving more than `cell_min` (0.0004 m³/s, smoothed) form runs, bridging gaps of up to `gap` (1) cell. A run carrying `min_flux` (0.003 m³/s) is a spill; at most `max` (8), the largest first.
- Each spill has its side and outward normal, its flux, a **lip** on the rim (the flux-weighted middle of the run, at the water surface in the cells inward of it), the ground there (`floor`), a half width from the flux's spread (√3·σ + half a cell, at most half the run), the brink depth, and the speed out of the plate in the cells inward.
- `edge_outflow()` gives the raw per-cell rates by side, for probes.
- It costs about 15 µs.

### Easing

As the waterfalls': a spill matches the standing fall on the same side within `MATCH` (1.5 m) along it; it stands after `HOLD` (0.75 s), grows in over `GROW` (1.2 s), and once missing for `GRACE` (0.5 s) fades over `FADE` (2 s). Its lip, width, flux, speed and brink ease with `SMOOTH` (0.6 s). At most `MAX_SHOWN` (4). Strength is √(flux / `FULL_FLUX`), `FULL_FLUX` 0.2 m³/s, at least 0.15, so a trickle is a torn veil and a full spring a curtain (`veil`, as the waterfalls).

### The prop

- **Curtain.** The waterfalls' strand (`shaders/flow_fall.gdshader`) on 24 rings: 4 over the bend at the lip, 12 down the face, 8 falling free. Ring 0 sinks 0.12 m under the brink, so the water comes out of the notch.
- **Hugging the side.** Down the face each ring stands `GAP` (0.05 m) plus its own thickness off the earth side. The side is read from the earth sides' mesh along rays, three across the fall's width every `PROFILE_STEP` (0.2 m) down (`_profile`, redone only when the sides' mesh or the lip moves). Off the lip the water also takes `CLING` (0.25) plus `CLING_FLOW` (0.35) × strength of its ballistic throw at the brink's speed, so a trickle clings and a strong spring leans out.
- **Aeration and width.** Aeration integrates as the source's does (at its rate × (1 + strength)), so the sheet whitens down the face. Width is the spill's, necked at the lip and spreading 25 % with aeration and a further 70 % as it falls free. Thickness is (0.035 + 0.1·strength), growing in over the first rings and by 60 % falling free.
- **Into the void.** Past the block's bottom (the lowest facet the rays hit, or `BOTTOM`, −4.8 m) it falls `TAIL` (2.6 m) plus `TAIL_FLOW` (2 m) × strength more. The shader's `break_from`/`break_length` tear it over that stretch: first into strands, then beads, then nothing. It whitens as it breaks.
- **Droplets and mist, no plunge.** A GPU bead burst (40, `amount_ratio` by strength) falls from where it breaks up. Up to 48 mist sprites (`studies/fall_mist.gd`) trail below from the free fall, sinking rather than rising (`rise_height` −(0.8 + 1.4·strength)) and drifting with the wind. There is no plunge foam and no ripple rings: nothing is there to land on.
- **The turn and the flip.** It is drawn in the terrain's frame, so it turns with the world. It is **hidden during the diorama flip**: `diorama_flip.gd` leaves `edge_falls.gd` out of its snapshot, and the falls hide while `flip.active()`. When the world lands they fade back in if water still leaves the plate.
- `--no-edge-falls` leaves them out, for A/B and profiling.

### The rim notch and the earth sides

The earth sides' facets are about 3.5 m along the rim, but the rim's own points are about 0.64 m apart. A notch refitted with the old per-vertex shift would be bridged by one facet, which would stand over the cut or drop away from the land on either side. `skirt_mesh_for` now slices the sides first. Where the rim's change bends more than `SKIRT_BEND` (0.1 m) away from the straight line the facet over it follows, every facet is cut by planes across the side at each rim point and midway between. Every facet takes the same planes, so the sides stay closed. The slices are then shifted as before: the top by the rim's change, less toward the base. The notch therefore runs a shallow chute down the face, fading out toward the bottom. The sliced soup is cached until the planes change. A generated world's gently moved rim keeps its facets.

### Measured

`tools/probe_edge_fall.gd -- --modeless` (headless, `--fixed-fps 60`, dummy renderer). A 4 m peak written at (8, −3); a real thumb stroke through `hand_reach` from (9.4, −3) toward (13, −3), let go short of the rim; an 8 m³ ball dropped at the groove's head:
- The groove is carried to the lip and notches the rim 0.9–1.0 m deep over three rim points (z −3.2 to −1.9; the screen-straight stroke lands a little off z −3). The rim either side is unchanged (under 2 cm at the notch's shoulder, 0.000 m further out), and so is the rim beside a thumb run along the edge at x 12.6.
- The earth sides' top meets the notched rim within 1 mm. They go from 392 to about 1,750 triangles. Refitting them costs about 3.6 ms per light refresh while the rim is notched, against 1.2 ms for the old per-vertex shift; a generated world's rim alone slices nothing.
- The spring's 0.096 m³/s levels off at 0.35–0.46 m³ standing (it varies take to take). 0.088 m³/s leaves over four edge cells; soak and evaporation take the rest. `poured` = standing + `drained` + `soaked` + `removed` to the litre.
- The channel is wet to the cell beside the edge, and the stream is drawn to x = 14.0.
- One spill and one edge fall stand: a 3.7–4.3 m face and 7.6–8.2 m in all. The spring taken away, it fades out.
- Cost: the step is 38–60 µs as before, the spills read about 15 µs every 0.25 s, and the edge falls' frame update about 0.05 ms steady. A fall's first frame costs 0.5–16 ms once (its nodes, materials and the side profile), as the waterfalls' does.
- Draws per edge fall: the curtain (plus its shadow pass), the bead burst, and one mist canvas draw of up to 48 sprites.

### Filmed

`tools/film_edge_fall.gd` (rendered, 1280×720, M-series Mac):
- **Gestures.** A 3–3.7 m peak pinched at (8, −3) and a thumb groove from its flank toward (13.1, −3). The groove is carried to the lip and notches it about 0.9 m deep. A spring from the sky at the groove's head gives 0.115 m³/s.
- **Time lapse.** The water runs ×6. One edge fall stands within the first read: 0.95 m wide, a 4.3 m face and 8.4 m in all. Steady, 0.48 m³ stands on the plate and 0.115 m³/s leaves over the edge.
- **The camera.** It comes down to a low three-quarter side view, saves `edge_fall.png`, and orbits 1.5 rad over 16 s. The clip is `edge_fall.mp4`.
- **Cost.** The edge falls' frame update is about 0.05 ms and the read about 14 µs. The first frame of a fall is 7–16 ms once (nodes, materials, side profile).

What the frames show:
- The notch reads as a clean V-shaped spillway in the rim with a chute down the face. The fall comes out of it as a pale blue sheet that whitens down the face, clinging just off the side.
- Past the block's bottom it tears into strands and then beads. Droplets and faint mist trail below and are gone a few metres down.
- Still off:
  - The sheet is smooth and bright, and reads a little like a ribbon close up.
  - Its own shadow darkens the chute beside it.
  - Seen head-on, the peak's own groove waterfall (`flow_falls.gd`) plunges just inside the lip, and its foam blobs sit on the brink like a white cap.
  - The mist is faint.
  - The God Hand stays in shot: the film's hide does not hold.
  - The flip is not filmed: the falls hide while it runs, and that was only reasoned, not seen.

## Drop legibility (2026-09-29)

A rendered playtest dropped an 8 m³ ball on the top of a pinched peak on an open plain. What a player saw: a pale, glassy sheet draped over the summit and down a flank, thin white rings on the plain, a small fall on the face, and no stream or pond.

**Why** (headless reproduction, `/private/tmp/zs-drop/probe_drop.gd`, the playtest's own gestures at `--fixed-fps 60`):
- **The whole ball burst on the summit.** A spring ball still let its water go as a burst, 7.3 m³ in 1.2 s over 0.8 m. That is about 6 m³/s at the apex, so it ran down every flank at once. The waterfall detector read a 19 m³/s cascade and stood a curtain 5.5 m wide over the dome.
- **Then it spread thin over the flat.** Within 3 s, 7.2 m³ was on the plain. By 6 s it covered 106 m², mostly 1–10 cm deep, with nothing to pool in. At 30 s 5.3 m³ had soaked in and 1.4 m³ had gone over the edge; 3.3 m³ was left.
- **Thin water drew as glass.** A sheet 1–3 cm deep on a steep face was drawn twice: once through the stream material and once through the pond material under it. The stream material shows at least 40 % alpha, takes the sky's Fresnel sheen at the face's grazing angle, and takes speed foam in its vertex colour. The pond material shows the lake's Fresnel on a surface that is not level. At 16 s, 47 m² of moving water was drawn, half of it under 3 cm deep.
- **The rings.** Once a pool stood anywhere, the live reflection's planar path drew the plain's 3–10 cm sheet with the bed showing through: an almost invisible interior, and only the shore foam band round its edge.

**What changed:**
- **A spring ball no longer bursts.** Its water wells out of the spring over `SPRING_HEAD_SECONDS`, about 0.75 m³/s for an 8 m³ ball, then the spring keeps its steady rate.
- **The spring rises `SPRING_SET` down the steepest descent** from the landing point (`WaterFlow.descent`), so a summit's water takes one flank.
- **The spring's bed** (`WaterFlow.spring_bed`). The course runs to its foot, where two 0.5 m steps in a row fall less than 8 %. There the water wears two things:
  - a pool sized to hold the ball, set half a radius past the foot and kept 1.5 m inside the rim. It was first the water brush's hollow (radius 1.4 + 0.9√V, depth 3V/πr² + 0.05 m); it is now a floored pond (see "The foot pool read as grass" below);
  - a rill 0.3 m deep and 1 m to either side, down the course from the spring to the pool.
  
  A foot already in a hollow 0.25 m deep, such as a palm-pressed basin, keeps its ground. So does a course that reaches the rim, such as a notched spillway. The bed is inside the spring's undo step: one undo takes the spring and the bed, and redo brings both back. `last_bed` hands the editor the ground before and after, and `_wear_spring_bed` eases it in over 1.2 s with light refreshes. A stroke that starts meanwhile, an undo or a new world stops it. `--no-spring-bed` keeps the old ground, for A/B.
- **Thin moving water reads as wet ground** (shader `live_thin`, from `THIN`). From 1.2 to 5 cm deep, moving water fades from a dark wet tint at 28 % alpha to the stream's look, and loses the sky sheen, speed foam and glint. Deeper water is unchanged.
- **Live still water on a slope fades out** (shader `live_level`, smoothstep 0.82–0.96 on the surface normal's y). On a face, only the moving water's own look shows. Level ponds are unchanged.
- The ball's fish wait for the bed's pool.

**Measured** (same probe, two takes each; the pinched peak is 8–9.7 m and varies take to take):

| | Before | After |
|---|---|---|
| Largest cascade the falls read | 19 m³/s, 5.5 m wide (2 s) | 1.0–1.4 m³/s, 1.3–1.6 m wide during the head, then 0.1 m³/s, 0.9 m |
| Water in the pool (within 4.5 m of its centre) | none (the groove caught 6.8 m², depth 0.37 m) | 2.2–2.4 m³ at 4 s, 5.1–5.4 m³ at 8 s, 7.2–7.4 m³ at 12 s |
| Deepest water on the flat | 0.37–0.5 m (in the thumb groove) | 0.59–0.6 m in the pool; `pools()` reports 13–16 m² at 15 s |
| Moving water drawn at 20 s (under 3 cm) | 40–44 m² (24–27 m²) | 21 m² (6–8 m²) |
| Standing at 30 s, soaked, over the edge | 3.3 m³, 5.3, 1.4 | 6.2–7.1 m³, 2.0–2.3, 1.0–1.6 (the full pool overflowing) |

Once full, the pool overflows with the spring's steady 0.09 m³/s and runs on as before.

`tools/probe_water_flow.gd` and `tools/probe_edge_fall.gd` still pass (run with `--no-title`, which the title screen now needs). The groove's head in each ends in a basin or at the rim, so neither wears a bed. `tools/probe_water_flow_modeless.gd` fails on main as well: its drag starts in the plain sky, and since the cloud change only a tuft from the cloud makes a ball.

**Unverified:** none of this has been rendered. The wet-ground tint, the fade of still water on slopes, the rill and pool's look, and the bed wearing in all need a rendered take. Still open:
- a burst on flat low ground still spreads into a thin sheet, and can still show the shore-foam ring;
- trees standing where the pool is cut stay, sunk to the new ground;
- the rill cuts into the user's peak; `--no-spring-bed` shows it without.

### The foot pool read as grass (2026-09-29, rendered playtest)

In the rendered take the stream was right, but the pool at its foot showed only as a thin pale curve on the grass.

**Why** (headless, the playtest's gestures; `pools()`, the surface arrays and the live materials read at 8–30 s):
- **The water was there.** About 7–8 m³ stood in the pool, and `pools()` reported 12 m² from about 15 s. The planar view came on then (`planar_enabled`, level followed).
- **It was a shallow dish.** The water brush's (1 − t²)² hollow, 7.7 m across, held most of its water in a thin rim. Within 4.5 m of the pool at 16 s, 44 m² was drawn: 21 m² under 15 cm, 9 m² deeper than 30 cm, and a mean depth of 0.17 m. 24 m² of it still ran fast enough (over 0.22 m/s) to draw as a stream.
- **The planar path shows the bed through shallow water.** It mixes in the screen's bed by `exp(−(2.0, 0.7, 0.45)·depth)`. That is tuned for the planned ponds' basins, which are a metre or more deep. At 0.17 m it keeps 89 % of the grass in green. The shallow end of the depth palette (`79ae9b`) is itself close to the meadow's green, so the inside read as grass, and only the shore-foam band showed.
- **Not the cause:** `live_level`. 94 % of the pool's rest facets are within 16° of level, and the swell and chop tilt them by only a few degrees more. `live_thin` applies only to moving water.

**What changed:**
- **The pool is a pond** (`BED_*` in `water_flow.gd`).
  - Radius 1.2 + 0.55√V (1.8–3.4 m; 2.7 m for a 7.5 m³ ball, against 3.9 m before).
  - Full depth inside 45 % of the radius, rising to the ground on a smoothstep.
  - Deep enough to hold the ball with 0.1 m to spare (0.35–1 m; 0.71 m for 7.5 m³, against 0.53 m at the middle only).
- **Live ponds hide their bed sooner** (shader `bed_absorb`, `water_flow_view.gd` `BED_ABSORB` = 2): the planar path's absorption runs twice as fast with depth for live still water. Planned ponds keep 1. Thin moving films keep the `live_thin` wet-ground look.

**Measured** (same gestures; a take's pool lands where its course runs):

| At 16 s | Before (4.5 m round the pool) | After (0.9 radius round the pool) |
|---|---|---|
| Still water drawn | 44 m², 24 m² of it under moving water | 18 m², 1.7 m² of it under moving water |
| Mean drawn depth | 0.17 m | 0.44 m |
| Deeper than 30 / 60 cm | 9 / 0 m² | 12.4 / 6.1 m² |
| `pools()` | 12 m², 0.49 m deep | 15 m², 0.78 m deep |

Soaked by 30 s: 1.5 m³ before, 0.8 m³ after. The reflection comes on at about 15 s in both.

**Unverified on screen:** the pond's look with `bed_absorb`. The shader edit needs a windowed compile check.

## Known gaps and follow-ups

- **Unverified on screen:** how the flip and the turn treat the new meshes (the edge falls hide during the flip, unfilmed); the GPU cost of the reflection view and the mesh uploads (see "Look pass").
- **One reflection for all live ponds.** Only the followed pond, and water within 0.3 m of its level, reflects; other live ponds keep the ordinary surface, as planned ponds past the two largest do.
- **Record ponds and streams are not simulated.** A generated world's ponds and streams, and the planned water under `--planned-water`, stay as records. Live water sees their beds as bare ground, so it pools in them and draws over them. They could be seeded into the depth grid and retired.
- **Emergence only avoids the water.** Its biome blend still reads water distance and wetness from pond records, so reeds and bank grass do not yet favour live shores, and plants already standing where live water arrives stay. `drown` has no live counterpart.
- **Drain under `--modeless`.** Only undo removes a spring there. The water brush's Shift-drag drains outside `--modeless`.
- **The groove's bed.** The clay's groove follows the ground (0.3 m deep on this branch; `feature/thumb-dirt` is deepening it), so a groove across a hump dams its own water. The probe's groove is shaped to fall steadily.
- **A ball on flat ground soaks away** within a minute or two. The planned water always scooped a hollow instead. Tune `soak` or `evaporation` if puddles should last.
- **Sound.** The water's sound hears `water_settled` pool reports, but has no running-water layer for live streams.
- **Tests.** No suite tests were added or run (the user deferred them during the scenic pivot). `tools/probe_void_snap.gd` drags in the void to check a drag does not snap; a drag that crosses the land now gathers a water ball.

# Live water

Branch `feature/water-flow` (2026-09-28). The user asked for water that is physics-based above all: "I want a user to be able to create a mountain, add a waterfall to it, and then, with that water, if they thumb carve, the water can fill the areas where they thumb carved, and fill into a pond if they depress that area with the palming tool." They chose a real flow simulation over running the water brush's one-shot plan again.

Under `--modeless` a dropped water ball feeds a live shallow-water simulation instead of the one-shot plan (`docs/scenic/water-brush.md`). `--water-flow` turns it on without `--modeless` (the water brush's ball then feeds it too), and `--planned-water` keeps the plan for A/B.

Checked headless (`tools/probe_water_flow.gd`, `tools/probe_water_flow_modeless.gd`) and filmed (`tools/film_water_flow.gd`, see "Look pass" below).

## What it does

- **Water runs, pools and spills.** Water runs downhill, fills a thumb's groove as a channel, pools in a hollow or a palm-pressed basin, and spills over the lowest point of the rim into the next low ground.
- **It follows the land.** Every step reads the ground under each cell again from the terrain's heights. A trench cut out of a pond drains it into the trench; a basin pressed beside a stream takes the stream; a peak raised under a pond throws the water off. There is no hook to miss: a sculpt, the clay, an undo, a mountain springing and a new world all move the water the same way.
- **The plate's edge drains.** Water that reaches the plate's outer ring of cells falls off the plate and is gone. A basin holds its water until the water tops the lowest point of its rim; only then does it run on, and off the edge if nothing lower stops it. This keeps water from ever building up against the rim, and needs no lip.
- **Water soaks and evaporates.** Every wet cell loses `evaporation` a second, and thin water (under `soak_depth`) loses up to `soak` more, so a front soaks in as it runs. A steady spring therefore levels off: in the probe, a 0.084 m³/s spring's water holds at about 12.6 m³ over about 50 m² after four minutes. A pond without a source lasts a long while (a 6 m³ pond, about 15 minutes); a puddle on flat ground soaks in within a minute.
- **Springs and bursts.** A ball that lands 1.2 m above the plate's low ground (`SPRING_RISE`; the low ground is the plate's 20 % height quantile), or on ground steeper than `SPRING_SLOPE`, lets its water go and **stays as a spring**, pouring `SPRING_SHARE` of its volume each second. A ball anywhere else lets its water go once. Either way the ball's water leaves over `BURST_SECONDS` across `BURST_RADIUS`, not in one lump. The user will refine where springs come from.
- **Water from the sky** (`--modeless`). The water ball had no door under `--modeless` (left presses on the land are clay). Now a press in the void (the sky) that drags onto the land condenses a water ball there, and it fills while held, as the water brush's press did. Letting go drops it. A click in the void is still the snap. The void's hint says so.
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
| Edge | The ring of plate cells at the grid's border (or beside a wall) drains. What arrives there is counted as `drained` and removed. |
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
- **Falls** (`scripts/flow_falls.gd`, `FlowFalls` on the scene). Traced from the flow and sized by its flux; see "Waterfalls" below.

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
| `SPRING_RISE`, `SPRING_SLOPE`, `LOW_SHARE` | 1.2 m, 0.45, 0.2 | A ball is a spring this far above the plate's `LOW_SHARE` height quantile, or on ground this steep. |
| `SPRING_SHARE`, `SPRING_MIN`, `SPRING_MAX` | 0.012 /s, 0.03, 0.25 m³/s | Spring rate as a share of the ball's volume each second. |
| `SPRING_RADIUS`, `MAX_SPRINGS` | 0.35 m, 8 | A spring's footprint; the oldest goes when a ninth comes. |
| `BURST_SECONDS`, `BURST_RADIUS` | 1.2 s, 0.8 m | How a ball's own water leaves it. |
| `POOL_DEPTH`, `POOL_SPEED`, `POOL_CELLS` | 0.15 m, 0.12 m/s, 12 | What counts as standing water for life. |
| `WET_DEPTH` | 0.05 m | Water that stops emergence. |
| `SURFACE` (`water_flow_view.gd`) | wet 1.2 cm, lift 1.2 cm, flow on/off 0.22/0.12 m/s, foam 0.8–2.2 m/s, depth scale 0.45 m, under | Surface build. |
| `MIN_AREA`, `LEVEL_STEP`, `BAND`, `SWITCH_SHARE` (`live_water_reflection.gd`) | 1.5 m², 1 cm, 0.3 m, 1.6 | When the reflection view stands, how far the pond moves before it follows, how far from its level water still reflects, and when it changes pond. |
| `SURFACE_SECONDS`, `FALLBACK_SURFACE_SECONDS` (`water_flow_view.gd`) | 1/30 s, 0.1 s | Surface rebuild interval. |
| Waterfalls (`flow_falls.gd`) | see "Waterfalls" | Detection, easing, look. |
| `FLOW_READ_SECONDS`, `FLOW_REPORT_SECONDS`, `FLOW_AREA_CHANGE` (`native_chunk_editor.gd`) | 1 s, 3 s, 2 m² | Reading and reporting pools. |
| `FLOW_FISH_SECONDS`, `FLOW_FISH_REACH` (`native_chunk_editor.gd`) | 90 s, 12 m | A ball's fish waiting for a pond. |

## Code

- `native/terrain_kernels/water_flow.h`: `ZenScapeWaterFlow`, registered by `kernels.cpp`. It holds `configure`, `set_params`, `step` (resample the ground, then run the ticks with the sources), `add_water`, `drain`, `get_depth`/`set_depth`, `get_ground`, `get_velocity`, `wet_cells`, `stats`, `surface`, `pools`, `falls` (the old point search, unused by the view) and `cascades` (the waterfalls). Rebuild the library after changing it (`native/terrain_kernels/README.md`).
- `scripts/water_flow_reference.gd`: the GDScript mirror, with the same methods and arithmetic. Keep the two in step.
- `scripts/water_flow.gd`: the owner. It holds the grid and cell map, the fixed clock, springs and bursts, `drop`/`drain`, and undo, save and load.
  - It takes the mirror when the library is missing, when it lacks the newest method (`cascades`, so a stale build falls back instead of failing), or under `--gdscript-kernels`.
  - `native` says which one runs, and the probes check it.
- `scripts/water_flow_view.gd`: the surface meshes; it stands the falls.
- `scripts/flow_falls.gd` and `shaders/flow_fall.gdshader`: the waterfalls.
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
- **Still off: thin sheets read milky white.** Water only a few centimetres deep, such as an overflow spreading on flat ground, lies wholly inside the shore-foam band (`zs_look_shore`, depth under about 3.5 cm), so the whole sheet takes foam. Planned ponds never have such sheets. The fix would be to fade the lap foam by distance to a dry cell rather than by depth, for example with a shore distance in UV2.y's spare lane.
- **Still off: water in a deep, narrow trench reads as grey haze.** It takes the sky's grey at the planar Fresnel.
- **Each take differs.** The palm's basin depth varies with the synthesized strokes: −1.5 m in one take and −0.55 m in the next, where the pond spilled onto the plain.

## Known gaps and follow-ups

- **Unverified on screen:** how the flip and the turn treat the new meshes; the GPU cost of the reflection view and the mesh uploads (see "Look pass").
- **One reflection for all live ponds.** Only the followed pond, and water within 0.3 m of its level, reflects; other live ponds keep the ordinary surface, as planned ponds past the two largest do.
- **Record ponds and streams are not simulated.** A generated world's ponds and streams, and the planned water under `--planned-water`, stay as records. Live water sees their beds as bare ground, so it pools in them and draws over them. They could be seeded into the depth grid and retired.
- **Emergence only avoids the water.** Its biome blend still reads water distance and wetness from pond records, so reeds and bank grass do not yet favour live shores, and plants already standing where live water arrives stay. `drown` has no live counterpart.
- **Drain under `--modeless`.** Only undo removes a spring there. The water brush's Shift-drag drains outside `--modeless`.
- **The groove's bed.** The clay's groove follows the ground (0.3 m deep on this branch; `feature/thumb-dirt` is deepening it), so a groove across a hump dams its own water. The probe's groove is shaped to fall steadily.
- **A ball on flat ground soaks away** within a minute or two. The planned water always scooped a hollow instead. Tune `soak` or `evaporation` if puddles should last.
- **Sound.** The water's sound hears `water_settled` pool reports, but has no running-water layer for live streams.
- **Tests.** No suite tests were added or run (the user deferred them during the scenic pivot). `tools/probe_void_snap.gd` drags in the void to check a drag does not snap; a drag that crosses the land now gathers a water ball.

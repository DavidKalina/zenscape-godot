# Modeless: flipping the diorama

Behind `--modeless`, one slice of the scheme in `hand-world.md` ("Verbs on the diorama"). Drag the rim up and over the lip and the diorama turns over: its other side is a new world. "Flipping it over is what creates a new chunk... you're like flipping it over and starting over."

The code is `scripts/diorama_flip.gd`, built by `studies/cozy_worlds.gd` when `--modeless` is set (`scene.flip`). The probe is `tools/probe_diorama_flip.gd`.

## The API the rim gesture calls

The rim agent's `hand_reach.gd` emits `flip_began(screen_pos)`, `flip_dragged(progress)` and `flip_released(progress)`. At merge, connect them to:

- `begin(screen_pos) -> bool`: takes the snapshot and grips the rim. False while another flip, a regrowth or a formation is busy (`can_begin()`).
- `drag(progress)`: 0..1, how far over the lip. Starts making the world at `GENERATE_AT` (0.2). At `AUTO_COMMIT` (0.97) it goes over without waiting for the release.
- `release(progress)`: decided at the release (the edge rework, `docs/scenic/modeless.md`): upright or past it (`TIP_ANGLE`) it goes over; with a flick (smoothed drag rate at least `TOSS_RATE`) it is tossed and may fall back or go over; slowly, it falls back and emits `set_down(progress)`, which sinks a basin. `COMMIT_AT`, `FLICK_RATE` and `FLICK_FROM` are gone.
- `can_catch()`, `catch(screen_pos)`: a tossed plate in the air is held where it is, and the next drag adds to its angle.
- `dip_begin(screen_pos)`, `dip_to(amount)`, `dip_release(amount)`, `dip_finish()`: the edge spring's dip, on the same snapshot; `dipped(amount)` when it is back at rest.
- `flip_back() -> bool`: flips the other way and brings the previous world back (see Undo). `back_source()` says how (UNDO, KEPT, or NEW for nothing to bring back). The parent should route its undo key here when `back_source() != NEW` and the flip is the last thing done.
- Signals: `landed(world_seed)`, `fell_back`, `phase_changed(phase)`. `active()` and `going_over()` tell the rim routing to ignore presses.

**Temporary trigger, remove at merge:** `_unhandled_key_input` and `debug_flip()` in `diorama_flip.gd` (F8 flips by a scripted drag, F7 flips back). Marked TEMPORARY in the code. The probe uses `debug_flip` for its later flips.

The hand holds the new `flip` key in `god_hand.gd` `GESTURES`, which plays the existing Rim clips (RimIn, RimHold, RimOut). It exists because `hand_reach.gd` clears `"rim"` each frame while it is not holding the rim, which happens as soon as the drag is let go and the flip carries on. No new clips.

## Feel

- **Held.** The plate follows the drag's angle (progress times pi) on a spring (`HOLD_W` 13, `HOLD_ZETA` 0.85), so it lags a touch like something heavy. `RESIST` holds back 16 % of the lift at the start of the drag, easing away by 75 % progress. It tips up on a hinge at the far edge, like a lid. The edge nearest the camera (or the one under the press, snapped to a side) is the one that lifts, so from the default camera the near lip comes up toward the view and over.
- **Hinge.** The hinge stays on the far edge for the first `HINGE_HOLD` (0.5 rad) of tip, then slides to the middle over the next quarter turn, so past vertical it turns like a coin and lands where it was, instead of falling beyond the far edge. The middle also rises `LIFT` (0.08, was 0.3, which took the plate off the top of the frame) of the half width times sin(angle), so the lower half is not below the horizon. `pose(angle, lift)` is the whole of it.
- **Fall back.** Under half way: gravity-like acceleration (`FALL_ACCEL`, more when high), a bounce that keeps `BOUNCE` (28 %) of its speed, a small tremor per bounce. In the probe a drag to 0.4 rests after 0.7 s with two bounces and changes nothing.
- **Over.** A pull back (`PULL_ANGLE` 0.16 rad, 0.2 s), a spring throw toward `HOVER_ANGLE` (2.7 rad, about 155 degrees), a hover there that creeps on a little and bobs, for at least `HOVER_MIN` and as long as the world needs, then a drop (`DROP_ACCEL`) to pi and a thump (`_tremor.add(THUMP)`, and `world_rumble` held through the making). The landing bounce moves the world on screen with the tremor's `jiggle` (the snow globe's channel), not the nodes, and the hand lets go when it settles. About 1.8 s from release to landing when the world is ready as it is thrown.

## How it looks: a snapshot, not the real nodes

The world's nodes cannot be rotated safely. The diorama is about forty scattered nodes at the origin (the reference terrain and skirt, plants, ponds, falls, dead wood, fish, land life, leaf litter, planar water and more), with a creature's physics bodies and a good many shaders that read world position (`MODEL_MATRIX[3].xz` seeds, wind sampled at world position, the local wind field).

The other option in the brief was to rotate the camera and the room together. That cannot work for a flip: the room is only fixed in yaw (`world_turn.gd` `room_yaw`, `zs_room_yaw`), and pitching the camera over the world would turn the sky, sun and lights upside down with it, then snap back.

So `begin` takes a **snapshot**:

- Every visible `MeshInstance3D` and `MultiMeshInstance3D` in the scene gets a copy on one pivot node (`FlipSnapshot`). The copies share the meshes, multimeshes and materials, so it is a few dozen nodes and no uploads.
- The real nodes move to render layer 19 (`HIDDEN_LAYER`). The main camera's cull mask and every light's cull mask drop that layer, so the real world is neither drawn nor casting shadows. Nodes the real world grows while hidden (or gives a mesh to for the first time, like the pond surface) are hidden the moment they appear (`node_added`).
- The pivot's transform is the tip and turn. The sky, sun, lights, fog and weather stay put, in front of the fixed room.
- Left out of the snapshot: weather, lightning, atmosphere, lights, fire, the explosives, world play, the wanderer and the creatures (skinned, and physical). They vanish while it is in the air and come back with the world.
- The God Hand is a child of the real terrain. For the flip it is reparented to a stand-in on the pivot at the terrain's rest pose (`_hand_anchor`), so it grips the rim all the way over, and handed back at the end. The real terrain does not move: forming the new plain reads its transform (the earth sides sample the land through `terrain.to_local`, the fog takes its ground bounds from `terrain.transform`), and before 2026-09-28 the terrain rode the pivot, so the new plate's sides and the fog's ground were built upside down and stayed wrong after the landing (dark faceted shapes under and around the plate).
- The real world carries on underneath, hidden. That is where the new one is made, so nothing about the making can be seen.

Everything is put back (`_release_world`) at the landing, on a fall back, or on a give-up.

## The new world: a blank plain

2026-09-28, after the user first flipped it on screen: "the flip animation, the beginning is great... But then as the flip occurs, it freezes... once it unfreezes, you have a blank new chunk and then the world generates... Also, the bottom of the chunk when you're flipping it over does not look like the same thing as the start of a fresh new chunk... maybe we shouldn't generate a new chunk... It should just start as a blank canvas." So the other side is now a Genesis plain (`scripts/genesis_canvas.gd`, the same plain the game opens on), under the same sky. The generated world, its 4 s growth and its change of mood are gone from the flip; Regrow still makes generated worlds.

- **Baked ahead.** While the flip is idle it keeps a plain baked for the next one (`_keep_baked`, `_bake_underside`). A worker thread sets up a detached `NativeTerrainData` from the land's own arrays (`setup(mesh, arrays)`, so the worker reads no mesh), shapes it with `Genesis.shape` from the seed the flip will use, and builds its mesh: the same steps as forming it for real, and the same vertices (the probe checks). About 55 to 60 ms on the worker, nothing on the main thread but fitting its earth sides (`editor.skirt_mesh_for`, split out of `_rebuild_skirt`, about a millisecond). It is baked again if the land's palette changes (checked every `BAKE_CHECK`, 1 s) or a probe asks for a seed (`next_seed`).
- **The underside.** `begin` hangs the baked plain and its earth sides on the snapshot, turned over (`pose(PI)` inverted), so the plate's other side is the plain from the first tip; from the default camera it shows from about 40 degrees of tip. The plate's middle is set so the plain's lowest point just meets the old world's base, and the plain is held `UNDER_SHRINK` (0.4 %) inside the old footprint so the two sets of walls do not fight. Turned over by pi, the underside stands exactly where the real plain will (inside that shrink).
- **The old world is pressed flat.** Between `SQUASH_FROM` (0.3 pi) and `SQUASH_TO` (0.75 pi) the old world's copy is squashed toward its base to `SQUASH_LEFT` (2 %) of its depth and drawn in by `SQUASH_IN` (1 %), so it does not hang below the new plate at the landing (a mountain would otherwise poke out under it, and tall rim walls would cut short at the touchdown). It is a function of the angle, so a toss that falls back unsquashes. The hand's grip follows the lip that is coming up.
- **Forming** the real plain (`Genesis.form`, live, one undo step marked `flip`) starts when the flip is decided, behind the snapshot, at the raised `MAKE_BUDGET_USEC` slice. It is about 35 ms of work over about 17 frames and is ready about 0.3 s into the throw, so the hover is its least (`HOVER_MIN`). No view fitting (a plain has the same extents). Outside scenery mode the navigation is rebuilt as before.
- **Touchdown.** The snapshot is dropped and the real plain is there, whole: no fold, no growth, no mood change, the sky as it was. `places.plain` is set and the plain's day is synced as when the game opens on one. The thump and the landing bounce are as before. The next flip bakes a new plain.
- **Hover** and `GIVE_UP` are unchanged, but a plain is ready long before either matters.

The scene is paused and the brush put away from the moment the flip is decided, as in Regrow, and restored after.

## Undo, and losing nothing

- **The undo step.** `form_inland` leaves the old world one step down `data._undo` with its whole scene state (`favorite_scene`), the same step Regrow leaves. The flip marks it `flip`. The editor's ordinary undo restores it (with a hard cut).
- **Flip back.** `flip_back()` runs the same flip the other way and swaps in by that undo step while the flip is still the last step.
- **The kept copy.** When a flip is decided, the world it will replace is kept whole (document plus scene state, at the drag's 0.2, about 1 ms for a plain and a generated world in the probe, a background write of the file). It is held in memory (`kept`), and written on a worker thread to `flip-previous.json` beside the places, in the same format as `places.json`, so it survives a quit. Undo history is capped at 50 steps and painting pushes more; when the flip is no longer the last step, `flip_back()` brings the kept copy back through the same flip (`Source.KEPT`), and keeps the world it leaves in turn, so flipping back again returns to it. The file is a separate one from `places.previous_path()` so that the plain launch's set-aside place is never overwritten.
- What does not survive: a second flip replaces the kept copy with the world the second flip left. One step of memory, plus the undo stack.

## Probe

`tools/probe_diorama_flip.gd`, headless, `--fixed-fps 60`, `-- --modeless`, on the real `studies/cozy_worlds.tscn`. It proves:

- The pose is the identity at rest; at pi the plate is upside down in place and its grabbed edge is at the far edge; a quarter turn lifts the edge; the hinge keeps the far edge down while it tips.
- A drag to 0.4 follows with weight, the hand grips (`flip`), the release falls back with two bounces, and nothing changes: heights, the whole document (hash), the recipe seed, the camera's cull mask, the terrain's transform, no snapshot left, the hand let go.
- A plain is baked for the seed asked for, and the snapshot carries it on its underside.
- A drag past half way goes over (angle reaches pi), lands on the seed asked for, and the world after is a blank plain with new heights. The underside had the landed plain's vertices exactly, and turned over it stood where the plain does. The old world was pressed to 2 % of its depth. The real world changed while the snapshot was up (at 118 degrees). On every frame while the snapshot stood, no mesh of the real world was drawable by the main camera. It landed and settled about 2 s after the grab, the terrain and the camera are back, the scene is unpaused and the hand let go.
- Longest main-thread frame: 15.5 ms, and 15.0 ms plain to plain (headless, so render cost is not in it; the budget it is held to is 100 ms). The plain was ready about 0.3 s into the throw.
- Undo: `flip_back` by the undo step brings the old world back exactly (heights, document, recipe, blank).
- The kept copy: after a second flip and a brush stroke (so the flip is no longer the last step), `flip_back` brings the first world back exactly.
- Nothing is left running: the probe joins the flip's background work before it quits (see Shutdown).

The world-turn and fixed-room probes were rerun with `--fixed-fps 60` and pass (27 and 19 checks). `probe_god_hand_wiring` has the same two headless failures with and without this change ("the hand leans into the pointer's way", "and tells the ball where it pokes"); `probe_hand_reach` passes.

Timings in the probe's frame counts are not in real time. Headless frames take 2 to 7 ms rather than 16.7, so waits on the worker look up to ten times longer in frames than they are (the first flip hovers about 3 s of game time in the probe for about 350 ms of work).

## Shutdown

Godot aborts at teardown if a `WorkerThreadPool` task is still running or was never joined. Anything the flip puts on the pool is joined: the kept world's write is joined before the next one and in `_exit_tree`; the underside's bake task id is kept and joined in `_exit_tree`; `wait_idle()` finishes both for a caller that wants to be sure (the probe calls it before `quit`).

## Not verified

- **How any of it looks on screen.** Nothing was rendered: the snapshot, the pose, the pull back, the hover and the landing are checked as numbers and as node state only. The pose's clearances (the plate's far corner at a quarter turn is about 19 m above the plate's middle, which may crop at the top of a narrow window on the default camera), the lift and the time constants are all the first thing to tune by eye.
- **World-space shaders on the tilted snapshot.** Terrain, plants and water read `MODEL_MATRIX` and world position for per-instance seeds, wind, height tints and the local wind field. On a tilted plate those change with the rotation, so colours or sway may shimmer in the air. If they do, the fix is a global uniform with the snapshot's transform that those shaders undo before they read world position.
- **The planar water** reflects its own copy of the world, so the snapshot's water may show the flat, unflipped reflection.
- **Creatures, weather and fire vanish** while the snapshot is in the air.
- **Whether the freeze the user saw is gone.** Headless has no render cost. The old flip made a whole generated world (new biome, plants, shaders) behind the snapshot; a plain is the same materials and about 35 ms of budgeted work, so the likely causes are gone, but nothing has been timed on the GPU.
- **The seam at the touchdown**: the underside is 0.4 % smaller than the real plain (about 6 cm at the edge), and the squashed old world's base sits at the plain's lowest point; both should be hidden by the thump.
- Whether the God Hand's Rim clips look right lifting a whole plate; they were made for a lip grip, and there is no clip for the far hand of a flip.

## Likely to conflict at merge

- `scripts/god_hand.gd`: four one-word additions for the `flip` key (`GESTURES`, `TILT`, `UNLIFTED`, the `free` test) and a doc comment. Reconcile with whatever the rim agent adds to those tables.
- `scripts/hand_reach.gd` (not touched here): it clears `"rim"` when it is not holding, so it must not clear `"flip"`, and when it routes `flip_began` it should leave the hand to `diorama_flip.gd` (`begin` sets `reach_gesture`, `reach_point` and `reach_facing` itself).
- `studies/cozy_worlds.gd`: a `flip` var and five lines at the end of `_ready`.
- `scripts/frame_work_budget.gd`: a static `override_usec`, used only by the flip.
- The flip touches the camera's `cull_mask` and the lights' `light_cull_mask` while it is up. Nothing else should use layer 19.
- `world_turn.gd`, `camera_rig.gd` and `fidelity.gd` are untouched. The rig should not orbit while `flip.active()`.

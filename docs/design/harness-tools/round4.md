# Harness tools, round 4: stills and films of a moment

The survey (`scratch/tool-survey.md`, rank 3) found agents building their
own Camera3D for rendered stills in 49 of 160 runs since the harness
landed. They wanted a still or a short film of a moment in a driven run,
and shot.py's views were only reachable from the CLI. This round adds
`shot_at()` and `film()` to drive.gd. No game code changed.

## What agents' scripts converged on

From `linger_shots.gd`, `hunt_shots.gd`, `olmec_film.gd`,
`weeper_run_shot.gd`, `merchant_shot.gd`, `flyer_shots.gd` and
`beetle_film.gd`:

- views relative to him and the enemy: side (across the line between
  them), behind or over his shoulder at the enemy, in front of a face, high,
  and the play camera;
- framing both him and the enemy (the middle of the two);
- a fixed eye that turns to follow, or one that moves with the target;
- a still every N frames for a count, from a state onward (`--from=act`);
- the camera made current, then the study's camera put back.

## API (drive.gd, `# --- Shots ---`; `python tools/drive.py --api shot`)

`shot_at(view, target, opts) -> String` places a camera on a view of the
target, framed by its size, and saves a still. It prints
`[fN] saved PATH: side of him at (..), 4.2 m off` and returns the path.

```gdscript
await shot_at("side", motor, {"when": func() -> bool: return not motor.grounded, "dist": 1.6})
await route(Art.way_up(), {"name": "hill"})      # the armed still is taken mid-jump
await shot_at("three", collision_box(first("Belfry")), {"out": "scratch/belfry.png"})
```

`film(target, opts) -> Dictionary` takes a still every `every` frames
for `seconds` (or `count` stills). It runs in the frame hooks, so it goes
on through any `route()` or `watch()` the driver awaits.
`film_end(f, now = false)` waits for the film to finish (`now` stops it
at once), writes `<out>_sheet.png` and returns `{shots, sheet}`. It prints
`[fN] FILM weeper side: 20 stills every 6 frames, DIR, sheet PATH`.

```gdscript
var f := film(w, {"view": "side", "with": "him", "every": 6, "count": 20,
	"when": func() -> bool: return float(w.gap_to_him) < 6.0})
await watch(w, {"frames": 420})
f = await film_end(f)
```

- **Targets.** A Node3D (the box of its visible meshes), `motor` or
  `"him"`, a pattern for `first`, a Vector3 (`radius`), or an AABB.
- **Views.** shot.py's world views (three, front, back, left, right, top,
  close); the turning ones side, ahead, behind, shoulder, high; play (the
  study's camera, untouched); or a Vector3 way out from the target. Side
  takes the other side when a collider hides the target from the first.
- **Opts.** `out`, `dist`, `fov`, `radius`, `with` (frame a second target
  too), `eye`, `offset`, `size`, `hud` (play view only), `when`. Film only:
  `every`, `seconds`/`count`, `sheet`, `cols`, `cell`, `follow` (false:
  fixed eye that turns), `turn`.
- **Headless.** One `SKIP shot_at ...` / `SKIP film ...` line each. shot_at
  returns "". film returns a finished film with no stills, and film_end
  returns it at once. An armed still that never fires prints a SKIP line at
  `finish()`.
- **Also public now.** `make_sheet(paths, out, cols, width)`,
  `mesh_box(tops)`, `view_eye(view, box, ahead, him, fov, dist)` and
  `VIEWS`. shot.gd and sheet.gd use them, so shot.py and a driver frame the
  same way.

### Design notes

- **A SubViewport, not a current camera.** shot_at and film render
  through a SubViewport on the same World3D. Its camera copies the play
  camera's environment, attributes and cull mask. The study's camera stays
  current. The Weeper, the Linger and item pickups act on
  `get_viewport().get_camera_3d()`. The first version made its own camera
  current, and the filmed Weeper froze ("seen") and never came. The extra
  render costs a frame's draw for each still, and a small view each frame
  while a film runs.
- **mesh_box leaves out** particles, and meshes under a `top_level` node
  below the framed node. His puffs and ripples are top-level multimeshes
  near the origin, and they had stretched his box to 100 m. This also changes
  `shot.py --frame` slightly, for the better: it skips the same meshes.
- Films grab the frame drawn from the camera set one hook earlier. A film
  keeps its size from its first frame, and its middle is eased (0.5 a frame).
- `drive.py --rendered` now takes shot.py's window lock, so a rendered
  driver and a shot.py run never open two windows.

## Proof (rendered, one window each, watchdogged; images in `scratch/r4/shots/`, drivers in `scratch/r4/`)

| What | Driver | Image |
|---|---|---|
| Him mid-jump during `route(Art.way_up())` on the aqueduct isle (armed `shot_at("side", motor, {when})`) | `jump_still.gd` | `jump_side.png`, also `hill_top_high.png`, `hill_top_play.png` |
| The Weeper's approach and blow during `watch()`, framed with him, as a 20-still film and sheet | `weeper_film.gd -- --with=him` | `weeper_side_sheet.png` |
| The same over his shoulder | `weeper_film.gd -- --view=shoulder --every=8 --count=12` | `weeper_shoulder_sheet.png` |
| A kit piece (bell_spires' Belfry) by its collision AABB, three ways | `piece_still.gd -- --scene-args --motif=bell_spires` | `piece_sheet.png` |
| The beetle's lip bout during `watch()` (the survey remake) | `beetle_film_after.gd` | `beetle_lip_sheet.png` |
| Edge paths: film stopped early, a `when` that never fires | `edges.gd` | `edge_sheet.png` |
| shot.py unchanged | `shot.py studies/trap_yard.tscn --frame walker --view three,front,top --sheet` | `trap_sheet.png` |

Headless, every driver above ends with exit 0 and only SKIP lines.
Headless import: 0 errors. Smoke: aqueduct_isle, weeper_yard,
beetle_yard and motif_yard (`--motif=bell_spires`): 4/4 PASS.
`drive.py --api` exits 0 after `--api --update`.

## Survey remake: before and after

`beetle_film.gd` (survey, agent-acb031c784a7ca885) has a fixed side camera
placed by hand, a loop of 420 frames, a jump at the charge and a still at
each state change or every 6 frames. It is **57 lines**. The remake,
`scratch/r4/beetle_film_after.gd`, uses `film(b, {"view": "side", "with":
"him", "follow": false, "when": tell})` and `watch(b, {"pilot": leap})`. It is
**20 lines**, and it adds the watch log and a contact sheet. The Linger
scripts (`linger_shots.gd`, `hunt_shots.gd`) were the first pick, but the
Linger isn't on main. `merchant_shot.gd` no longer runs against the current
merchant.

## Gaps

- One film at a time is the expected use. Two films each make a view of
  their own, which works but doubles the draw cost.
- Contact-sheet cells have no frame labels (Image has no text). The PNGs
  carry the index and the FILM line gives the cadence.
- In a rendered run, `first("Belfry", first("Motif_"))` found nothing in
  the motif yard, though `first("Belfry")` from the study did. Not looked
  into: it is the yard or `find`, not the shots.
- A machine-wide window lock (the survey asked for one) is not done. The
  lock is still per checkout (`.godot/harness-window.lock`).

## Tests

No existing test breaks. No test uses `tools/harness/`, `shot.py` or
`drive.py`. `test_game_pause.gd` and `test_threaded_instances.gd` matched a
grep and pass. The full suite was not run, and no tests were added.

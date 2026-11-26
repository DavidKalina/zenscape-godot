# Handoff: the 10 ms stall in t_smash (2026-11-26)

## The cause, as measured

The frame log's `t_smash` part is all of `SurgeSmash.before()`, and its first
line is `walls.step(eye)` (scripts/endless/cracked_walls.gd), which runs every
frame, surge or no surge. The stall was not the surge's `_scan_ahead`: in
driven flights the 11-13 ms frames all fell on a cracked-wall chamber
committed into the tree (`_commit`) as it came within REACH (2400 m). Timed
inside `_commit` (seed 1, three chambers):

| step | ms |
|---|---|
| `_tidy(room)`: freeing the room's hull body (~1200 ConvexPolygonShape3D) | 6.2-7.0 |
| `_tidy(wall)` x2: each wall's hull body (~350 shapes) | 1.1-1.3 each |
| box bodies, records, `breaks.add` | ~0.6 in all |
| `_sunlit` | 0.05 (8 ms once, the first chamber at load: tone materials made) |

The builds make their own hulls (RuinKit `Build._body`) and `_commit` threw
them away on the main thread, since boxes stand in for the chamber's collision.

`_scan_ahead` itself measured 0.1-0.3 ms. In seed 1 and 2 flights and an
amberlands flight no standing arch record had a `kit_piece` node under it
(land arches are merged meshes; peak carves have none), so it adopted
nothing; the only breaks targets were the cracked walls.

## The fix

`_make` (already on a worker) frees the room's and walls' hull bodies there,
off the tree, on the thread that made them (`_drop_hulls`). `_tidy` still
calls it, now finding none. Nothing else changes: same box bodies, same
records, same `breaks.add` and threaded pre-cuts (the rebuild for a cut still
builds its own hulls).

## Before / after (headless, t_smash per frame, 3600 frames, meter held full)

| run | worst mid-flight frames before | after |
|---|---|---|
| seed 1 | 13.11, 12.33 | 0.83, 0.78 |
| seed 2 heading 200 | 12.09, 11.22 | 0.58, 0.56 |

The load frame (t=0, the first chamber plus first-use materials) went from
~37-40 ms to ~10 ms; it is before the flight starts.

The smash still works: `scratch/surge_wall_hit.gd` (driven along a line into
start-east's front wall, meter full, surge pressed 90 m out) breaks both
walls, pre-cuts used 2, missed 0, cut 0.01 ms in the hit's frame, chamber
reads opened, no crash. Rendered stills show the wall blowing out.

## Not covered

- Freeing physics shapes on a worker: they were already made there, so
  this is symmetric, but only Windows/Jolt-or-default physics was run.
- Not flown by hand with `--frame-log`; ask the player to fly again and
  compare against the old logs.
- If kit-piece ruins come back into land arches, `_scan_ahead` adopts a whole
  arch in one frame; not measured with real pieces since none exist now.

## Tests

None touch the cracked walls, the breaks or the surge; none run.
Drivers (uncommitted): scratch/surge_stall.gd, scratch/surge_wall_hit.gd,
scratch/smash_csv.py.

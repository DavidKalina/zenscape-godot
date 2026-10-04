# Watch mode

`scripts/watch_mode.gd` puts the tools down so you can just look. **O** hides
every piece of chrome and hands the camera to a slow director. **O**, **Esc** or
a click comes back, and the camera stays where the watch left it.
`--watch` opens a world straight into watch mode, for filming and later for a
wallpaper export.

It is the first step of the "alive" layer for launch: a camera that shows off
the wind, the light and the life the world already has.

## The director

The director picks shots the way a nature film would. Each shot lasts 16–26 s.

| Shot | What it does | Lens |
| --- | --- | --- |
| Orbit | The whole plate from the overview, turning slowly and easing in a little. Always the first shot, and more likely the longer it has been away. | 45° |
| Drift | A place, dollying in from 1.6× to about 0.7× of a fitting distance while it turns. | 36° |
| Skim | Low across the land (polar 1.28–1.36). At golden hour it looks across the low sun, side-lit or against it. Never at night. | 40° |
| Follow | A deer, the heron, a bird or Bigfoot, loosely, until it leaves the plate. | 34° |

Rules:

- The same kind of shot never runs twice in a row, unless nothing else is
  possible.
- A place seen in the last 3 shots is not chosen again.
- The turn keeps its direction, and reverses one shot in four.
- The distance breathes ±4.5 % (log) over 23 s.

**Places** come from `gather_places`:

- One pass over the objects, binned on a 3.5-unit grid, finds groves (3 or more
  trees) and meadows.
- Built and rare things count on their own: the cabin, campfire, waterfalls,
  bridges, arches, lamps, redwoods and sunflowers.
- Every pond counts, and so does a summit standing 3 m or more above the mean.

At night the lit things (the cabin, campfire and lamps) weigh three times as
much, and groves and meadows less. Places are gathered again every four shots.

**Clear views.** Before a shot starts, its yaw turns in steps until the land
hides the pivot neither at the start, half way nor at the end. Its polar is
lifted until the eye clears the ground all the way through.

## Feel

The director moves a mark along each shot. The camera trails the mark on two
chained critically damped springs (`SETTLE` 0.62/s), so a move between shots
starts and ends at rest, and within a shot the camera lags the mark softly.

- **Pace.** A long move between shots cruises rather than rushes. The first
  spring's pace is capped at `PACE` 0.24/s. Pace is how fast the picture
  changes: the pivot's speed over the distance, plus the dolly's rate and the
  turn.
- **Ground.**
  - The first spring's eye is kept `LIFT_MARGIN` (2 m) over the ground.
  - The pose rises over banks on a lift of its own (a spring of `LIFT_W` 3/s).
    The lift looks 0.7 s ahead along the camera's way, so it starts early.
  - `FLOOR` (0.35 m) is a hard floor, as a last resort.
  - Before the lift, a move from a skim into a pond's basin crossed the rim
    0.21 m over the ground and jolted.

The pose is written into the scene's orbit, as photo mode does. The room is
not turned, so the sun stays put in the world and the light comes round as the
camera does.

While watching:

- The camera rig, photo mode and the wanderer stand aside.
- Every key except Cmd and Ctrl shortcuts is swallowed, so nothing changes
  behind the watch.
- Moving the pointer shows one faint line saying how to come back. After 2.5
  still seconds the line fades and the pointer hides.

## Checks

`tools/probe_watch_mode.gd` (headless, `--fixed-fps 60`) builds a hill, a pond
and a wood on the plain. The director is random, so the probe runs on four fixed seeds. For each
seed it presses O, lets the director run for 110 s, then clicks.

```
godot --headless --fixed-fps 60 --path . -s res://tools/probe_watch_mode.gd
```

It prints each shot as it begins, then the path:

- the largest step and change of step per frame;
- the pace (eye speed over distance to the pivot);
- the least clearance over the ground;
- the slowest frame.

Results on 2026-10-03 (seeds 37, 11, 23, 51; 61 checks pass):

- 5–6 shots per seed. Every seed had orbit, follow and drift or skim, and no
  kind of shot ran twice in a row.
- The largest change of step was 0.7 mm per frame, and the largest step
  0.10 m per frame (6 m/s).
- The highest pace was 0.18/s. The probe allows up to 0.3.
- The camera stayed at least 2.06 m over the ground.
- The UI hides on entry. On a click the UI comes back, the rig takes the camera
  where it is, and the lens is home.
- Gathering places takes about 1–2 ms. The slowest frame took 7.5 ms, at entry.
  An earlier run had one 20 ms frame mid-shot, not at a shot change. That is
  probably the world's life rather than the director, but it was not measured.
- `tools/probe_camera_focus.gd` with `-- --no-title` gives the same result
  with and without this change: 22 OK and 4 FAIL. The 4 failures are about
  brush dabs and water pours. Without `--no-title` it opens on the title and
  fails almost everything.

**Not verified headless:**

- How any of it looks or feels. Nothing has been watched on screen yet.
- Whether the shots frame well: the dummy renderer has no picture, and plant
  instances cannot be picked.
- The pointer hiding (probes leave the pointer alone).

## Next

- Tune by eye: shot lengths, the pull-back pace, lenses, skim heights.
- A palette button beside the photo camera, so watch mode is found without the
  key.
- An idle start: watch mode after a few minutes without input.
- Time-lapse while watching (days, then seasons), and a "hold this shot" key.
- Clip export for Wallpaper Engine: `--watch` with movie capture is the
  starting point.

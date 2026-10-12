# Snag study, round 1

A sky-folk pilot flies a fixed low loop with a part (the rune token as a
placeholder) on a rope under the plane. Watch a pass, get under the dip, and
touch the swinging load to snatch it. Branch `study/snag` (off `feature/ledger`).

## Run

    ./run-snag-study.command [--snag-lap=26] [--snag-rope=6] [--snag-dip=9.5]

It's also in the scene picker as On-foot greyboxes, "Snag study".

## Controls

The character study's: WASD run, Space jump, Shift/C crouch (slide, then Space
for a long jump), X twirl, Q / RB updraft (charged by flow). F1 shows the
numbers (the snag lines are at the bottom), F2 the feel, R the start.
Stations: 1 start, 2 pier, 3 perch, 4 terrace. The line at the top counts
down to the next pass over the pier.

## The spots

- **1 Start → 2 Pier** (easy): a 20° ramp up to a 10 m pier. The load passes
  about 3 m over its top, so a standing jump at the right moment takes it.
- **3 Perch** (long jump or twirl): a block off the dip's way out. The load
  swings past 1.7 to 2.5 m off its lip, 1.3 to 3 m over its top. Teleport
  only.
- **4 Terrace** (updraft): under the loop's far side, where the plane passes
  higher. Slide down the ramp, long-jump along the deck to build a flow
  charge, then updraft into the load, which passes about 8 to 10 m over the
  deck. Teleport only.

The stations are laid against the loop at its default tunables, so the flags
move the difficulty, not the ground.

## Tunables

- `--snag-lap=<s>`: one lap, 26 s by default
- `--snag-rope=<m>`: the rope's length, 6 m by default
- `--snag-dip=<m>`: the belly's height over the pier at the dip, 9.5 m by default

The constants in `scripts/snag_plane.gd` cover the rest: the loop's radii,
cruise height, far sag, bank gain, the rope's gravity, drag and load weight,
and the lurch.

## Built

- `scripts/snag_plane.gd`: the plane (`plane_figure.gd` in a traffic livery,
  drawn 2.5x its toy size) flying a parametric ellipse with a Gaussian dip,
  plus a 10-link verlet rope with a heavier load. `snatch()` frees the load,
  lurches the plane (a ringing roll and nose-down jolt) and makes its pilot
  look back. A new load grows back on the rope 4 s later.
- `studies/snag_study.gd`: extends the character study. It lays the
  stations, checks the grab (the load within 1.05 m of his body), adds a
  small yank in the air, carries the part overhead until he lands, then
  plays the pickup twist. The "Got it" pop and the pass countdown use the
  moments HUD.
- `tests/test_snag.gd`: checks that the loop closes and dips, the load swings
  off plumb and hangs out of the turns, a grab detaches it and lurches the
  plane, and the load respawns.

## What feels weak (expected; nothing seen rendered yet)

- None of this has been looked at in a window. The plane's scale, the rope's
  thickness and readability, and whether the swing reads are all unjudged.
- The plane figure is scaled 2.5x so the load reads, which makes the pilot in
  it a giant. Its scarf is hidden because it trails from the unscaled frame.
- The plane's speed varies round the ellipse (about 9 m/s at the ends,
  14.5 m/s over the pier), because the curve is driven by angle rather than
  by distance along it.
- The grab is a plain distance check: no hand reach, catch pose or rope
  pull. Falling "with it" is only a 30% yank of the plane's pace plus the
  part held overhead.
- The pier pass is short (the load is over the pier for about 0.35 s), so the
  timing may be too tight. The perch and terrace numbers come from the sim,
  not from playing them.
- The torn rope just keeps the same length. It doesn't fray or shorten.
- The load has no collision, so it can swing through the ledge if you lower
  the dip.

## Open questions

- Should the plane be the toy-sized figure, matching the game's own plane,
  with a bigger load instead?
- Should the grab be hands-only (a catch you aim) or the whole body?
- After a snatch, should he ride the load a moment, swung under the plane
  before it tears, rather than it tearing at once?
- Should the loop drift lap to lap (wind, a second pattern) once it's learnt,
  or stay fixed?
- For the later slung-load mechanic on the player's own plane: is this verlet
  rope (load heavier than the links) the right base, or a single pendulum?

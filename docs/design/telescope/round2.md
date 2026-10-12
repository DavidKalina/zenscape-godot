# The telescope, round 2

Playing round 1, the user said: "I can barely make it out because it's
binoculars. I feel like a telescope makes a lot more sense." So the
binoculars are now a brass spyglass, for the pilot and for the watcher.
Everything else from round 1 stays: the isle card from the ground, the
glints, the shuffle-only movement, the bindings, and the rules for when it
can be raised (docs/design/telescope/round1.md has them).

Branch `feature/telescope`. It's `study/watcher` (which holds
`feature/binoculars`) with `main` merged in. It isn't merged into main.

## What changed from the binoculars

- **The view** (`shaders/telescope_view.gdshader`):
  - It's one round lens, not two circles. Its radius is `LENS` = 0.66 screen
    heights, so it runs past the top and bottom of the screen and its
    sides curve in well short of the screen's edges. On 16:9 that's about
    69 % of the screen inside the lens. The binoculars' two circles came to
    about 57 %, less their wide dark shading at the rims.
  - Inside the lens there's a faint warm tint (5 %). A gentle vignette
    darkens the outer 0.26 screen heights, down to about half at the rim.
  - The rim is a thin, soft brass ring, lighter at the top than at the
    foot. Outside it the screen is dark.
  - Glints use `in_lens` (one circle) instead of `in_circles`.
- **The zoom** is now `ZOOM` 3x to 12x (it was 2x to 8x), and it starts at
  4x (it was 3x).
  - The lens fov is still `2·atan(tan(30°)/zoom)`: 4x is about 16.4°,
    12x about 5.5°.
  - The triggers run the zoom a bit faster (`ZOOM_RATE` 2.6 a second). The
    wheel step is still ×1.3 a notch.
  - At 12x the serpent 215 m off fills about half the lens, and its rune
    find is plainly a diamond in a ring.
- **The sway** is steadier: `SWAY` is 0.0025 rad (it was 0.0035). Look is
  still slowed by the zoom.
- **The spyglass** (`Telescope.make_glass`) replaces the binocular pair.
  - It has eight-sided (faceted) brass sections: a base with a leather grip
    band, a dark eyepiece with a bright ring, and two thinner draws, each
    with a bright lip. The last draw ends in the objective's rim.
  - It's about 0.17 m long collapsed and 0.33 m extended at the figure's
    size (`GLASS_SIZE` 1.3 over the model's 0.13 / 0.25 m).
- **The pose** (`Telescope.ARMS`, `lift_arms`, `hold`):
  - The arms are no longer symmetrical. Each arm has its own five angles,
    found by a headless search like round 1's:
    - The right mitt grips the base under his right eye, at about
      (0.06, 0.9, −0.14) m.
    - The left mitt steadies it from below, at about (−0.03, 0.86, −0.15).
    - His short arms reach no further forward than that.
  - The spyglass sits `GLASS_LIFT` over the right mitt and `GLASS_IN` in
    toward his middle, so its eyepiece covers his right goggle. It points
    along the look.
- **The watcher** calls the same statics (`make_glass`, `lift_arms`,
  `hold`, `extend`). His spyglass extends and collapses with his own raise
  (0.45 s), and the slide sounds play at his eye in 3D. His own pose
  constants and states are unchanged.

## The raise

- `RAISE` is 0.3 s up and down (it was 0.25).
  - The arms lift over the first 70 %.
  - The draws slide out between 30 % and 75 % (`SLIDE`, `extension(up)`):
    the first draw, then the tip, each easing out.
  - Lowering runs the same curve backwards, so it collapses as he lowers it.
- **Sound** (through the kit audio when it's there):
  - Raising: a cloth rustle, then a quick high swish as the draws start out,
    then a two-tick click (one low, one high) as they lock.
  - Lowering: a swish, then a softer tick as it shuts.
- In first person, the pilot's figure and his spyglass still hide past
  85 % of the camera blend (about `up` 0.73). So you mostly hear the slide
  and see the view narrow; the slide itself shows on the way up and down.
  The watcher shows all of it.

## Renames

| Was | Now |
|---|---|
| `scripts/binoculars.gd` (`Binoculars`) | `scripts/telescope.gd` (`Telescope`) |
| `shaders/binoculars_view.gdshader` | `shaders/telescope_view.gdshader` |
| `binoculars` action (pad.gd) | `telescope`, same bindings (right mouse, pad LB) |
| `binocular_finds` / `binocular_objective` | `telescope_finds` / `telescope_objective` |
| `Binoculars.spottable` | `Telescope.spottable` (kit_tokens.gd, watcher.gd) |
| `binoculars_allowed`, `script_binoculars`, `study.binoculars` | `telescope_allowed`, `script_telescope`, `study.telescope` |
| `_make_pair`, `.pair` | `make_glass`, `.glass` |
| `in_circles`, `CIRCLE` / `APART` | `in_lens`, `LENS` |
| `tests/test_binoculars.gd` | `tests/test_telescope.gd` (same checks; the look check is now at 3x and 12x) |
| `docs/design/binoculars/round1.md` | `docs/design/telescope/round1.md` (kept as history, with a note) |

The hints now say "telescope", and docs/gamepad.md has the new action and
the 3x to 12x range. The watcher's round 1 doc uses the new names.

## Captures

Windowed, `tools/capture_telescope.gd` (`Godot --windowed --path . -s
res://tools/capture_telescope.gd -- --no-title`), aqueduct isle with
`--watcher`, the serpent where it starts at the dip:

- `captures/telescope/watcher_spyglass.png`: the watcher from ahead and to
  the side, with the spyglass extended at his right eye, right mitt on the
  grip and left mitt under it.
- `captures/telescope/view_6x.png`: the pilot's view at 6x on the serpent,
  about 200 m off. Its runes are readable, and the find's glint is a small
  star on its crest.
- `captures/telescope/view_12x.png`: the view at 12x, about 215 m off. The
  find is clearly a rune diamond in its ring, riding the crest.

## Checks

- Headless import: clean.
- `zenscape.tscn --quit-after 300`, twice each: clean every time with
  `-- --no-title`, and clean every time with `-- --no-title --watcher`.
- `tools/run_tests.py --tests` test_telescope.gd, test_watcher.gd,
  test_ledger.gd, test_gamepad.gd: three runs, 4 of 4 pass each time.
  - On the last two runs, test_gamepad was flagged "pass with known engine
    error": the exit leak (4 resources still in use at quit) that the
    runner already knows. The first run was clean.

## What's weak

- **The pilot's own slide is barely seen.** His figure hides at 85 % of the
  blend, so in play the extension is mostly heard. A rendered look at the
  raise in motion (not a still) hasn't been done.
- **The pose was only checked from one angle.** It was judged from one
  still of the watcher, from in front and to the side. From behind or
  straight on, the left mitt may read as pressed to his cheek rather than
  under the tube.
- **His mitts are big and the glass is small.** The right mitt covers the
  base and the grip band, so the leather band hardly shows.
- **The pose doesn't follow pitch.** The arm angles are one fixed pose. The
  glass tilts with the pitch, but the arms don't, so looking well up or
  down may part the glass from the mitts (the watcher looks down 10 to 20°
  at the dip).
- **The far view is hazy.** At 200 m and beyond, the world's distance haze
  washes the lens view toward a pale beige. The lens tint adds a little to
  that. It still reads, but it isn't crisp.
- **The lens is cropped top and bottom.** It runs past the top and bottom
  of the screen, so on 16:9 it isn't a whole circle. That was chosen for
  more image (a whole circle could cover at most 44 % of the screen), but a
  full circle would read more like a spyglass.
- **The camera is at the middle `EYE`, not the right eye.** The view
  doesn't shift with the glass on the right eye. That's fine in play, but
  it isn't literal.

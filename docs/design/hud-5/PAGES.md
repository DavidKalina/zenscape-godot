# HUD 5: the almanac's pages

This is the in-game build of the two pages from Claude Design's "ZenScape HUD 5 Air"
(project `a0f03cdb-c2ea-4ac8-acf0-0b4614cdee5f`, folder
`design_handoff_lowpoly_linen_hud_5_air/`). The spec is `README.md`, sections B, E,
"Customise" and Motion, and `lowpoly.js` is the source of truth. Both are copied
here. The `.dc.html` reference was not available, so the layout calls it would have
settled are listed under departures below.

The pages open to the left of the almanac strip. The strip is `scripts/almanac.gd`,
on its own branch. The merge connects its `page_requested(page, row)` signal to `open(page, row)`.

## API (`scripts/almanac_pages.gd`, a Control)

| | |
|---|---|
| `setup(scene)` | Takes the scene holding `mood_look`, `_atmosphere` and `_celestial` (studies/cozy_worlds.gd). |
| `open(page, row := "")` | `page` is `"moods"` or `"customise"`. `row` is a Customise row (`season`, `time`, `weather`, `wind`, `rock` / `rock_type`) or a colour (`grass`, `c_grass`...). The page scrolls the row into view and lights it. A colour opens its swatches. |
| `close()`, `is_open()` | `closed` is emitted once per close. |
| `contains_pointer(p)` | True over the open page, in viewport pixels. |
| `strip_rect` | The strip's rect. Presses there never close the page. If empty, the design's column is used: the right 116 design px. |
| `handle_event(e)` | The page's input (`_input` calls it). Probes call it too. |

- **Placement.** The right edge is `RIGHT` = 116 design px from the frame's right edge, and the page is vertically centred. If it is taller than the frame less 24 px margins, it scrolls with the wheel.
- **Closing.** A press on the empty frame closes the page and is consumed, so it does not also reach the hand. Esc closes it too; in Mix, Esc goes back to the swatches first.

## The shared wind strengths

`scripts/mood_look.gd` `WIND_STRENGTHS` is the one table for both the strip's windsock and this page's Wind row:

| id | strength | droop |
|---|---|---|
| calm | 0.15 | 40° |
| light | 0.4 | 22° |
| brisk | 0.8 | 10° |
| gale | 1.3 | 0° |

- `strength` is the atmosphere's `strength`, matching the range of the sky's held sweep (`sky_wind.gd` `STRENGTH`).
- `droop` is lowpoly.js `WIND_DROOP`.
- `wind_strength(s)` and `wind_strength_id(s)` read the nearest entry.
- Wind pins like any control. The pin value is `"<id>@<degrees>"` (`wind_pin`, `wind_parts`), where degrees is `direction_angle`.

## Files

| File | What |
|---|---|
| `scripts/almanac_pages.gd` | The pages. |
| `scripts/mood_look.gd` | Adds `WIND_STRENGTHS` and the Wind pin. A pinned wind is applied after the weather, so living weather drifts from it. It survives mood changes and is cleared by Back to mood. |
| `scripts/hud_icons.gd` | One block at the end: `vignette_svg` and `vignette_texture` (lowpoly.js `vignette()`), plus `VIGNETTE_SIZES`. |
| `studies/cozy_worlds.gd` | `--pages-preview` (Moods) or `--pages-preview=customise` opens a page on start, and F8 reopens it. Nothing else is wired. |
| `tools/probe_almanac_pages.gd` | Headless checks, and it writes `/tmp/zs-hud/almanac-vignettes.png`. |

## Departures from the spec

- **The mood colours are the game's.** The cards take sky, glow and grass from `SceneLookPresets.look_document`, and the hour from the preset's `phase`. This world uses the origin snapshot `mood_look` keeps, or the live look before the first change. The lowpoly.js `MOODS` colours are not used. The titles and descriptions are the game's too.
- **Seeds.** This world is 23. The nine moods are 24–32 in `PRESETS` order, which is the order of the design's list.
- **The hour comes from the phase.** Night is before 0.25 or from 0.75 on. "Low" (dawn, golden hour, dusk) is before 0.31 or from 0.6. Everything else is "high". For example, Golden meadow's 0.36 draws a high sun, not the design's golden-hour sun.
- **The colours and swatches are mood_look's.** That is `COLORS`: Grass, Leaves, Rock, Earth, Water, Sky and Mist, each with its own six swatches. lowpoly.js `COLOURS` is not used. `mood_look.value` plays the part of `resolve()`.
- **An open colour** gets a full-width row under the pair it sits in, and the list stays visible. The design may instead replace the list.
- **Mix** adds a SWATCHES link as well as Esc, so the way back works with only a mouse.
- **Hue / Depth / Light** are HSV hue, saturation and value. While mixing, a grey keeps its hue.
- **Wind is not in `mood_look.CONTROLS`.** Adding it there would make the old drawers (`mood_panel`, `lantern_mood`) grow a row they cannot draw.
- **The dial is the ground from above, north up** (screen x is world x, screen y is world z). It is not turned with the camera. A dial drag applies directly with no fade, as the old picker drags do. A strength chip cross-fades like any other pin.
- **`open(row)`** lights the row with the hover patch, fading over 1.2 s, and scrolls to it only if it is out of view.
- **Header.** Customise's header reads `MOODS · <mood name>` on the left and `◌ BACK TO MOOD` on the right.
- **Switching pages** fades the new page's content in over the 250 ms open time.
- **Easing** is smoothstep, standing in for `cubic-bezier(.25,.1,.25,1)`, as 4c does.
- **Small caps are faked** (capitals at 10/13 of the size), as in 4c.
- **The knot's inset and drop shadows** are approximated: a drop circle and a shade arc.
- **The Unpin tooltip** is a small dark patch up and to the right of the knot.

## Unverified on screen

Only headless checks were run: the layout, hit tests and state, and the drawing code running without errors. Nobody has seen these on screen:

- the pages
- the cloth at 0.8
- the type sizes and fit
- the balanced card titles
- the grooves' gradients
- the knots and the tooltip
- the dial
- the slide and fade

Only the vignettes have been looked at, in `/tmp/zs-hud/almanac-vignettes.png`.

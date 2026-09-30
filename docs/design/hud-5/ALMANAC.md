# HUD 5: the almanac strip

This is the in-game build of the right-edge strip from Claude Design's "ZenScape HUD 5 Air" (project `a0f03cdb`, folder `design_handoff_lowpoly_linen_hud_5_air/`). It covers sections A, D and E's strip knots, plus the Motion table. The spec is `README.md` and `lowpoly.js`, both in this folder. The pages it opens (Moods, Customise) are a separate build, `scripts/almanac_pages.gd`, described in `PAGES.md`.

## What was built

`scripts/almanac.gd` mirrors the 4c tool roll (`scripts/tool_roll.gd`) on the right edge:
- It sits 24 px in from the right and is vertically centred, with 12/10 padding, 4 px gaps and 60 px pockets. The strip measures 80 × 361.
- It uses the same cloth, hem, shadow, stitched pockets, hover patch and tag type as the roll.
- The pockets, top to bottom:
  - **Mood**: the resolved look as a faceted vignette.
  - A double stitch.
  - **Time**, **Season**, **Weather** and **Wind**.

**Rest and reach.** At rest the strip shows 0.6 opacity and is tucked 6 px out to the right. It is reached (full opacity, no offset) in three cases:
- the pointer is past x 1260 of the 1440 frame, which is 180 design px from the right edge, the roll's `NEAR` mirrored;
- a page is open (`page_open`);
- the pointer is over the strip or its tag.

It uses the roll's timing tokens: reach 250 ms, recede 400 ms after a 300 ms hold. A drag in progress (`quiet`) never wakes it. The one exception is its own Wind drag.

**Pockets drawn as their gestures** (`hud_icons.gd`, in the "HUD 5 almanac icons" block; seeds 16–20):

| Pocket | Drawn as | Click |
|---|---|---|
| Time | Sun, or crescent moon by night | Day and night's home since the void's snap was cut (2026-09-30). `VoidSnap.snap`, the snap's instant cut, without the hand or its sound; pinned as `night` or `morning`. Shift-click steps the golden hours (dawn, midday, dusk, night), pinned by name. With `--void-snap` it is `hand_reach.fire_snap(step)` again. |
| Season | Plate from above in `SEASON_TINT`, with rim arc and bead | Next season, pinned |
| Weather | Snow globe | Next of `MoodLook.WEATHERS`, pinned |
| Wind | Windsock at its strength's droop (40°, 22°, 10°, 0°) | Next of Calm, Light, Brisk, Gale, pinned. Dragging across the pocket turns the prevailing heading by 1.5° per design px; on release it is pinned with the heading. |
| Mood | Vignette | `page_requested("moods", "")` |

A pinned pocket shows a 6 px cream knot, 5 px in from its top right, with its halo, drop and lower lip. It stays visible at rest.

**Tags.** Hovering a pocket shows the 4c tag on a strip of cloth to the LEFT:
- the lowpoly.js `ALMANAC` wording, for example "Wind · Brisk, from the south-east";
- under it, the whisper in Spectral 13 px, `#d6cbb2`.

The tag holds while the pointer crosses onto it. Clicking the tag presses the pocket and emits `page_requested("customise", row)`.

**Cues.** Each cue plays once per hover, per `CUES` and the Motion table, and nothing loops:
- **snap**: the other body, as a 520 ms hard cut;
- **turn**: −24° over 320 ms, back from 560 ms;
- **jiggle**: −9°, 7°, −4°, 0°, in 90 ms eased-out steps, pivoting at 50% 80%;
- **lift**: half droop, then level at 80 ms, half at 460 ms, rest at 540 ms, in hard steps.

**Whispers retire.** The almanac watches for the real gestures. The first time one happens, that pocket's whisper and cue retire for good. The tag stays.

| Pocket | Real gesture | How it is noticed |
|---|---|---|
| Time | None now: its line reads "shift-click for the golden hours" and retires at the first Shift-click (key `time_golden`). With `--void-snap`: "or click the sky", retired by the sky's snap | `hand_reach.snaps` goes up (the pocket's own snap is excluded) |
| Wind | The sky's held sweep | `SkyWind.sweeps` goes up |
| Weather | The shake | `snow_globe.shake_started` |
| Season | A rim spin that winds the world into another season | While `spin_time.winding`, the season quarter changes |

Retirement is saved in `user://almanac.cfg` under `[whispers]`, following `camera_rig.gd`'s `user://camera.cfg` hint. Probes and movie captures never write it. The design's `whispers` tweak is the `whispers` var.

## API

- `signal page_requested(page: String, row: String)`: `("moods", "")` from the Mood pocket or its tag; `("customise", "time"|"season"|"weather"|"wind")` from a tag.
- `want(on)`, `quiet`, `page_open`, `whispers`, `retired`, `retire(id)`, `whisper(id)`.
- `setup(scene, hand_reach)`.
- Hit tests: `pocket_at(p)`, `tag_at(p)`, `contains_pointer(p)`, `strip_rect()`, `pocket_centre(id)`.
- Presses: `press(p) -> bool`, `holding()`, `drag(p)`, `let_go(p)`, `click(id)`, `open_tag(id)`.
- The almanac joins the group `hud_piece`.

## Hooks in shared files

- `scripts/hand_materials.gd` changes:
  - it makes the almanac next to the roll in `MaterialsTrayLayer`;
  - `tray_under` includes it;
  - `press` offers it the press first, and takes the hold `"almanac"` for a Wind drag;
  - `drag` and `let_go` route that hold to it;
  - `step` calls `want`/`quiet` on it, and a hold of `"almanac"` is not quiet;
  - `drive_hand` floats the hand over the tray during that hold;
  - a stub, `_page_requested`, keeps `page_asked = [page, row]` until the pages are wired.
- `scripts/hand_reach.gd`: `"almanac"` is added to the two hold lists that route `drag` and `release` to the materials.
- `scripts/mood_look.gd`: the wind control is copied verbatim from `feature/hud5-pages` (`WIND_STRENGTHS`, `wind_strength`, `wind_strength_id`, `wind_pin`, `wind_parts`, `_apply_wind`), so the merge is identical. The strip drives the windsock through those helpers.
- `scripts/hud_icons.gd`: one block at the end of `_build` and file, "HUD 5 almanac icons". The pages branch also appends a HUD 5 block at the end of this file, so the merge will need both blocks kept.

## Departures from the README

1. **Strip height is 361 px, not "≈ 370".** It is 12 + 5 × 60 + 4 gaps + a 17 px stitch block with a 4 px gap each side. The divider's lines are 40 px wide and 4 px apart, centre to centre, as the roll's.
2. **Reach is measured as 180 design px from the right edge**, which is x > 1260 at 1440. On wider windows it stays tied to the edge.
3. **The Time pocket pins the hour.** Customise's Night or Morning is pinned after the snap. On a turning day that holds the hour, whereas the sky's own snap lets the day keep turning. The brief asked every click to tie a pin.
4. **With `--void-snap` the Time pocket calls `fire_snap`, so it also counts as a use of the sky's snap for the sky's hint line** (`uses["void"]`). It does not retire the almanac's own whisper.
5. **Cue during the snap at night.** At night the Time pocket shows the moon, so its cue swaps to the sun. The README only covers the day case ("swaps to moon").
6. **The Mood's tag opens the Moods page.** The Mood has no Customise row.
7. **Weather steps in `MoodLook.WEATHERS` order**, not the living weather's next sky that the W key uses.
8. **The vignette's glow is the look's `horizon` colour.** The look's `glow` is a dark warm tint.
9. **Sun height in the vignette comes from the sun's elevation**, not from the Time value. Night is below the horizon; the sun is low under 0.22. The seed is the mood's (23 for this world).
10. **The vignette is redrawn at most every 0.1 s** while the look changes, including during the 1.2 s cross-fade.
11. **The vignette's corner radius is 3 px**, which the README leaves open. Its edge and drop are drawn as flat rounded fills.
12. **Knot shadows are approximated.** The inset lip is a dark arc, and the drop is a disc 1 px below.
13. **The rest opacity applies to the whole strip, knots included.** Knots stay visible at rest, at 0.6.
14. **Wind strength can drift.** A pinned wind sets the air's strength and heading, and the drift starts from it. Living weather's later sky changes can still move the strength, as they do for a mood's wind.
15. **`vignette_svg` duplicates `hud_icons.gd`'s vignette** from the pages branch. Fold it into that one after the merge.
16. **The old M-key mood drawer is not hidden.** Under the hand scheme, M opens the Lantern shell's own mood orbs (`creation_palette.mood`). Replacing that belongs with the pages and needs M rewired to `page_requested`, so it was left alone.

## Checks

`tools/probe_almanac.gd` runs headless (82 checks):
- layout and hit tests;
- rest, reach, hold and recede;
- page-open reach;
- quiet during drags;
- the left tag and whisper;
- each cue plays once and stops;
- retirement, persisted across a new instance;
- `page_requested` from the Mood pocket and from tags.

In the game (`--modeless`), through the hand's own input path, each pocket changes the hour, season, weather, wind strength and heading, and ties a pin. A mood keeps the wind pin. The real gestures retire their whispers. The probe also writes the icon and vignette sheet to `/tmp/zs-hud/almanac.png`.

```
godot --headless --fixed-fps 60 --path . -s res://tools/probe_almanac.gd -- --modeless --no-title
```

**Unverified on screen:** only headless runs have been done. Nobody has yet seen the strip, the tags, the cues' motion, the knots or the vignette's legibility at 44 × 28 px.

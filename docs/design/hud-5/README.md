# Handoff: Low-poly on Linen HUD (5: the almanac, a home for the air)

## Overview
5 extends 4c with a third piece of the same linen for everything that changes the AIR, not the land.
- **Bottom bar = MATERIALS**: what you add. Unchanged.
- **Left = THE TOOL ROLL**: how you shape. Gains **Feather · Gust** and a small **foot** (Undo, Photo).
- **Right = THE ALMANAC**: moods, time, season, weather, wind. New.
- **One thing in hand** across both bars, as before. The almanac never holds anything; its pockets do things.

## About the Design Files
Design references made in HTML, not production code. Rebuild in the game's UI stack (Godot Controls drawn in code + one canvas shader for weave/noise, as 4c).
- `ZenScape HUD 5 Air.dc.html`: frames 1–6 at 1440×810 plus sheets (air control states, pins, colours + Mix, feather cursor sketches, new icons, mood specimens). Hover near any edge to reach for a piece; everything on the almanac is clickable.
  - Tweaks: `restOpacity`, `whispers` (gesture cues on/off), `lockHammer`.
- `lowpoly.js`: 4c generator + all new icon data, moods, customise lists, swatches, pin `resolve()`, `vignette()`, cues and `AIR_TOKENS`. **Source of truth.**
- `ZenScapeToolbar.dc.html`, `support.js`, `game-bg.png`: reference runtime and backdrop. 4c is untouched in `design_handoff_lowpoly_linen_hud_4c/`.

## Frames
1. All three at rest. 2. Almanac reached, moods page. 3. Customise: Season pinned, Grass swatches open. 4. Feather in hand with its lane sketch. 5. A whisper: hover on Weather. 6. Runner-up: the air printed on the sky.

## A · Where the air lives: the almanac (right edge)
- Mirror of the tool roll: right edge 24px in, vertically centred, padding 12px 10px, 4px gap, 60px pockets, ≈ 80×370px. Same cloth, hem, shadow, radii as 4c.
- Pockets top to bottom: **Mood** (vignette) ‖ **Time**, **Season**, **Weather**, **Wind**. Divider: two horizontal 40px dashed lines, 3px apart.
- Rest: 0.6 opacity, 6px out to the right. Reached (pointer x > 1260, or a page open, or a pocket hovered): opacity 1, no offset.
- Pages open to the LEFT of the strip, 10px gap (`right: 116px`), vertically centred. They may overlap the plate's far right edge, never its middle or front edge. Clicking the empty frame closes a page; so does `Esc`.
- **Runner-up (frame 6): type printed on the sky**, top right, 0.82 opacity, no cloth. Quietest of all, but it loses contrast over First snow / Alpine morning, and has nowhere to hang swatches, knots or a vignette. Kept as a possible "photo mode" readout.

## B · Moods are a place (a page of specimen cards)
- Mood pocket → the **Moods page** (320px). Header: MOODS (hairline) · CUSTOMISE link.
- **This world** row first, once anything differs from the made look: 56×35 vignette + caps + Spectral line.
- 3×3 grid of **specimen cards**: 78×49 faceted vignette (sky, horizon glow, slab, sun/moon), stitched inside at 2px, title below in 12px small caps (2 lines allowed, balanced).
- Chosen card sits in the pressed patch (4c Held); hover = half patch. Foot: hovered (else current) mood's title + Spectral 15px description.
- Choosing cross-fades the world over 1.2s (unchanged). Pinned values survive.
- The strip's Mood pocket always shows the current resolved look (pinned Sky / Grass colours included).

## C · Wind: held for gusts, placed for the prevailing wind
- **Feather · Gust** (seed 15, tint `#cbb994`) joins the tool roll after a divider, below Hammer. It follows one-thing-in-hand. Size pips set the **lane width 20 / 34 / 52px**.
- Cursor (4b rules): feather at 48px, up-right of the hotspot, tilted −18°. Ground mark `rgba(255,250,240,.85)`, dashed 6/6:
  - Swipe on and let go: **a lane**, two dashed edges following the swipe, fill `.07`, no arrowheads.
  - Hold still 400ms: **a burst ring** growing to 1.5× lane width while held; releases outward.
  - At rest: only a 7×3.5 dashed hotspot ellipse.
- The **prevailing wind** stays a sky gesture and gets the almanac's **Wind** pocket (a windsock: droop = strength, 40° / 22° / 10° / 0°). Click steps Calm → Light → Brisk → Gale; drag on the pocket turns the direction. Also a Wind row in Customise with a 22px stitched direction dial.
- Sky gestures (swipe for a passing gust, drag from sky onto land to pick up wind, press-pull-hold) still work. Dragging from sky onto land now puts the Feather in hand, visibly pressed in the roll.

## D · Gesture twins (teaching without hand-holding)
Each pocket is drawn as its gesture and does what the gesture does when clicked. Hover shows the 4c side tag (to the left) plus one Spectral 13px line in `#d6cbb2`, and plays a **one-shot** cue. Nothing loops. Once the player has performed the real gesture once, that pocket's whisper line and cue retire for good (the tag stays).
| Pocket | Drawn as | Click | Whisper | Cue |
|---|---|---|---|---|
| Time | sun / crescent moon | day ↔ night | or click the sky | swaps to moon, 520ms, hard cut |
| Season | the plate from above, season-tinted, with a rim arc + bead | next season | or spin the plate by its rim | turns −24° (320ms), back at 560ms |
| Weather | snow globe | next weather | or shake the plate | jiggle −9° / 7° / −4° / 0°, 90ms steps, pivot 50% 80% |
| Wind | windsock | next strength; drag turns | or press and pull in the sky | sock lifts to level and settles, 540ms |
| Mood | vignette | opens the page | (none) | (none) |
Clicking the tag itself opens Customise at that row and presses the pocket.

## E · Pins: a knot in the thread
- Setting any Customise value (or clicking a twin pocket) **ties a knot**: 7px cream dot `#e3d7bd`, `inset 0 -1px 0 rgba(26,20,14,.35), 0 1px 0 rgba(12,9,5,.3)`, halo `0 0 0 3px rgba(227,215,189,.14)`, left of the row label.
- The pinned strip pocket shows a 6px knot at its top-right, 5px in, visible even at rest.
- Knot hover: halo 5px, tooltip "Unpin". Click unties; the row returns to the mood's value over the 1.2s cross-fade, a dashed ghost knot fades out over 400ms.
- **Back to mood**: caps link at the Customise header's right, shown only while any knot exists, with a 5px dashed ring glyph. Clears all.
- Model unchanged: `value = pins[key] ?? mood[key]` (`resolve()` in lowpoly.js).

## Customise (page, 360px)
- Top: MOODS link + current mood name; a row of 10 mini vignettes (22×14 in 3px pressed/hover patches) to switch mood without leaving.
- Rows (label column 64px): Season, Time (incl. Turning day), Weather, **Wind** (new), Rock. Chips: 24px tall, 12.5px small caps .12em, 1px dashed `rgba(227,215,189,.22)`, radius 5. Chosen = 4c pressed patch, no stitch. Hover = 4c hover patch.
- **Colours**: two-column list, each a label + 30×16 stitched flat chip of the current value. Clicking opens that row full width: six 24×20 swatches (stitched 2px inside, `rgba(255,250,240,.35)`), chosen in a pressed pocket, then **Mix**.
- **Mix (one level down)**: replaces the row with three 12px stitched grooves (Hue, Depth, Light), linear gradients, a 14px cream knot rides each. Esc returns to swatches.

## F · Undo and Photo: the tool roll's foot
A separate small piece of the same cloth, 8px under the roll, same 80px width, radius 10, hem inset 4 / radius 7. Two 32px slots, 24px icons: **Undo** (seed 21, curled arrow) and **Photo** (seed 22, camera). Hover tag to the right, as the roll's. Whispers: "or Cmd Z", "the cloth steps out of the shot". No badges or counts. Photo hides all three pieces for the shot.

## Motion
| What | Duration | Easing | Delay |
|---|---|---|---|
| Piece reached (all three) | 250ms opacity + transform | `cubic-bezier(.25,.1,.25,1)` | 0 |
| Piece recedes | 400ms | same | 300ms |
| Page open / close | 250ms opacity, 6px slide from the strip | same | 0 |
| Pocket / chip hover, press | 150ms background + shadow | linear | 0 |
| Mood cross-fade | 1200ms (unchanged) | engine | 0 |
| Weather jiggle | 4 × 90ms steps | ease-out | 0 |
| Season turn | 320ms out, back at 560ms | 4c ease | 0 |
| Time snap | hard cut, 520ms hold | none | 0 |
| Wind lift | 80ms up, 380ms hold, 80ms down | step | 0 |
| Ghost knot | 400ms fade | 4c ease | 0 |
No overshoot, bob or loop anywhere.

## New tokens (see `AIR_TOKENS`)
- Page cloth `rgba(98,88,74,.8)` (4c bar is .76; pages sit over brighter sky)
- Knot `#e3d7bd` · knot halo `rgba(227,215,189,.14)` · whisper ink `#d6cbb2`
- Chip stitch `rgba(227,215,189,.22)` · section rule `1px dashed rgba(227,215,189,.3)`
- Swatch stitch `rgba(255,250,240,.35)` · swatch edge `inset 0 -1.5px 0 rgba(26,20,14,.25), 0 0 0 1px rgba(20,14,8,.25)`
- Vignette stitch `1px dashed rgba(255,250,240,.3)` inset 2px · vignette edge `0 0 0 1px rgba(20,14,8,.3), 0 2px 0 rgba(12,9,5,.22)`
- Ground mark `rgba(255,250,240,.85)` · lane fill `rgba(255,250,240,.07)` · dash 6/6
- Season tints: Spring `#93b86c` · Summer `#6c9a4a` · Autumn `#c27c3e` · Winter `#cfd8de`
- Seeds: 15 Feather · 16 Sun · 17 Moon · 18 Plate · 19 Globe · 20 Sock · 21 Undo · 22 Photo · 23–32 moods (sky s, glow s+40, land s+80)

## Departures from 4c (named)
1. A third piece (almanac) on the right edge; reach trigger x > 1260.
2. Tool roll gains a 6th tool, Feather · Gust, after a divider; roll ≈ 80×480px.
3. New small cloth piece: the roll's foot (Undo, Photo). 32px slots, below 4c's 60px.
4. Pages: first HUD surfaces larger than a bar; cloth .8 opacity instead of .76.
5. Side tags on the almanac read to the LEFT and may carry a second Spectral line (the whisper).
6. Chip text 12.5px small caps at .12em (4c tags 13px at .22em) so rows fit.
7. First use of flat colour (swatches, vignette disc, side face); always stitched, never glossy.
8. One-shot hover cues on four pockets. 4c had no hover motion.
9. Wind added to Customise (strength chips + direction dial). Not in the old drawer.
10. Moon crescent and undo arrow are polygons sampled in code (no masks), still clipped facets.
11. Mood descriptions other than "Clear blue air. Sunlit stone." are placeholder copy.

# Creation shell: three UI directions

Branch `feature/ui-mockups`, 2026-09-27. These are design mockups, not an implementation.

> **Decision (round 2):** the user picked Lantern's look, laid out like Super Mario Maker 2's editor. That direction is **B2 · Lantern Maker**, at the end of this file. The round-one recommendation below is kept for the record.

The brief, in the user's words: the current glass UI is "clean" and "pretty minimalistic, but it just feels like a web UI overlaid on a game. It doesn't feel like a video game UI." It needs more glyphs and a more attractive look.

Each direction covers the same pieces:

- The bottom creation palette:
  - Land, Water, Meadow, Forest and Path.
  - Brush size and strength.
  - Look, Photo and the new Mood.
- Craft and World at the top right.
- The brush cursor in the world.
- The hint line.
- The Land forms sub-row: Hill, Alpine peak, Ridge, Mesa and Volcanic cone.
- The Mood swatch row, with its customise drawer (season, plus grass, rock and water colour chips).

## Files

| Direction | Full frame, creating | Full frame, Mood open | Close-up sheet | Glyphs |
|---|---|---|---|---|
| A Field Journal | `mockups/field-journal/field-journal-create.png` | `…-mood.png` | `…-sheet.png` | `glyphs/field-journal/` |
| B Lantern | `mockups/lantern/lantern-create.png` | `…-mood.png` | `…-sheet.png` | `glyphs/lantern/` |
| C Toy Box | `mockups/toy-box/toy-box-create.png` | `…-mood.png` | `…-sheet.png` | `glyphs/toy-box/` |

**Full frames (1440×900):**

- The frames are composited over real frames of `captures/phase3-slices-2-5.mp4`:
  - The creating frame uses the 62 s frame (forest and pond).
  - The Mood frame uses the 44 s frame (island in mist).
- Each frame is cropped above the old palette and scaled up, so the old UI does not show through.
- The small white ring on the pond and the pond outline are in the film itself. They are not part of any direction.

**Sheets:** each sheet shows:

- The glyph set.
- Button states: idle, hover and selected.
- The size and strength widget at three settings.
- The "while painting" state.
- The forms row.
- The cursor at small and large sizes.
- The mood row and the open drawer.
- The hint line.

**Rebuilding:** run `python3 tools/ui_mockups/build.py [field-journal|lantern|toy-box] [--create|--mood|--sheet]`.

- The build is headless. It uses ffmpeg to take the frames and headless Chrome to rasterise the HTML, so no window opens.
- Fonts are fetched once to `/tmp/zs-ui-mockups/fonts` and are not committed.
- The PNGs were force-added, because `/docs/**/*.png` is normally ignored.

**Glyphs:** every glyph is a hand-authored 48×48 SVG. They are ready for Godot:

- Plain paths, circles and ellipses.
- Hex colours, with `fill-opacity` / `stroke-opacity` for alpha. There is no `rgba()`.
- No gradients, filters or dash arrays.

All 67 glyphs were loaded through `Image.load_svg_from_string` in a headless Godot 4.7.2. All of them load, and none import as black. Nobody has yet compared them by eye against the Chrome rendering, so a partly vanished path would not have been caught.

The shared constants (brush order, forms, seasons and mood colours) are in `tools/ui_mockups/common.py`. The mood colours come from `scripts/scene_look_presets.gd`. The ground colours for Alpine morning, First snow and Nordic night are guesses, because those presets do not set grass.

---

## A · Field Journal

**Pitch.** The world is painted and the UI is the painter's sketchbook.

- **Palette.** A torn strip of watercolour paper, taped to the bottom of the screen with washi tape. Each tool has its own hand-inked glyph.
- **Selection.** Picking a brush blooms a watercolour wash behind its glyph, in the brush's colour: ochre for Land, teal for Water, sage for Meadow, pine for Forest and sand for Path. A pencil underline sits under the name.
- **Size and strength.** Shown as an ink well. The ring's diameter is the brush size, and the ink level inside it is the strength.
- **Land forms.** They sit on a smaller slip taped above Land.
- **Moods.** Tiny painted postcards: sky, sun, far hill, near ground and a sliver of water, in each preset's own colours.
- **Craft and World.** Cloth bookmark ribbons that hang from the top edge.
- **Cursor.** A pencil compass circle drawn on the ground, with a paper tag showing the form in hand.

References: the journal in *Alba: A Wildlife Adventure*, Tiny Glade's warmth, and the sketchbook menus in BotW.

**Materials.**

- Cream paper (`#f2e8d3`) with fibre noise and deckled, torn edges.
- Sepia ink (`#3a2e24`) at 2.2 px, with round caps and a slight hand wobble.
- Transparent watercolour washes with darker edges.
- Kraft washi tape.
- Madder (`#a65a4b`) and indigo (`#4d6283`) cloth ribbons.
- A soft two-layer drop shadow, so the paper sits just above the world.

**Typography.**

- [Fraunces](https://fonts.google.com/specimen/Fraunces) (SIL OFL) in italic, with `SOFT 100` and `WONK 1`, for labels and the hint.
- Newsreader and Spectral already ship in `assets/fonts` and would be a zero-new-files fallback, but Fraunces's soft wonk is what makes it feel hand-lettered. A static italic cut subset to Latin should be well under 100 KB (not measured).

**Motion.**

- **Hover.** The glyph tips 4° and rises 2 px (0.12 s, ease-out back). A pencil underline draws left to right (0.18 s).
- **Select.** The wash blooms from the glyph's centre: its scale goes 0.6 → 1.05 → 1 and its alpha goes 0 → 0.55 (0.35 s). The previous wash fades as if drying (0.4 s). The glyph gives a small ink "tap", squashing to 0.94 for 60 ms.
- **Size and strength.** On [ ] the ring redraws at its new size, and the ink level sloshes (a damped sine, 0.5 s).
- **Forms slip.** When Land is picked, or 1 is pressed again, the slip slides up from behind the strip and rotates into place (0.3 s). It tucks back when another brush is picked.
- **While painting.** On stroke start the strip slides 70 px down behind the screen edge (0.25 s). Only a torn tab with the held glyph and its well stays. It returns 0.6 s after release.
- **Cursor.** The compass ring's gap rotates slowly (one turn every 8 s). The paper tag swings on its string when the pointer moves quickly.
- **Mood.** The postcards deal in from the left, 30 ms apart, each landing with a 3° random tilt. The drawer card slides out from behind the row with a paper rustle.
- **In and out.** Photo mode pulls the paper away along the tape (0.3 s). Look collapses the strip to its tab.

**Godot mapping.**

| Element | Godot |
|---|---|
| Strips, slips and cards | Deckle-edged paper PNGs as `StyleBoxTexture` (nine-patch margins about 12 px), or one `NinePatchRect` per piece |
| Tape and ribbons | `TextureRect`s |
| Glyphs | SVG `Texture2D`s on `TextureButton` / `Button.icon`. Ink colour is baked in; tint with `self_modulate` if needed. Ribbon glyphs have `-light` variants |
| Wash behind the selected glyph | `glyphs/field-journal/wash.svg` (white, `fill-opacity`), modulated to the brush colour and scaled by a Tween. A few rotated copies keep it from repeating |
| Ink well | `TextureProgressBar` with `FILL_BOTTOM_TO_TOP` (the wash is the progress texture and the ring is the over texture), scaled by size |
| Pencil underline | A `Line2D`, or a small SVG revealed with `region_rect` |
| Cursor | A ground decal or projected quad with a small ring shader (arc gap, ticks, pale under-stroke) |
| Paper tag | A `Sprite3D` billboard, or a screen-space `TextureRect` that follows the unprojected point |
| Mood postcards | A clipped `TextureRect` per card, with a small shader that draws the sky, sun disc, two hill bands and water from the preset colours. No `SubViewport` needed |

**Strengths.**

- The strongest link to the "paint a world" metaphor.
- The mood postcards are the most evocative of the three mood rows.
- Opaque paper reads on every mood, including First snow and Nordic night.

**Risks.**

- Paper and tape can become twee if they are overdone. Keep one strip, one slip and no more props.
- The italic is less legible than a sans at 12 px.

---

## B · Lantern

**Pitch.** No panels at all.

- **Glyphs.** Thin luminous line glyphs hang in the air along a gentle arc, joined by a dotted "constellation" thread, over a soft darkening at the bottom of the screen.
- **Selection.** The held brush glows in its own colour, inside a halo. A ring around it widens with brush size, and five motes on the ring's arc light up for strength.
- **Land forms.** When Land is in hand, the forms fan out above it like petals.
- **Moods.** Glass orbs, each holding a tiny sky, horizon and ground.
- **Customise.** The drawer is a blurred veil (the existing `editor_glass` blur).
- **Cursor.** A ring of motes that brighten toward the viewer, with a thin beam of light at its centre.

This is the "spirit" direction. Its references are Journey, Sky: Children of the Light and the minimal Sheikah-slate HUD in BotW. It is the least UI on screen, and it disappears while you paint.

**Materials.**

- Warm white light (`#fbf6ea`) with an additive glow.
- Brush-tinted halos: straw for Land, ice for Water, lime for Meadow, mint for Forest and blush for Mood.
- A radial dark vignette behind the arc for legibility.
- Glass orbs with inner shading.
- The existing blurred glass for the one panel (the drawer).

**Typography.**

- [Cormorant Garamond](https://fonts.google.com/specimen/Cormorant+Garamond) (SIL OFL), SemiBold, in small caps spaced 0.2–0.32 em.
- It is used only for names on hover and selection, and for the hint. A static SemiBold cut subset to Latin should be well under 100 KB (not measured).

**Motion.**

- **Idle.** Each glyph drifts ±1.5 px vertically on its own slow sine (3–5 s, out of phase), so the arc breathes.
- **Hover.** The glyph lifts 3 px, a small halo breathes in (0.2 s), and its name fades up in small caps.
- **Select.** The halo swells (scale 0.7 → 1.1 → 1, 0.4 s) and tints to the brush colour. The other glyphs dim to 60%. The size ring draws around the glyph (0.3 s), and the motes kindle one after another (40 ms apart).
- **Size.** On [ ] the ring eases to its new radius, and a tiny spark runs round it. On Shift [ ] one mote kindles or gutters.
- **Forms fan.** The forms bloom out along their arc from behind the Land glyph, each 30 ms after the last (0.3 s). A dotted thread links each form to Land.
- **While painting.** Everything except the held glyph fades to 0 (0.2 s). The held glyph sinks to a small lantern at the bottom edge and pulses softly with each dab.
- **Cursor.** The motes orbit slowly. When a dab lands they puff outward and settle, and a few motes rise up the beam.
- **Mood.** The orbs rise out of the Mood glyph and settle along their arc. Hovering an orb previews its sky tint as a faint screen wash.

**Godot mapping.**

| Element | Godot |
|---|---|
| Glyphs | White SVG `Texture2D`s on `TextureButton`s, each with a second, blurred copy underneath (`CanvasItemMaterial` blend `ADD`). `glyphs/lantern/halo.svg` is a stepped-opacity halo that imports cleanly; a `GradientTexture2D` (radial) also works |
| Tint | `modulate` |
| Arc layout | A small custom `Container` (a `Control` that places children on a curve). The thread is a `Line2D` with a dotted texture |
| Vignette | One `TextureRect` with a radial `GradientTexture2D` |
| Size ring and motes | `_draw()` on a `Control` (`draw_arc` plus `draw_circle`) |
| Cursor | Ground shader, or `GPUParticles3D` constrained to an ellipse, with an additive beam quad |
| Mood orbs | A `TextureRect` with a tiny shader (vertical sky → glow → ground bands, rim light) |
| Drawer | The existing `editor_glass.gdshader` panel |

**Strengths.**

- The least on screen.
- The most "spirit" feel, and serene.
- Cheap to build.
- It keeps the current glass for the one panel.

**Risks.**

- It is the closest to what is there now: thin lines in circles. The user may still read it as "clean web UI", only glowing.
- White-on-fog legibility is weak on bright moods such as First snow and After the rain, even with the vignette. The mockup shows this over the misty grass.
- It has the least "things to touch" feel.

---

## C · Toy Box

**Pitch.** Every tool is a painted wooden token you can pick up.

- **Tray.** The palette is a chunky wooden tray with a warm grain and a dark cartoon outline.
- **Brushes.** Each brush is a round, painted token with a visible side.
- **Selection.** The selected token pops up with a cream collar and a name pill.
- **Size and strength.** Size is a painted dot that grows in a carved well. Strength is five pegs that fill from the bottom.
- **Land forms.** Five little clay-model tiles on a shelf: a green hill, a grey alpine peak with snow caps, a sage ridge, a striped terracotta mesa and a smoking cone. The chosen tile carries a gold tick.
- **Moods.** Round painted "candies" (sky, sun, hill and water). The customise drawer is an actual wooden drawer with a knob. It holds four season tokens and three paint jars (Grass, Rock and Water) filled with the mood's colours.
- **Craft and World.** Round wooden coins at the top right.
- **Cursor.** A stitched cream ring on the ground, with a pin marker on a stick that shows the form in hand.
- **Hint.** A speech bubble that rides beside the cursor instead of sitting at the bottom of the screen.

References: Animal Crossing, Townscaper, Tiny Glade's soft buttons, and Mario Odyssey's snappy menus.

**Materials.**

- Wood: `#e6c493` → `#d2a870`, with fine grain stripes.
- A 2.6 px warm dark outline (`#4a3829`) on everything.
- Painted token colours: Land `#d9a764`, Water `#62b0cb`, Meadow `#9ccb66`, Forest `#4f9a67`, Path `#d69570` and Mood `#e89bb0`. Each token has a side 28% darker.
- Cream (`#fff6e3`) glyph faces, pills and bubbles, with a solid drop "side" instead of a blur shadow.

**Typography.**

- [Fredoka](https://fonts.google.com/specimen/Fredoka) (SIL OFL), SemiBold, for pills, the bubble and key caps.
- Nunito, which already ships in `assets/fonts` as a variable font, is a good zero-new-files fallback at weight 700–800.
- A static Fredoka SemiBold subset to Latin should be well under 100 KB (not measured).

**Motion.** This direction has the most motion. It is the one that meets the "Mario Odyssey idle" polish bar.

- **Hover.** The token hops 4 px and tips 6° (0.1 s up, 0.18 s settle with overshoot). Every token gets a soft wooden "tok" sound.
- **Select.**
  - Anticipation: the token squashes to scale (1.08, 0.9) for 60 ms.
  - Pop: it rises 10 px with a stretch of (0.94, 1.08), then settles with overshoot (0.3 s).
  - Collar: the cream collar pops (scale 0 → 1.1 → 1).
  - Name pill: slides down from under the token.
  - Previous token: drops back into the tray with a small bounce.
- **Size and strength.** The dot in the well grows or shrinks with a springy overshoot. Each strength peg clicks in with a 3 px drop.
- **Forms shelf.** It slides up out of the tray, and each tile hops into place in turn (25 ms apart). The gold tick stamps in with a squash.
- **While painting.** The tray sinks below the screen edge (0.22 s, ease-in back). Only the held token and its well ride up on a stub. On release the tray bounces back.
- **Cursor.**
  - The marker bobs on its stick (a 1.6 s sine).
  - On stroke start it squashes into the ground, and the ring's stitches spin with the drag speed.
  - On release it springs back up.
  - The bubble follows with a small lag (spring).
- **Mood.** The candies roll in from the Mood token across the shelf. The drawer slides out with a knock, and its jars fill up to the new colour when you pick a mood.
- **In and out.** Photo lifts every piece off-screen upward, as if the tray were picked up. Look slides the tray down to its stub.

**Godot mapping.** This is the cheapest of the three to build, because almost everything is a `StyleBoxFlat`.

| Element | Godot |
|---|---|
| Token | `StyleBoxFlat`: full corner radius, 2.6 px border, `shadow_color` at the dark side colour with `shadow_offset` (0, 5) and `shadow_size` 0. The glyph goes on top as the button icon. `token-face.svg` and `token-side.svg` are provided if a textured version is preferred |
| Selected collar | A second `StyleBoxFlat` ring behind the token, or `expand_margin` plus a border |
| Tray, shelf and drawer | `StyleBoxTexture` over a tiling grain texture, with a `StyleBoxFlat` border and side drawn beneath it (two `Panel`s) |
| Pills, bubble and key caps | `StyleBoxFlat` with a solid `shadow_offset` |
| Pegs and well | `StyleBoxFlat` circles. The well's inner shadow is a small radial texture |
| Glyphs | Multi-colour SVGs on `TextureButton` / `Button.icon`. Do not modulate them; the colours are part of the drawing |
| Squash and stretch | `Tween`s on `scale` and `position`, with `pivot_offset` at the token's base |
| Cursor | Stitched-ring decal shader on the ground, plus a `Sprite3D` billboard marker and a `Line3D`-style stick (a thin quad) |
| Bubble | A `Control` that follows the unprojected cursor point with a spring |
| Mood candies | A `TextureRect` with a small shader (sky, sun disc, one hill curve, water) inside a circular `StyleBoxFlat` |

**Strengths.**

- The most unmistakably "video game". It answers the brief most directly.
- Opaque, outlined pieces read on every mood.
- The motion vocabulary (pop, squash and hop) is exactly the polish bar the user has set for animation.
- The contextual hint bubble removes the bottom text line.

**Risks.**

- It is the loudest on screen, and could feel toy-like or childish next to the serene, misty diorama. Two mitigations:
  - Keep the dark outline warm and thin (2–2.6 px) and the paint colours muted, as mocked up.
  - Sink the tray whenever a stroke is in progress.
- Wood grain must stay subtle so it does not fight the faceted ground.

---

## Recommendation

**Go with C, Toy Box, and borrow two things from A.**

C best answers what the user actually said: "it doesn't feel like a video game UI". Its tokens, tray and pop-up selection read as a game at a glance. Its motion language matches the Mario Odyssey idle bar set for the creatures. It stays legible on every mood from Nordic night to First snow. It is also the cheapest to build, because `StyleBoxFlat` with a solid shadow offset gives the token look with no textures at all.

Borrow from A:

1. **The painted-postcard idea for moods.** The candies already use it. Keep the sky, sun, hill and water composition.
2. **A's restraint:**
   - Labels appear only on hover and selection.
   - The tray sinks while painting.
   - Hints ride on the cursor rather than filling a bottom line.

If the user finds C too toy-like, **A** is the fallback. It is equally legible and more "artful", at the cost of more custom art (the paper textures) and less punchy motion. **B** is worth keeping only for its cursor (the mote ring with a beam), which would also suit C's world marker at night. As a whole direction, B is too close to the current look to fix the complaint.

## Open questions for the user

- **Outlines.** Should the outlines be chunky (as mocked up) or hairline? Chunky reads as a game; hairline reads as more grown-up.
- **Hint placement.** Should the hint ride beside the cursor (C) or sit in a bottom line? And should it disappear for good after the first few strokes?
- **Forms row.** Should it open automatically when Land is picked, or only on a second press of 1 or on hover?
- **Sound.** Each direction implies its own set: pencil and paper for A, chimes for B, wooden "tok" for C. Is it worth a pass?

---

## B2 · Lantern Maker (round 2, the chosen direction)

The user's words: "Lantern aesthetic is what I'm going for, but with more of a Mario Maker layout. Layout is a bit rough in the mockups. But I like this."

B2 keeps Lantern's visual language:

- Thin luminous line glyphs.
- Halos tinted to the brush.
- Dotted threads.
- The ring-of-light cursor.
- Cormorant small caps.

It rebuilds the layout on Super Mario Maker 2's editor: parts along the top, hand tools down the left, the world down the right, and one big "play" button, which here is Photo.

**Files** (`docs/ui/mockups/lantern-maker/`):

| File | Shows |
|---|---|
| `lantern-maker-create.png` | Main view, 1440×900: Land in hand with the forms wheel open |
| `lantern-maker-create-1080.png` | The same view at 1920×1080 (UI scale 1.2) |
| `lantern-maker-mood.png` | Mood open: orbs pour out of the right column, with the customise veil beside the chosen orb |
| `lantern-maker-paint.png` | Painting: the UI recedes while you drag |
| `lantern-maker-snowtest.png` | Main view over a washed-out, near-white frame, standing in for First snow in fog |
| `lantern-maker-sheet.png` | Glyph set, slot states over grass and over snow, the Undo wisp's three frames, the forms wheel, cursor sizes, hand modes, mood orbs, the veil, Photo, and the scrubber and hint |

The glyphs are in `docs/ui/glyphs/lantern-maker/`. The set is the Lantern set plus:

- `paint`, `lower`, `grab` and `undo` (the wisp).
- `slot-empty`, for future brushes.
- `underglow`, the legibility plate, drawn as stepped circles with no gradient.

All 27 glyphs load in headless Godot 4.7.2 through `Image.load_svg_from_string`, and none import as black. They use no `rgba()`, gradients, filters or dash arrays.

### Layout

All numbers below are design units at 1440×900.

- **Grid.** The base unit is 8. Every slot is 56 (the hit target, above 44), with a 16 gap, so slots sit on a 72 pitch. The screen margin is 24.
- **Groups.** Each group is anchored to an edge. The whole UI scales by `min(W/1440, H/900)`: 1.0 at 1440×900 and 1.2 at 1920×1080.

```
 +------------------------------------------------------------------------------+
 |              .---------------------------------------------.                 |  top-centre, y 20
 |              | (LAND)  water  meadow  forest  path   o  o  o |  parts bar     |  slots 56, pitch 72
 |              '--+------------------------------------------'                 |  o = future slots
 |          hill \ | / volcanic cone                                            |
 |       (ALPINE)  ridge  mesa         <- forms wheel: arc under the held part    |
 | .---.                                                               .---.    |
 | |PNT|  paint                                                        |MOO|    |  mood
 | |OTH|  other way               centre stays clear                   |WLD|    |  world
 | |LOK|  look / grab                                                  |CRF|    |  craft
 | |---|                         . ring cursor .                       '---'    |  right-middle
 | |UND|  undo (the wisp)                                                        |
 | '---'  left-middle                                                  .----.   |
 |                    --*----*----(o)----*----*--   season scrubber     |PHOT|   |  Photo, 84
 |            DRAG raise land . RIGHT DRAG other way . [ ] size         '----'   |  bottom-right
 +------------------------------------------------------------------------------+
                   bottom-centre: scrubber (y -58) + hint (y -24)
```

- **Parts bar** (top centre).
  - Five brushes and three empty dotted slots for future brushes, on a 600 × 80 plate whose top edge is 20 from the screen top.
  - The brush in hand has a tinted halo and a double ring.
  - Land also carries a small badge showing the form in hand, the way Mario Maker shows a part's variant.
  - **Forms wheel.** Holding Land, or clicking it again while it is in hand, swings the five forms down on an arc (radius 146, from 150° to 30°), joined to Land by dotted threads. Release over a form to pick it, as with Mario Maker's parts wheel.
- **Hand modes** (left middle).
  - Paint, Other way (lower or erase), Look (grab and orbit), then a hairline divider and Undo.
  - An 80-wide pill plate, vertically centred.
  - Labels appear to the right on hover or for the mode in hand.
- **The Undo wisp.** A small lantern spirit whose tail curls into an undo arrow. It is Undodog's counterpart:
  - It bobs and blinks at idle.
  - On press it hops and its tail whips round.
  - When the undo lands it spins back and sheds sparks.
  - Redo is Shift-click, and the wisp spins the other way.
- **World column** (right middle).
  - Mood, World and Craft, on the same grid and plate as the left column, so the two columns mirror each other.
  - **Mood** pours nine orbs down a crescent that bows toward the screen centre. The chosen orb sends a thread to the customise veil, which is titled with the mood's name and holds the season glyphs plus the grass, rock and water chips.
- **Photo** (bottom right). The big 84 button with a double ring and a warm halo, in the spot Mario Maker gives Play.
- **Bottom centre.**
  - A slim season scrubber: a 360-wide line with the four season glyphs and a glowing handle, like Mario Maker's course-scroll strip.
  - One hint line under it.
  - Nothing else sits in the lower centre.
- **Size and strength live on the cursor.** The ring's size is the brush size, and five motes on its front arc light in the brush colour for strength. The form in hand floats on the beam.
  - This reads better than a meter in the bar, because your eyes are on the cursor while you paint.
  - The bar only shows which brush and form are in hand.

### Legibility (the white-on-fog fix)

Three layers keep the glyphs readable over bright fog and snow.

1. **Plates.** Every group sits on a soft dark plate (`#081218` at 40%) whose edge fades out through a matching shadow. In Godot this is a `StyleBoxFlat` with `bg_color` and `shadow_color` at the same colour, `shadow_size` about 12 and full corner radius.
2. **Under-glow.** Every slot has its own dark under-glow disc at 1.6× the slot size (`underglow.svg`).
3. **Dark rim.** Each glyph gets a 1.5 px dark rim before its light glow. In the mockup this is stacked CSS `drop-shadow`s. In Godot, draw the glyph twice, first dark and slightly grown, or use a small outline shader, then the additive glow copy on top.

Small-caps labels use the same dark-then-light text shadow (Godot `Label` `font_outline_color` dark at 2–3 px, plus a light `font_shadow_color`).

`lantern-maker-snowtest.png` and the "over snow" slot states on the sheet show the result on a near-white frame. All three layers hold up there. This is a filtered stand-in for First snow, not a real capture of that mood.

### Motion

The round-one Lantern motion carries over (idle drift, a halo that swells on selection, dots that light in turn). The layout adds:

- **Forms wheel.** It opens with the forms swinging out from behind Land, each 25 ms after the last (0.28 s, ease-out back). It closes by folding back to Land.
- **Painting.**
  - On stroke start the parts bar lifts off the top edge (0.2 s). Only the held brush stays, at 44, at the top centre.
  - The side columns slide 14 px outward and fade to 16%. Photo fades too.
  - The scrubber and hint hide.
  - Everything returns 0.5 s after release.
  - Each dab puffs the cursor's motes outward and sends a mote up the beam.
- **Mood.** The orbs pour down the crescent from the Mood slot, 30 ms apart. The veil fades in beside the chosen orb. Hovering an orb tints the screen toward its sky.
- **Scrubber.** Dragging the handle scrubs the season live, and the handle glows in the season's light.

### Godot mapping

The root is a full-rect `Control` under a `CanvasLayer`. Set the project's stretch mode to `canvas_items` with aspect `expand` and base size 1440×900. That gives the 1.2 scale at 1080p with no per-node maths. Each group is a child of the root, anchored with a preset.

| Group | Node and anchors |
|---|---|
| Parts bar | `PanelContainer` (plate `StyleBoxFlat`) → `HBoxContainer`, `separation` 16. Anchor preset `CENTER_TOP`, `offset_top` 20, grow both ways horizontally. Children are `TextureButton`s at `custom_minimum_size` 56×56. Empty slots are disabled buttons |
| Forms wheel | A `Control` added under the bar, positioned from the Land button's `global_position`. Children are placed on the arc (a small `RadialContainer` script: radius, start and end angle). Threads are `Line2D`s with a dotted texture |
| Hand modes | `PanelContainer` → `VBoxContainer`, `separation` 16. Anchor preset `CENTER_LEFT`, `offset_left` 24. Undo is a separate `Control` holding an `AnimatedSprite2D`, or tweened `TextureRect`s, for the wisp's three moves |
| World column | Mirror of the hand modes: preset `CENTER_RIGHT`, `offset_right` −24. The mood crescent is a sibling `Control` anchored to the same edge, and the veil is the existing `editor_glass` panel |
| Photo | `TextureButton` 84×84, preset `BOTTOM_RIGHT`, offsets −24, with a halo `TextureRect` behind it |
| Scrubber and hint | `VBoxContainer`, preset `CENTER_BOTTOM`, `offset_bottom` −16. The scrubber is an `HSlider` with a custom grabber icon (glowing dot), a tick texture and a season-glyph overlay. The hint is a `RichTextLabel`; key caps are inline images or a `[bgcolor]` span |
| Cursor | Stays in 3D: a ground ring shader (dot ring, front-arc strength dots, inner ring) plus an additive beam quad, with a `Sprite3D` billboard for the form. The editor's `setting_changed` drives the ring radius and the lit dots |
| Glow | Each lit glyph is a second `TextureRect` of the same SVG, scaled 1.1, blurred (import at 2× and scale down) or given a soft-glow shader, with `CanvasItemMaterial` blend `ADD`. Tint the halo with `modulate` |

Hit targets are 56 everywhere except the forms (52) and Photo (84), so all are at least 44 at the 1440×900 base. At smaller windows the stretch keeps the proportions; below about 1100 px wide, drop the empty future slots.

### Open questions (round 2)

- **Opening the wheel.** Should it open on hold only (Mario Maker), or on a second click as well? The mockup text assumes both.
- **Other way.** Is it a mode on the left, as mocked up, or only right-drag or Shift? Keeping both costs nothing.
- **Scrubber.** Should it scrub the season, the time of day, or both (two handles)? The mockup shows the season.

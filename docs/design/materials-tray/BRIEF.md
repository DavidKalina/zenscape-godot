# Design brief: the materials tray ("naturalist's field case")

ZenScape is a quiet diorama builder for Steam. A small slab of earth floats in a dusky void. You shape it with a ghost hand: you press and pull the land like clay, turn the plate, and shake it for weather. Life arrives by itself, depending on what you built.

The **tray** is where the hand picks up materials to add to the world: seeds, water, stones. It is the only piece of UI on screen during play, so it has to carry the whole game's taste.

We have a working prototype, but it looks cheap: a rounded pill, cartoon glyphs, cool colours, bobbing animation. We want it redesigned.

## Attached references
- `ref-title.png` shows the title screen. This is the taste bar. Match its restraint.
- `ref-play.png` shows a typical play view. The tray sits along the bottom of this, over a grey-violet void and a green plate.

## Direction: a naturalist's field case
Imagine a long, low specimen case of **dark smoked glass**, edged with a **brass or amber hairline**. It sits along the bottom of the screen. Each compartment holds one specimen, drawn like an old **botanical engraving**: fine single-colour line work, light hatching for form, no fills or flat cartoon shapes. It should feel like something a Victorian naturalist carried in the field: precise, quiet, a bit precious.

**Mood words:**
- Yes: refined, distinguished, still, warm, engraved, specimen, brass, glass.
- No: cute, bubbly, bouncy, app-like, flat icons, pills, badges, emoji.

## What the title screen does (match this)
- **Type does the work.** The logo is a refined serif. The tagline uses widely spaced small caps. A hairline rule sits above and below the logo.
- **No boxes or buttons.** The selected menu item gets only a thin vertical line to its left.
- **Warm cream type printed onto a dusky scene**, with a faint shadow.
- **Nothing bounces.** Things fade and slide slowly.

## Palette (from the game)

| Role | Hex |
|---|---|
| Logo cream | `#e3d7bd` |
| Warm hairline / accent (title rules and stem) | `#e2d0aa` (the rule gradient peaks at 40% alpha) |
| Tagline | `#e6decd` at about 63% alpha |
| Menu text | `#e9eef2` at about 79% alpha; hover `#f5f1e6` |
| Deep shade | `#081218` / `#0b0e12` |

**Accent: amber.** The user wants the tray more amber than the title. Propose an amber/brass ramp that sits beside `#e2d0aa` without clashing: a dim resting amber, a lit hover amber, and a hairline brass.

## Type (these ship with the game, so use them)
- **Newsreader** (display): logo and small caps.
- **Spectral** 400 (reading): menu and body text.
- Labels are small caps with wide tracking, in the style of the title's tagline.

## Contents
The tray should feel **fuller** than a three-jar strip: a proper case with several compartments, grouped by a hairline divider.

1. **Seeds, as separate kinds.** Each is its own specimen. Draw these six: acorn (oak), pine cone (pine), willow catkin (willow), birch catkin or samara (birch), wildflower seed head (meadow), reed or rush (waterside).
2. **Water:** a single drop, or a small water specimen.
3. **Stones:** a river stone, and optionally a crystal or rough shard.
4. **Snow** (optional): a snowflake engraving.
5. **Undiscovered slots.** Some compartments are empty or show a faint outline: kinds the player hasn't found yet. This hints that there is more to find without saying so. Show one or two in the mockups.

The label under a hovered specimen is small caps, for example `ACORN · OAK`, `RIVER STONE`, `WILLOW CATKIN`.

## States to design
1. **At rest.** The case is present but receded: low opacity, lying low along the bottom edge. It must not compete with the diorama.
2. **Case woken.** The pointer is near the bottom edge. The case brightens to full, with no bounce.
3. **Hovering a specimen.** It warms from dim to lit amber, a hairline draws out beneath it, and its label fades in.
4. **Picked up.** The specimen lifts out, and its compartment is left faintly outlined, showing it is in the hand.
5. **Undiscovered slot.** An empty compartment or a faint outline.

## Motion rules
- No bobbing, bouncing, squash or springy overshoot.
- Transitions last 150–250 ms, eased in and out.
- Hover is a warm fade plus a hairline drawing out.
- Waking the case is a slow fade of about 300 ms, with a slight rise of at most 4 px.
- A quiet "tick" sound on pick-up. Sound isn't your job; just note where it goes.

## Size and placement
- The game runs at 1440×900 logical (2× Retina).
- The case is centred at the bottom, with a margin of about 24–32 px from the bottom edge. Its width is up to about 60% of the screen, so it can hold 10–12 compartments.
- A quiet one-line hint sits just above it in Spectral, in cream at low alpha.

## Built in Godot, not HTML
These limits keep the design buildable:
- **Glyphs:** deliver them as SVG line art in a single colour. Use `fill-opacity` / `stroke-opacity` only, never `rgba()` colours, which import as black. Avoid gradients along curved paths, which can vanish on import. Hatching as plain strokes is fine. Also export each glyph as a 2× PNG as a fallback.
- **Stroke weight:** consistent, about 1–1.5 px at 1×, so the set reads as one engraver's hand.
- **Glass and blur:** a translucent dark panel with a hairline border is easy. True background blur behind the glass is possible but costly, so show a version without blur too.
- **Effects:** simple glows, fades and hairline growth are all easy. Complex masks and many layered effects are not.

## Deliverables
1. The play view (`ref-play.png`) with the case composited in each state: rest, woken, hover, picked.
2. A close-up sheet of the full specimen set: seeds, water, stones, snow and an undiscovered slot.
3. The amber palette ramp with hex values.
4. The motion notes as a short table: property, duration and easing for each state change.
5. Optionally, one bolder variation to push against.

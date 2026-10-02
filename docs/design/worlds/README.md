# Handoff: ZenScape Worlds — "Living backdrop" (direction 1b)

## Overview
Lets players save and load scenes in ZenScape. **Worlds autosave all the time, so there is no Save button and there are no save slots.** Players can only do five things with a world: **open, create, rename, duplicate, delete**. In-game, the one save action is **"Save a copy as…"**, which forks the current world.

In direction 1b, **the title screen is the world library.** The title's orbiting camera shows whichever world is selected. Browsing worlds swaps the live backdrop.

## About the Design Files
`ZenScape Worlds.dc.html` is a **design reference built in HTML**. It shows the intended look and behaviour; it is not production code. Rebuild it in the game's own UI layer (engine UI, React overlay, etc.) using that codebase's patterns. Open the file in a browser to try it: tiles, rename, duplicate, delete, land choice, seed roll and save-copy options all respond to clicks. `support.js` is only the prototype runtime. Don't port it.

Each frame is a **1440×810** reference viewport. Lay out the real UI relative to the screen edges as described below.

## Fidelity
**High-fidelity.** Colours, type, spacing and copy are final. The fabric ("linen") treatment matches the existing in-game toolbar and command palette.

## Screens

### 1. Title + worlds (home screen)
**Purpose:** pick a world and enter it, manage worlds, or start a new one.

**Layers (back to front)**
1. **Live backdrop.** The selected world rendered in 3D with the slow orbiting camera, full-bleed. In the mock it's a still image with a CSS filter. In-game it's the real scene.
2. **Legibility scrim**, full-bleed: `linear-gradient(180deg, rgba(20,16,22,.45) 0%, rgba(20,16,22,0) 22%, rgba(20,16,22,0) 38%, rgba(16,12,16,.88) 100%)`.
3. **Wordmark**, top-left (left 64, top 46):
   - "ZENSCAPE": Newsreader 400, 32px, letter-spacing .42em, `#f1e8d4`.
   - Tagline below, 8px gap: "a little wilderness, made by you". Newsreader 500, 13px, all-small-caps, letter-spacing .3em, `#d4c9b2`.
4. **Top-right links** (right 64, top 56, gap 32): "Settings", "Quit".
   - Newsreader 500, 14px, all-small-caps, letter-spacing .26em, `#d4c9b2`.
   - Hover: `#fffaf0`.
5. **Selected-world block**, bottom-left (left 64, bottom 214). Column with gap 14:
   - Kicker: "Your worlds · {n} of {total}". Newsreader 500, 13px, small-caps, .28em, `#d4c9b2`.
   - World name: Newsreader 400, 58px, line-height 1.05, `#f6eedc`, text-shadow `0 2px 18px rgba(10,8,10,.5)`.
   - Last played ("Played 2 minutes ago", "Yesterday evening", "Tuesday", "12 September"…): Spectral 400, 17px, `#d4c9b2`.
   - Action row (gap 28, min-height 46, margin-top 6):
     - **Enter world ↵**: primary button (see Tokens).
     - **Rename · Duplicate · Delete**: Newsreader 500, 14px, small-caps, .24em, `#e3d7bd`.
     - Hover: `#fffaf0`; Delete hovers to `#f0a383`.
6. **World strip, wrapped in linen fabric**, bottom (left 64, right 64, bottom 28):
   - Container: padding 18/24/14, radius 14, flex row, gap 14, items aligned to the bottom.
   - Fabric style: see the Linen panel token. Background alpha is .82, with `backdrop-filter: blur(6px)`. The inner dashed stitch is inset 5, radius 10.
   - Tiles: one per world, most recent first. Each is 156 wide:
     - Thumbnail 156×96, radius 8, shadow `0 6px 16px rgba(8,6,8,.45)`.
     - Name below (7px gap): Spectral 14px, single line with ellipsis.
     - **Selected:** border `1.5px solid #e3d7bd`, lifts `translateY(-6px)`, label `#f6eedc`.
     - **Unselected:** transparent border, label `#bfb49e`.
     - Transition: transform .18s ease.
   - Last tile, "New world": 96px tall, `1.5px dashed rgba(227,215,189,.55)` border, fill `rgba(20,15,10,.35)`, centred "+" in Newsreader 30px.
   - Right-aligned hint: "◂ ▸ browse · ↵ enter". Newsreader 500, 13px, small-caps, .24em, `#a39a88`.

**Rename (inline).** The name text turns into an input in the same position:
- Input: Newsreader 50px, width 720, fill `rgba(20,16,12,.45)`, bottom border `1px dashed rgba(227,215,189,.6)`, radius 8 8 0 0, padding 4/14. Pre-filled with the current name and autofocused.
- The action row becomes **Keep name ↵** (primary) and **Cancel · Esc** (link).
- Enter commits; Escape cancels. A blank name is ignored and the old name stays.

**Delete confirm (inline).** The action row is replaced by a small linen card:
- Card: radius 12, padding 12/14/12/22, gap 22, stitch inset 4.
- Copy: "Let this world go? It can't be brought back." Spectral 18px, `#f1e8d4`.
- **Keep it**: primary button.
- **Let it go**: destructive outline button. Text `#f0a383`, border `1px solid rgba(240,163,131,.55)`, radius 8, padding 7/16. Hover fill `rgba(240,163,131,.12)`.
- After deleting, the selection moves to the next world (or to the previous one if the deleted world was last).

**Duplicate:**
- Inserts "{name} (copy)" right after the source world, with last played "Just now".
- Selects the new copy.

### 2. New world
**Purpose:** name a world, choose its land, choose a seed. The backdrop **previews the chosen land live.**

- **Backdrop:** the preview of the selected land, orbiting. Scrim: `linear-gradient(90deg, rgba(16,12,16,.55) 0%, transparent 30%, transparent 50%, rgba(16,12,16,.5) 100%)`.
- **Bottom-left caption** (left 64, bottom 56):
  - "Preview" kicker.
  - Land name: Newsreader 52px, `#f6eedc`.
  - Description: Spectral 18px, `#e3d7bd`.
- **Right-docked linen panel:** right/top/bottom 24, width 440, radius 16, padding 30/30/24, column with gap 22.
  - Heading "A new world": Newsreader 30px.
  - **Name** field: placeholder "{Land} — or leave it". If left blank, the world takes the land's name.
  - **Land** list, four rows (gap 4). Each row:
    - 76×48 thumbnail (radius 5) plus the land name in Newsreader 19px.
    - Row padding 6, radius 9.
    - Selected: border `1.5px solid #e3d7bd`, fill `rgba(20,15,10,.3)`.
  - Lands:
    - Quiet plain: "Flat and green. Raise every hill yourself."
    - Red canyon: "Banded stone and slow cactus."
    - Misty isle: "Low cloud and soft grey water."
    - Moss hollow: "Deep shade and damp ground."
  - **Seed**: the seed text in Spectral italic 19px (format `word-word-NNNN`, e.g. "basalt-heron-2081"), plus a **Roll** button (dashed outline) that generates a new seed. The same seed always grows the same land.
  - Footer (pinned to the bottom, dashed rule above): "Back" link on the left, **Begin ↵** primary button on the right.

### 3. In-game pause (centred)
**Purpose:** reassure the player that the world is safe; resume, fork, or leave.

- Full-screen scrim `rgba(20,18,26,.42)` over the live game. The HUD stays where it is.
- **Centred linen panel:** 440 wide, centred with `translate(-50%,-50%)`, radius 16, padding 30/22/22.
  - Header (padding 0 12 14):
    - "Paused" kicker.
    - World name: Newsreader 30px.
    - Status: a 7px dot (`#b9c99a`) plus "Kept safe · just now" in Spectral 15px, `#c2b8a3`.
  - Rows, each Newsreader 21px, `#f1e8d4`, padding 10/12, radius 9, hover fill `rgba(20,15,10,.22)`:
    - **Resume**: shown in the focused state (fill `rgba(20,15,10,.28)`), with an "Esc" hint on the right.
    - **Save a copy as…**: ▸/▾ toggle that expands inline.
    - **Settings**
    - Dashed divider.
    - **Return to title**
  - Footnote: "Nothing is lost when you leave." Spectral italic 15px, `#a39a88`.
- **Save a copy as… expanded.** An inset well (fill `rgba(20,15,10,.3)`, radius 10, padding 14, gap 12) containing:
  - Name input, pre-filled "{World name} (copy)".
  - Radio buttons: **Carry on in the copy** (default) / **Stay here — keep the copy for later**. Each is a 14px ring in `#e3d7bd` with a 7px fill dot when selected.
  - **Save copy ↵**: primary button, right-aligned.

## Interactions & Behaviour
- **Saving:**
  - Autosave on every meaningful edit, debounced (suggested: a few seconds after the player stops editing, and always on pause or quit).
  - The pause status reads "Kept safe · just now", or "Keeping…" while a write is in progress.
- **Title browsing:**
  - ◂/▸ (or a controller shoulder button, or a click on a tile) changes the selection.
  - The backdrop scene swaps to the new world. Suggested transition: a short fade through the scrim (~300ms), then the camera picks up the orbit.
- **Opening:** Enter, a double-click on a tile, or "Enter world".
- **Escape:** cancels rename or delete first. From pause, it resumes.
- Only one inline mode (idle / rename / delete) is active at a time. Changing the selection resets it to idle.
- **Empty state** (no worlds): the backdrop shows a quiet plain, the kicker reads "Your worlds", the name reads "No worlds yet", and only the New world tile remains.
- **Thumbnails:** capture a frame from the orbit camera on save or exit.

## State
- `worlds[]`: `{ id, name, lastPlayedAt, thumbnail, sceneRef }`, sorted by `lastPlayedAt` descending.
- `selectedIndex`
- `mode`: `idle | rename | delete`
- `draftName`
- New world: `{ name, biome, seed }`
- Pause: `{ copyOpen, copyName, carryOn: 'copy' | 'stay' }`
- Relative-time formatting:
  - "Played N minutes ago" for today.
  - "Yesterday evening" (the yesterday wording can be time-of-day aware).
  - Weekday name within the last week.
  - "12 September" after that.
  - Month name only for older worlds.

## Design Tokens
**Colours**
- Ink, primary: `#f6eedc` (headlines on scene)
- Ink: `#f1e8d4` (text on linen)
- Thread / accent: `#e3d7bd`
- Secondary text: `#d4c9b2` (on scene), `#c2b8a3` (on linen)
- Muted: `#a39a88`, `#bfb49e`
- Destructive: `#f0a383`
- Status OK: `#b9c99a`
- Button text: `#2a251f`
- Page dark: `#1d1c24`

**Linen panel**
- `background-color: rgba(84,75,63,.9)` (the strip uses .82)
- `background-image: repeating-linear-gradient(0deg, rgba(20,14,8,.12) 0 1px, transparent 1px 3px)`
- `box-shadow: inset 0 1px 0 rgba(255,240,215,.09), 0 18px 50px rgba(10,8,12,.45)`
- Inner stitch: an absolutely positioned overlay, inset 5–6px, `1px dashed rgba(227,215,189,.3)`, radius = panel radius − 5.

**Primary button**
- Background `#e3d7bd`, text `#2a251f`
- Newsreader 500, 17–18px
- Radius 8, padding 10/24–26
- Hover: background `#f4ead3`

**Text link / kicker**
- Newsreader 500, 13–14px
- `font-variant-caps: all-small-caps`, letter-spacing .22–.28em

**Inputs**
- Fill `rgba(20,16,12,.35)`
- No border except a bottom `1px dashed rgba(227,215,189,.5)`
- Radius 6 6 0 0
- Newsreader at the context's size

**Type**
- Newsreader (400/500): headings, names, buttons, small-caps labels.
- Spectral (400, italic): body, metadata, seed.
- Both from Google Fonts.

**Radii**
- Panels: 14–16
- Rows: 9
- Tiles: 8
- Thumbnails: 5–6
- Buttons: 8

## Assets
- `title-desert.png`: title-screen render. Used here, cropped and filtered, as stand-in world thumbnails and backdrops.
- `game-bg.png`: in-game render, used behind the pause screen and for stand-in thumbnails.
- In production, every thumbnail and backdrop is a real capture or live render of that world. The CSS hue/saturation filters in the mock exist only to fake variety.

## Files
- `ZenScape Worlds.dc.html`: the prototype (frames: Title + worlds, Delete confirm, New world, Pause).
- `support.js`: prototype runtime. Not for production.
- `title-desert.png`, `game-bg.png`: reference images.

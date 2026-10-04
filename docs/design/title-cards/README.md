# Title cards: main menu and world select, dealt as cards

Claude Design project "Game UI Art Styles", `ZenScape Main Menu Cards.dc.html`
(frames 6b and 7b, face **5d Coin**). The design files are kept here for
reference: `ZenScape Main Menu Cards.dc.html` with the `WorldCard` and
`Glyph` components it imports. They need the Claude Design runtime
(`support.js`), which is not part of the game.

The title is two fans of cards over the orbiting world. Cards bob at rest.
The card under the pointer lifts and tilts toward the pointer, and its
neighbours lean away. A press sinks it a little. A pick draws it up and
sinks the rest, and its action follows. ◂ ▸ move, ↵ picks, and Esc goes back
from world select.

- **Main menu** (6b): Continue, Your worlds, A new world, Almanac, Rest. The
  wordmark sits centred at the top. Your worlds sits on a deck of two cards.
  Continue names the most recent world, takes that world's colours, and is
  left out when there are no worlds.
- **World select** (7b): every kept world as its card, most recent first,
  then a blank card. The wordmark and ◂ Menu sit top left, the count top
  right, and the focused world's number, name, mood and seed above the fan.
  The world behind turns to the hovered card. The blank card keeps the world
  behind and opens New world.

`--classic-title` (or the `classic_title` meta on a scene a test builds)
keeps the old card and library strip (docs/design/worlds).

## Where it lives

- `scripts/title_cards.gd`: the screen, its two fans, the springs, keys and
  words. `studies/cozy_worlds.gd` owns what the picks do: Continue
  (`continue_world`), Your worlds (`open_library`), A new world and the blank
  card (the New world panel, whose Back returns to where it was opened),
  Almanac (settings), Rest (`_quit_safely`), a world card
  (`world_session.open_world`) and Esc / ◂ Menu (`close_library`, the
  showcase returning under the cards' veil).
- `scripts/menu_card.gd`: one card. Its face is drawn flat into a SubViewport
  (`shaders/menu_card.gdshader` for the cloth and coin window, the glyph from
  `scripts/hud_icons.gd`, the printing). `shaders/card_tilt.gdshader` sets it
  in the scene through the card's homography, so the tilt is real perspective
  (900px), with the card's drop shadow leaning with it and the sheen on top.
  The ground shadow, and the deck behind Your worlds, float with the card
  but do not tilt.
- `scripts/world_card.gd`: what a world's card shows. When a world is kept
  (`world_session.keep_now`), its palette (the look's sky, glow and grass),
  mood (season, time, weather) and the four things placed most often
  (objects by glyph, ponds and streams as water) are stored with it in the
  library index as `card`. A world kept before cards shows its land's
  palette and glyph until it is next kept.
- `shaders/title_backdrop.gdshader`: the live world dimmed behind the cards:
  `blur(2px) brightness(.72)` on the menu and `brightness(.82)` on world
  select.

## Numbers from the design

All lengths are design pixels of the 1440 × 810 frame, fitted to the screen
(`TitleCards.scale_for`, the smaller of width/1440 and height/810). The fans
keep their distance from the foot of the screen, and the words from its top.

| | Main menu | World select |
|---|---|---|
| Card | 240 × 336 at .72 | 240 × 336 at .62 |
| Spacing | 188 | 166 |
| Centre height | 606 | 640 |
| Arc drop | 6·d² | 5·d² |
| Turn at rest | 2.5°·d | 2°·d |

For a world select with more than six worlds, the fan closes up to stay 64
from the sides, and its ends drop and turn no further than the design's
seven cards do.

**Motion**, per 60 Hz step: a spring `v = (v + (target − x)·.085)·.76`. The
targets are lift 1 when hovered (1.9 when picked), sink 1 for the cards not
picked, lean ±26 for each neighbour and ±10 beyond them, and press 1 while
held. The tilt follows the pointer at .14 a step.

The pose of each card follows the design's formulas:
- **Bob:** `sin(t·1.15 + i·1.7)·7`.
- **Sway:** `sin(t·.8 + i·2.1)·.9`.
- **Rise:** `y = bob − lift·30 + sink·70 + |lean|·.4`.
- **Scale:** `1 + lift·.07 − press·.05`.
- **Tilt:** `rotateX(−y·12·L) rotateY(x·14·L)`.
- **Art:** on menu cards only, `(x·7·L, y·5·L − 5L)` turned `−4°·x·L`.
- **Sheen:** `.22·L` at `(50 + 45x)%, (35 + 45y)%`.
- **Ground shadow:** opacity `.75 − .3L − .4·sink`.

A pick waits .65 s before its action. Almanac settles back after 1.7 s.

**Coin face:** cloth `#4e463b` with its threads, a 1 px light rim at the
top and a 2 px dark rim at the foot. A 2 px dashed ring, `rgba(227,215,189,.42)`,
212 px across at (14,18). The 192 px window at (24,28) holds its sky (top
to low by 70%), the haze (world cards), the 68 px sun at (62,30), the hill
ellipse 272 × 180 at (−40,132) and the 78 px glyph. The numeral sits 156
into the window, set in Newsreader 500 12 px, tracked .34em. Below the
window, at 246, are the name (Newsreader 24/28 on the menu, 22/26 balanced
on worlds, `#f6eedc`) and its line (11 px small caps .24em, `#c2b8a3`). The
blank card has a 1.5 px dashed inset border, then "+", "Begin a new world"
and "name it, choose the land".

## Not in the design

- **Build this world** and **Begin on a quiet plain** have no card. A quiet
  plain is a land on the New world panel. Keeping the showcase world, and
  renaming, duplicating and deleting worlds, are only on `--classic-title`
  for now.
- The design's Almanac card opens the settings dialog, as the old card's
  Settings did.

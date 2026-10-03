# Title screen

Godot's diorama entry point now uses the Electron title's Newsreader inscription,
Spectral menu, gold hairlines, breathing selection stem, and dark landscape scrim.
The original font files are bundled with their OFL licenses.

The cover is a randomly chosen cinematic chunk, closely framed like Electron’s
`titleView`: 72% camera radius, a raised target, and a 0.22-speed orbit. Seasonal
weather, drifting clouds, and curated lighting keep it alive.
The title is anchored near the top, with the key legend at the window foot.
Electron’s five-layer shadow scrim and four-stop gold inscription are retained,
with a fade from black and a staggered menu entrance. It is disposable and is
never saved as a player world. New diorama still restores the blank starting
state. During a session, Menu uses the current world and Escape returns to it.
Continue and Save a copy are shown only when available. Keyboard focus selects
an action; hovering does not move the keyboard selection.

Validation: `tests/test_diorama_flow.gd` (removed) covers the unsaved cover, initial focus,
arrow navigation, Escape, blank creation, save/open/continue, failed open, and
content bounds down to a 480×320 logical Retina viewport. The PNGs were captured
from the Forward+ renderer, including a 960×640 physical window.

Capture the real title without accessing the player library using
`--script tools/capture_title.gd`. Reference and current captures live locally
in `docs/visual-lab/title-screen/`. Terrain is native Godot; the Electron
journaling actions are replaced by the existing diorama actions.

## Random cinematic covers

Each launch picks a fresh terrain variation and a compatible look from
`scripts/title_showcase.gd`: horn, alpine cone, ridgeback, valley, plateau, or
red-rock canyon. Looks include autumn, first snow, rosewater dusk, alpine light,
and forest mist with sun rays. Flat and marsh compositions are excluded.
The startup CanvasLayer paints before scene setup, breathes while cooperative
terrain generation runs, and hands off to the title fade only when ready.
No cover is saved to the player library. `title_seed` allows reproducible QA;
`tools/capture_title.gd -- 37` captures a known selection.

Validation: 500 seeded selections pass native recipe validation and reach all
six families; the native diorama lifecycle and title resolution tests pass.

The production world-variety integration expands this pool to 39 terrain/mood
pairings across 13 curated entries (11 distinct families), including inland
massifs, twin peaks, glacial/buttressed valleys, monuments, salt basins and desert
mountains. These use the same saved recipes and shared fog/cloud/rock controls
as the editor. See [shared world variety](../world-variety/README.md).

Desert (held back for an update): the four arid entries (monuments, salt
basin, desert mountains, canyon) are only drawn with desert on
(`scripts/desert_landscape.gd` `ENABLED`, or `--desert`). A default game
picks from the nine others, seven families.

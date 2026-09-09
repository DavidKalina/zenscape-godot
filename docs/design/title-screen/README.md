# Title screen

Godot's diorama entry point now uses the Electron title's Newsreader inscription,
Spectral menu, gold hairlines, breathing selection stem, and dark landscape scrim.
The original font files are bundled with their OFL licenses.

The cover is a live wooded Silverhorn chunk, closely framed like Electron’s
`titleView`: 72% camera radius, a raised target, and a 0.22-speed orbit. Fair
weather, drifting clouds, and fixed evening light (phase 0.68) keep it alive.
The title is anchored near the top, with the key legend at the window foot.
Electron’s five-layer shadow scrim and four-stop gold inscription are retained,
with a fade from black and a staggered menu entrance. It is disposable and is
never saved as a player world. New diorama still restores the blank starting
state. During a session, Menu uses the current world and Escape returns to it.
Continue and Save a copy are shown only when available. Keyboard focus selects
an action; hovering does not move the keyboard selection.

Validation: `tests/test_diorama_flow.gd` covers the unsaved cover, initial focus,
arrow navigation, Escape, blank creation, save/open/continue, failed open, and
content bounds down to a 480×320 logical Retina viewport. The PNGs were captured
from the Forward+ renderer, including a 960×640 physical window.

Capture the real title without accessing the player library using
`--script tools/capture_title.gd`. Reference and current captures live locally
in `docs/visual-lab/title-screen/`. Terrain is native Godot; the Electron
journaling actions are replaced by the existing diorama actions.

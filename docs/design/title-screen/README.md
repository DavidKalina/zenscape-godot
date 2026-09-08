# Title screen

Godot's diorama entry point now uses the Electron title's Newsreader inscription,
Spectral menu, gold hairlines, breathing selection stem, and dark landscape scrim.
The original font files are bundled with their OFL licenses.

The cover is a live, slowly orbiting Skywater plateau. It is disposable and is
never saved as a player world. New diorama still restores the blank starting
state. During a session, Menu uses the current world and Escape returns to it.
Continue and Save a copy are shown only when available. Keyboard focus selects
an action; hovering does not move the keyboard selection.

Validation: `tests/test_diorama_flow.gd` covers the unsaved cover, initial focus,
arrow navigation, Escape, blank creation, save/open/continue, failed open, and
content bounds down to a 480×320 logical Retina viewport. The PNGs were captured
from the Forward+ renderer, including a 960×640 physical window.

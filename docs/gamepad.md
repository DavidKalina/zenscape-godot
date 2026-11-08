# Gamepad

The game plays on an Xbox-style pad, the Steam Deck's included. The keyboard
and mouse keep working alongside it; the last device used names the prompts.
The in-game Controls page (pause menu) lists every binding with the pad's
glyphs, read from the InputMap (`scripts/endless/shell/controls_page.gd`).

The bindings live in one table, `ACTIONS` in `scripts/pad.gd`, which also holds
dead zones, curves and vibration. Flight bindings:

| Pad | Does | Keys |
|---|---|---|
| Left stick | Bank and pitch | W A S D, arrows |
| Right stick | Look round | Right mouse |
| Right trigger | Boost | Space |
| Left trigger | Brake | Shift |
| A | Barrel roll | Z |
| LB / RB | Knife edge (lean) | Q / E |
| Y | Flaps, land | F |
| X (held) | Surge, with a full meter | B |
| B | Drop the cargo | E |
| D-pad up | Next weight preset | V |
| D-pad right | Next pace preset | P |
| R3 (held on a bracketed plane) | Challenge it to a race | Tab |
| L3 | Photo mode | O |
| Start | Pause | Esc |

In menus the pad's A, B and the d-pad work every page.

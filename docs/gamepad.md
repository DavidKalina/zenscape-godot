# Gamepad

The whole game plays on an Xbox-style pad, the Steam Deck's included. The keyboard and mouse keep working alongside it, and there is no mode to switch. Whichever device was used last names the prompts.

Code:
- `scripts/pad.gd`: the actions, the device in use, dead zones and curves, and vibration.
- `scripts/pad_input.gd`: what the pad does in each place.
- `scripts/pad_prompt.gd`: hint lines with drawn button glyphs.
- `scripts/wanderer_eye.gd`: walking and flying.

Tests: `tests/test_gamepad.gd` and `tests/test_gamepad_screens.gd`.

## Layout

The layout follows cozy builders on a pad, such as Townscaper and Tiny Glade on the Deck. In building, a soft cursor stands for the mouse. The shoulders, the D-pad and Y pick what is in hand. Nothing destructive happens on a single press:
- Undo and redo are holds.
- Delete in the library asks first, with Keep it in focus.
- The trash can keeps its own undo.

### Building

| Pad | Does | Keys / mouse it matches |
|---|---|---|
| Left stick | Moves the hand's cursor. It eases in and speeds up while held. At rest it keeps to the land point under it as the view orbits and the world turns. | Moving the mouse |
| A (tap, hold) | Press, or hold and move for a stroke or drag. A quick second press glides the camera there. | Left click / drag, double-click |
| X (held) | Shift: thin, pluck, or turn without winding time | Shift |
| B | Puts down what is in hand: the material, then the tool. Closes an open page, the palette or the moods. | Esc (never opens the menu) |
| B held ½ s | Undo | Cmd Z |
| Y | Next mode of the tool in hand (Pull/Draw, Pinch/Groove…) | Q / E |
| Y held ½ s | Redo | Cmd Shift Z |
| LB / RB | Previous / next tool on the roll | Pressing a pocket |
| D-pad ◂ / ▸ | Previous / next specimen found in the case | Pressing the case |
| D-pad ▴ / ▾ | Size up / down | [ ] or 1 2 3 |
| Right stick | Orbit and tilt | Right-drag |
| LT / RT | Zoom out / in, toward the cursor | Wheel |
| R3 | Overview | R |
| L3 | Photo mode | P |
| View | Steps into the eyes where the cursor is | V |
| View held ½ s | Watch mode | O |
| Menu | Pause; closes the moods first if open | Esc |

### Walking

| Pad | Does | Keys / mouse |
|---|---|---|
| Left stick | Walk, analog | WASD / arrows |
| Right stick | Look | Mouse |
| A | Jump; again on landing, the higher pump; in a skid, the side flip; surfing a slope, the slide jump; on a wall (or just after touching one in the air), kick off it; again in the air to fly; beside the plane, take off | Space |
| LT (held) | Crouch; at a run, then A, the long jump; on a slope, surf down it | Shift or C |
| X (in the air) | Twirl; out of a slide, steer across to build speed and hop again on the touch | X |
| B or View | Step back out to building | V / Esc |
| Menu | Pause (steps out) | — |

Walking is already first person, so there is nothing for C, and Y does nothing while walking.

### Flying (the plane)

| Pad | Does | Keys / mouse |
|---|---|---|
| Left stick | Bank, turn and pitch | A D, W S |
| Right stick | Look round. The view holds 2.5 s, then swings back. | Mouse |
| RT or A | Boost | Space |
| LT | Brake | Shift |
| LB / RB | Barrel roll | Q / E, click |
| Y | Land. Again before the touch flies on; after it, hops out. | F |
| X | Eject (the skydive, docs/skydive.md) | X |
| R3 | Chase / first-person camera | C |
| B or View | Step out | V / Esc |
| Menu | Pause | — |

During the landing, RT, a roll or Y flies on, as Boost, Q/E or F do.

### Skydiving (out of the plane)

| Pad | Does | Keys / mouse |
|---|---|---|
| X | Open the canopy (it also opens by itself near the ground) | X |
| Left stick | Falling: turn, forward tracks, back slides. Under the canopy: steer, forward for speed, back to brake | A D, W S |
| RT or A | Falling: tuck and dive faster | Space |
| LT | Falling: spread and slow. Under the canopy: brake and float | Shift |
| Right stick | Look round | Mouse |
| B or View | Step out | V / Esc |

The old glider (`--glider`) keeps its own controls:
- LT or A rises and RT dives.
- X flaps.
- Y comes in to land.

### Photo mode

| Pad | Does | Keys |
|---|---|---|
| Right stick | Orbit / look | Drag |
| Left stick | Pan / walk the ground eye | Right-drag, arrows |
| LT / RT | Dolly | Wheel |
| A | Take the photo | Space |
| B | Back | P / Esc |
| X | Ground eye | G |
| Y | Depth of field | F |
| LB / RB | Lens | [ ] |
| D-pad ▴ / ▾ | Exposure | Shift [ ] |
| View | Hide the chrome | H |
| R3 | Reframe | R |
| Menu | Leave and pause | — |

### Watch mode

Any button comes back. Menu comes back and pauses.

### Screens

| Screen | Pad |
|---|---|
| Front page | D-pad or left stick moves through the entries, A presses. Godot's focus is used; the card lights the focused entry. |
| Pause, field notes | D-pad up/down steps the rows, A presses, B folds the copy well, goes back from the notes, or resumes. Menu resumes. |
| Settings | Every row takes focus on the pad. D-pad moves, ◂ ▸ sets sliders and lists, A toggles, B closes. Includes **Controller vibration** (`user://pad.cfg`). |
| Library | ◂ ▸ browse the worlds, A enters, B goes back. ▴ lifts focus onto the action row (Enter, Rename, Duplicate, Delete), ▴ again onto Settings and Back. ◂ ▸ walks a row, A presses, ▾ or B returns to the worlds. X starts a new world. Delete shows its card with Keep it focused: ◂ ▸ choose, A presses, B cancels. |
| Rename | A keeps the name, B cancels. Typing needs a keyboard, or the Deck's on-screen keyboard (Steam + X). |
| New world | ▴ ▾ pick the land, ◂ ▸ the kind, X rolls the seed, Y goes to the name, A begins, B goes back. |
| First steps card, almanac, almanac pages, command palette | The cursor and A, like the mouse. B closes a page or the palette. |

A stitched ring in the linen's thread, with a faint lift, follows the focus on these screens while the pad is in hand.

## Actions

Every pad read goes through a named action in the InputMap (`Pad.ACTIONS`). `Pad.ensure()` adds the ones the project does not define. It leaves alone any action already in `project.godot` or set by a remap. It also gives `ui_accept` the pad's A and `ui_cancel` its B.

Keys sit in the same action where the code polls them:
- `move_*`
- `walk_jump`, `walk_crouch` and `walk_twirl`
- `fly_boost` and `fly_brake`
- `fly_eject` (the pad's X: eject, then open the canopy; the X key is the same verb, read as an event)
- `glide_rise` and `glide_dive`

Keys read as events keep their own handlers.

The screens that only read keys (the library, New world, photo mode) are handed the pad's moves as those keys. They are marked with `Pad.PAD_DEVICE` so they are not taken for the keyboard.

Prompts name a binding with `{action}` or a glyph id (`{A}`, `{LB}`, `{LS}`). A remap changes the glyph drawn.

## Devices and feel

**Which device is in use:**
- The pad counts as picked up on a press, or a stick or trigger pushed past 0.45.
- The keyboard and mouse count as picked up on a key, a click, or the mouse moving 3 px.

**Prompts.** They follow the device:
- the walk, fly, landing, photo and watch hints
- the hand's hint line
- the first steps' lines, and the field notes with them
- the pause panel's "Esc"
- the library's strip hint

**The cursor:**
- It moves the system pointer: `warp_mouse` where there is a mouse, and the pointer's own events otherwise. Everything that reads the pointer follows it.
- While the pad drives it, the system arrow hides and a small stitched reticle shows instead.
- The pointer echo some systems send after a warp is dropped. It is neither the mouse picked up nor a second move.

**Dead zones and curves:**
- Sticks: 0.18 radial, rescaled from the edge, with a 1.6–1.8 power curve.
- Triggers: 0.1.
- Cursor: 0.75 screen heights a second at full push. It starts at 40 % and reaches full speed over 0.6 s.
- Orbit: 0.24 of a turn a second.
- Zoom: ×2.2 a second.

**Vibration.** Small pulses on touchdown, a barrel roll, A on the land, and undo/redo. It is off with the setting, and silent while the keyboard and mouse are in hand.

## Not covered yet

- Scrolling the almanac pages and the field notes' long list on the pad. The pages' items are pressed with the cursor; the notes scroll with the D-pad.
- The command palette's typing.
- Rename's typing, beyond the Deck's on-screen keyboard.
- The mood orbs under `--classic-shell`, the old craft shell, and the legacy file dialog.

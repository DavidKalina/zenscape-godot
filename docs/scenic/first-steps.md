# First steps

The game has no tool modes, so the gestures are easy to miss. First steps walks a new player through six of them, once, and keeps the rest in a page of field notes. Branch `feature/first-steps`.

## What it is

- **The model** (`scripts/first_steps.gd`) knows every verb the hand can do (`VERBS`), which ones the player has found, and which step the card is on. It draws nothing and recognises no gesture. The world's own pieces call `mark(id)` when a verb is really done, the way the almanac's whispers retire.
- **The card** (`scripts/first_steps_card.gd`) is a small linen card that shows one step at a time, with six pips and a Skip. As a step is asked, the hand is given what the step needs (the verb's `take`: a tool from the roll in the right mode, or the tool put down), and the pocket and mode it names (the verb's `near`) are gently ringed.
- **The field notes** (`scripts/field_notes.gd`) are the lasting reference, reached from the pause panel.

## The six steps

Shown in this order, one at a time. The card shows the first step not found yet, so a player who does a later one early never sees it asked.

| Step | Verb | Done by |
|---|---|---|
| 1 | `look` | right-drag to look round |
| 2 | `raise` | with the Modeller's pinch (put in hand), press the land and pull up |
| 3 | `groove` | drag slowly across the land |
| 4 | `water` | with the watering can (put in hand), hold it over the land to pour |
| 5 | `tree` | bend a tree right over and let go |
| 6 | `turn` | push the rim sideways (the rim is outlined while the step is asked) |

A step completes the first time its verb is really done (`mark`). Nothing is checked while the card is up that was not checked before: the card only listens.

- **Skip** puts the card away for good, wherever it was. Verbs keep being noted.
- **Finishing** the last step also puts it away, and sends `finished`.
- **`restart`** brings the card back from step 1. It forgets only the six steps. Everything else found stays in the notes.

## The field notes

A page off the pause panel: **Field notes**, between "Save a copy as…" and "Settings". It lists all 25 verbs under seven headings (`GROUPS`: the eye, the land, trees, the edge, the sky, the case and the roll, the air).

- A verb found reads in full: its name, then how it is done.
- A verb not found is a faint dashed outline with only its clue in italic, and no name. It works the way the materials tray shows specimens not found yet.
- The top shows the count, such as "9 of 25 found". A verb found while the page is open fills in at once.
- **Walk me through it again** calls `restart` and asks for the card.
- **Back**, or Esc, returns to the pause panel.

It is one column that scrolls (wheel, Up and Down, PageUp and PageDown). The lines are sentences that wrap, and a column keeps the groups in reading order. Faint rows are short, so a new player sees most of the page at once. It uses the pause panel's linen, fonts and scaling.

With `--classic-controls` or `--no-first-steps` there is no model, and the pause panel leaves the Field notes row out (`notes_available`).

## Where it is kept

Found verbs and the skip are in `user://first_steps.cfg`, across worlds:

```
[found]
look = true
[card]
skipped = false
```

## Flags

| Flag | Does |
|---|---|
| `--no-first-steps` | leaves out the card and the field notes |
| `--first-steps` | shows the card from the top whatever was found before, and saves nothing. For probes and films |

## Still to judge on screen

- Whether the card reads as help and not a lecture, and whether it stays out of the way of the hand.
- The pocket ring: whether it is seen at all, and whether it is too much.
- Whether a faint outline invites, or just looks like something missing.
- The field notes' size, the length of the scroll, and how the dashed rows look next to the found ones.
- Whether the clues are the right size of hint.
- Whether six steps is the right number, and whether the order is.
- The wording of every line.

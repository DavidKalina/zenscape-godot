# Greybox agent brief (fill in CARD, SLUG, FOCUS)

Build a playable GREYBOX of one motif card for this Godot 4.7 roguelike
(branch roguelike). Your card: CARD. Read it, plus
docs/design/roguelike/motif-brief.md (pillars; "everything chains") and
AGENTS.md (Prototyping, Sizes, Test execution).

**What a greybox is:** a study scene where the user plays the motif with the
real pilot, judging layout, distances and chains by feel. Grey boxes for
structure (no art; RuinKit models only if trivial), but the REAL existing
traps, enemies and cannon wherever the card uses them, since the combos are
the point.

**Templates (read first):**
- studies/headless_body_isle.gd, studies/inhaler_isle.gd: greybox isles in
  open sky extending studies/character_study.gd; an EnemyField; stations;
  `place()`; R reset; `lost`.
- studies/trap_yard.gd: a TrapField, `configure(knobs)`, reset on place,
  `open_below`.
- studies/character_study.gd header: the stations format (parts "box",
  "obox", ramps, "label", "pad", water), number keys, colours (grey
  structure, orange lips to hang from, green pads, blue water), F1 numbers.
- studies/cannon_yard.gd and scripts/cannon/ for a cannon;
  scripts/traps/*.gd and scripts/enemies/*.gd for the rest.

Size every gap, ledge, shaft and run-up from the pilot's real numbers
(`Trap.pilot()`, scripts/pilot_motor.gd, WorldScale per AGENTS.md "Sizes"),
not the card's guesses; fix a wrong number and say so.

**Deliverables (new files only):**
- studies/greybox/SLUG.gd and SLUG.tscn (a Node3D with the script, like
  studies/headless_body_isle.tscn). No `class_name`; preload by path.
- The layout in ONE const data table near the top (isles: name, outline or
  rect, top, step heights/tiers; pieces, traps, enemies, stations: place and
  facing), built from that table. A stepped mass (mesa, terraces, bench) is
  one entry with tiers, so the turf pass can turn it into a `KitLand.island`
  spec mechanically.
- Number-key stations: the start, each beat, and the start of each combo
  chain. Floating "label" parts naming beats and chains.
- A missing kit piece or mechanic (the card's "Kit asks"; the round
  README's "What blocks combos today") gets the nearest stand-in from boxes,
  existing traps, or a small script in your study, labelled
  "STAND-IN: ...". Do NOT edit any existing file (motor, traps, enemies,
  cannon, character_study). If no stand-in works, leave the gap labelled.
- Append "## Greybox (round N)" to the card: run command, stations, real vs
  stand-in, which chains you made happen and which you couldn't (why),
  distances you changed.

**Prove it (headless only, never open a window).** Use the harness
(tools/README.md), and don't hunt for Godot or write your own runner.
1. Smoke: `python tools/smoke.py studies/greybox/SLUG.tscn`. It must
   PASS. It runs the shared import itself if one is needed, under a lock,
   so don't run `--import`.
2. A throwaway check through the real play loop: `scratch/SLUG_check.gd`
   extending `tools/harness/drive.gd`, run with
   `python tools/drive.py scratch/SLUG_check.gd`. Stations first:
   `python tools/drive.py tools/harness/stations.gd -- --scene=studies/greybox/SLUG.tscn`
   (he stands at every one). Check every trap or enemy builds and ticks. Then FOCUS: `walk_to` and `jump` through the input.
   For seeds or knob values, use `python tools/sweep.py`. Report honestly
   what you could and couldn't verify.

Do not commit. Final reply (200 words or fewer): run command, stations, real
vs stand-in, which chains work, what you couldn't verify.

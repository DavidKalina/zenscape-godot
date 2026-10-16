# Spec: traps in the motif editor (loop `editor-traps`)

The motif editor (`studies/motif_editor.tscn`, rounds in
`level-editor-round*.md`) places land, RuinKit pieces and trees. This loop
lets the user place the greybox traps (`scripts/traps/`) the same way:
pick one from the palette, drop it where it snaps, tune its knobs, press P
and play through it, press P and keep editing, save, and find it again on
load and in the motif yard. Placement snaps, so the user never types a
coordinate.

## Done looks like (what the user plays and sees)

1. **Traps in the palette.** Cmd/Ctrl K, type "seesaw" (or "trap"): every
   trap in the trap yard's list is there as a tile, in a Traps pocket.
   Thumbnails may be a simple drawn stand-in at first; label it so.
2. **Placing.** Dragging a trap shows a ghost of the real trap with its
   way in and way out marked (arrows or pads at `entry()` and `exit()`).
   It snaps, in this order:
   - its entry onto a **cliff lip** (`RuinKitFit.lip_near`), facing out
     over the drop, so the trap runs off the edge as in the trap yard;
   - onto a **placed piece's top** or an upward face (as kit pieces seat);
   - onto the **pilot grid** (below) when it is on.
   Z / X turn it, drag moves it, Trash and Delete remove it, Ctrl+Z undoes,
   as for pieces.
3. **The pilot grid.** A toggle (a key and a tool-roll button) shows a grid
   near the cursor whose cell comes from the pilot's real numbers
   (`python tools/kit_piece.py numbers`: a run-up jump's carry, the set-off,
   GRAB_TOP), not metres typed in. With it on, traps and kit pieces snap
   to it, and the height snaps in ledge steps. A small readout names the
   cell ("1 cell = one standing jump, x m"). Off by default.
4. **Knobs.** Selecting a placed trap opens a panel on the editor's linen
   (as the landform panel) with one field per entry of the trap's
   `defaults()`: a slider for numbers, a toggle for bools. A change rebuilds
   that trap at once. A reset button puts it back to defaults. The panel is
   generic: it reads `defaults()`, nothing is written per trap.
5. **Playing.** P (play from spawn) and Shift+P (under the camera) run the
   traps live: stepped by a `TrapField` round the real motor, their winds in
   the motor's air, knocks and tosses as in the trap yard. P back to
   editing puts every trap back as built (`reset`) and the edit view as it
   was. Falling into the void sends the pilot back as it does today.
6. **Saving.** Ctrl+S writes the traps into the motif's JSON as recipes:
   `"traps":[{id, at:[x,y,z], turn, knobs:{only the changed ones}}]`.
   Additive: files without `traps` load and build exactly as before, and
   `format` stays readable by the current loader. Reload rebuilds them
   from current code with the saved knobs.
7. **Everywhere an authored motif goes.** `scripts/kit_isle/motif_authored.gd`
   builds its traps through the greybox `live(g)` hook (`g.trap(node)`),
   so `studies/motif_yard.tscn --motif=<editor slug>` and the generator run
   them too.

## Rules for this loop

- **One trap list.** Lift the trap yard's `TRAPS` table into a shared
  registry (e.g. `scripts/traps/trap_registry.gd`: key, script, display
  name) that the trap yard, the editor and `motif_authored.gd` all read.
  The trap yard must behave as before. Keep trap keys stable: they are
  saved ids now.
- **Don't change the traps' behaviour.** A trap that can't be built or
  reset twice cleanly in the editor gets a small, additive fix in its own
  file (e.g. `reset` missing a part); note it in the commit. A trap that
  needs a deeper change is left out of the palette and listed.
- **Editor rules from AGENTS.md (The motif editor) hold:** stable ids,
  additive file format, existing `motifs/authored/*.json` build as before.
  Smoke a kit motif and an `editor_*` motif in the motif yard after any
  change to `motif_authored.gd`.
- `studies/motif_editor.gd` is already ~2450 lines. Put the new work in
  new files beside it (as `motif_editor_panel.gd` and
  `motif_editor_palette.gd` are): e.g. `motif_editor_traps.gd` (placing,
  snapping, live, save/load) and `motif_editor_knobs.gd` (the panel), with
  small hooks in the editor.
- Sizes come from WorldScale and the pilot (AGENTS.md, Sizes).
- Prototyping round: no new committed tests, no full suite. Prove each
  task with the smoke checks and a throwaway driver through the real
  editor loop (copy `tools/harness/kit_piece_editor.gd`'s approach into
  `scratch/`: place, turn, save, reload, play through with real input).

## Checks every iteration

- `python tools/smoke.py studies/motif_editor.tscn`
- `python tools/smoke.py studies/trap_yard.tscn`
- `python tools/smoke.py studies/motif_yard.tscn -- --motif=editor_aqueduct_gorge`
  and `-- --motif=bell_spires` (when `motif_authored.gd` or the kit changed)
- Anything seen (ghost, arrows, grid, panel): a rendered still of the
  editor (`tools/shot.py studies/motif_editor.tscn ... -- --no-title`),
  looked at.

## Proof at the end

A driver that, in the editor, places one trap on a lip and one on the
grid, changes a knob, saves to a temporary slug, reloads (knob and place
kept), plays and walks the pilot into the lip trap with real input until
it acts on him (a knock, toss or carry seen on the motor), returns to
editing (trap reset), then opens the motif yard on that slug and sees the
trap stepping. The temporary save is deleted. Plus stills of the editor
with a trap selected and the grid on.

Also: one small demo motif the user can open,
`motifs/authored/editor_trap_demo.json` (a few traps on an existing
landform), and a `run-*.command` line or the exact command to open it.

## Out of scope (later rounds)

Swing ropes, moving and drifting stones, cannons and enemies in the
palette; typed section ends and the join check between sections; agents
writing variations of the user's motifs. Note anything learned that bears
on them in the handoff.

## Loop

- Branch `iter/editor-traps`, worktree `.claude/worktrees/iter-editor-traps`.
- No lanes: the work is ordered and mostly in the editor.
- Model Opus (input, placement, live bodies). Cap 12 iterations, budget
  150000 tokens per iteration.

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

8. **A grey editing look** (do this next, right after the task in
   progress when it was added: it makes every later task cheaper to
   check). Editing is slow because the editor keeps the full look live
   (it re-dresses on its own ~250 ms after each change: turf, flora,
   life, sky shaders). Instead:
   - **Editing is grey by default:** the bare land (`rebuild_bare`) and
     pieces in plain flat materials (one grey for stone, one for land, the
     trap tell colours kept so traps read), no grass, flora, life, water
     shaders or cloud sky; one plain static sun and ambient light. It no
     longer dresses on its own.
   - **Play is grey too by default** (P / Shift+P): the same grey world,
     traps live, so build-play-tweak is fast.
   - **Dress on demand:** one key (G, which today re-dresses; or a tool-roll
     button) dresses into the full look as a preview, editing or playing;
     the same key goes back to grey. A small label says which look is on.
   - Saving, the file format and what the yard and generator build are
     unchanged: the grey look is the editor's view only.
   Measure the frame time while editing an `editor_*` motif before and
   after (a rendered run; say how), and put both numbers in the commit.
9. **Snappy edits** (the next task after the one in progress when this
   was added). In the grey look an edit still blocks about 1.4 s
   (iteration 3: ~1019 ms rebuilding every piece, ~355 ms the land). Aim:
   an edit answers within about 100 ms, and the full-detail rebuild never
   freezes the editor for longer than a frame or two at a time.
   - **Rebuild only what changed.** A land stroke, stamp or slider
     re-seats and rebuilds only the pieces and traps whose footprint the
     changed ground touches (the stroke's region, grown by the brush);
     moving, turning or adding a piece rebuilds that piece alone. Pieces
     untouched keep their meshes.
   - **A cheap land proxy while working is fine**, and so is something odd:
     a coarse or wireframe terrain, a low-resolution height mesh, only the
     region near the camera at full detail. Use whatever makes dragging a
     brush or a slider feel immediate. The full-detail land (grabbable
     lips, collision) is built when the hand stops, and must be in place
     before play (P waits for it).
   - **Spread the full rebuild** across frames, or move it off the main
     thread where GDScript allows, so the editor keeps answering.
   - Saved files and what the yard and generator build are unchanged.
   Measure, in a rendered run, the time from an edit (a brush stroke, a
   slider step, moving a piece) to the editor answering and to full detail
   in place, before and after; put the numbers in the commit.
10. **Inspecting up close** (the last task). The fly camera
   is hard to judge a place from, so give the user two close views,
   without leaving the editor or playing:
   - **Frame (F):** the camera swings in to the selected trap or piece
     (or what's under the cursor) and orbits it: right-drag turns round
     it, wheel moves in and out, WASD still breaks back to free flight.
   - **Eye view (V):** the camera at the pilot's eye height (from his
     real size), at the selected trap's entry looking along its route, or
     on the ground under the cursor. WASD walks it over the ground at eye
     height (it follows the land and steps up ledges, no collision needed);
     V again returns to where the camera was.
   Both glide (a short ease), and both work with a trap's ghost and the
   grid showing. Prove with stills from each view.

11. **Existing isles as a base** (after item 10; added late, the cap
   raised for it). The user wants to open the coded isles in the editor
   (colonnade_spine, broken_ring, bell_spires, ... and the aqueduct isle,
   the game's own, if it can be stood as one) and build on them. They are
   code, not recipes (land from functions, pieces placed by script), so:
   - **First, a short feasibility read** (in the commit): how the motif
     yard stands a kit pool motif or greybox slug, whether the aqueduct
     isle's place is a motif the yard can stand or needs an adapter, and
     whether a motif lists its pieces (parts, occupancy) in a form the
     editor could select.
   - **Then a base:** `--load-base=<motif id>` (and a palette / panel
     entry) stands that motif in the editor in the grey look, read-only,
     the land and its pieces collided, lips found for snapping. The user
     places traps (and anything else the editor places) on it, plays it
     (P) with its own live parts and the user's traps, and saves a recipe
     `{"base": "<motif id>", "seed", traps, pieces, markers}` that loads
     back the same and stands in the motif yard (additive format).
   - **Stretch, only if the read says it's cheap:** the base's own pieces
     selectable and movable, saved as overrides.
   Smoke a base load for at least colonnade_spine and bell_spires.

12. **Grid traps sit on the ground** (added after the demo; do it right
   after item 10, before item 11). The grid's "first 1.6 m ledge level at
   or above the ground" floats traps up to ~1.4 m over bumpy turf (the
   demo's wind blaster stands like a raised walkway). Instead: the grid
   snaps x and z only, and the trap sits on the ground as everywhere else
   in the editor. Holding a key (say which; Shift is taken by "keep
   placing") snaps the height to ledge steps for a stepped layout; then
   the nearest level, raised only as far as needed not to bury the trap.
   Saved `"on": "grid"` traps load and re-seat by the new rule; a ledge-
   stepped one keeps its step (save that as its own `on` value). Re-place
   the demo's wind blaster so it sits on the turf, and check the demo
   route still walks clean. Stills before and after.

13. **Ravine artifact** (from the user's play of the demo; a bug, first of
   13-15). Carving a ravine left a webby sheet of terrain spanning across a
   slice of the ravine. Diagnose before fixing: reproduce it (carve ravines
   on editor_trap_demo and editor_hill, several widths and depths; stills
   looking along and across the cut), find whether it is in the coarse
   land proxy (snappy edits), the full KitLand build, the cliff/lip prisms
   or the ravine stroke itself, in grey and full look, editing and after P.
   Fix it at its source; check old motifs with ravines (editor_*.json)
   still build as before or better, and say which changed.
14. **Slope tool** (the user's ask: "take something and turn it into a slope
   you can slide on, and vice versa"). A land tool on the tool roll's land
   tools (or the palette, if the roll has no room; say which):
   - **To slope:** drag a line from top to bottom (or across a band); the
     land there becomes an even ramp the pilot slides down, its angle from
     the pilot's real slide numbers (`tools/kit_piece.py numbers`:
     SLIDE_AUTO and the motor's slide), not a typed angle; no cliff steps
     or grabbable lips inside the ramp, blended at its edges.
   - **To steps (vice versa):** the same gesture turns a slope into
     terraces in ledge steps (the set-off, 1.6 m) with grabbable lips.
   - A recipe stroke like the others (additive format), undo, the snappy
     rebuild. Prove with real input: carve a slope on editor_trap_demo, P,
     the pilot slides it end to end; turn it back to steps, he climbs it.
15. **Rope bridge anchors** (the user: "rope bridges need better anchor
   points"; read here as: the bridge's ends and posts should sit on solid
   ground at the lip, posts footed in the turf, the deck meeting the walk
   height at each end, and the user able to drag each end's anchor; if the
   stills show a different fault, fix that and say so). Look first: stills
   of the bridges in editor_aqueduct_gorge and a few new runs across
   ravines of different depths, close (F, V). Then fix the anchor seating
   in the bridge run (`ruin_kit_fit.gd` bridge_run, the rope-bridge heads)
   additively: saved bridges rebuild, better seated. Prove the pilot walks
   on and off each end with real input.

16. **Base leftovers** (after 13-15, one task): the spawn on a base drops
   the pilot in mid air (the user's play of colonnade_spine: P from the
   spawn, he starts in the air); seat the spawn and rim markers on the
   base's real ground (its collision), default them to the base's own
   start where it has one, and prove P from the spawn lands him standing
   on colonnade_spine, bell_spires, stair_clouds, broken_ring and
   sundered_gorge. Also: hide the landform sliders and presets on a base;
   sundered_gorge lips found for snapping (or say why not); broken_ring's
   walk on a ledge wide enough.

17. **Whole undersides everywhere** (the user saw the broken stitching
   under other isles too; after 14-16, or earlier if an iteration has
   room). Item 13 added KitLand's opt-in `"whole_sides"` (ring_sides joins
   rings point by point) for editor motifs. Find every isle whose ring
   point count isn't a multiple of 16 (greybox isles with 260, 140, 40;
   the kit motifs; the aqueduct isle and anything else that calls
   `KitLand.island`), list them, and turn `whole_sides` on for each one
   that has long faces or holes (measure: longest underside edge before
   and after, as item 13's `scratch/sides_same.gd`). Deepen a keel only
   where a cut reaches under it. Isles at a multiple of 16 build the same,
   so leave them as they are. Stills from below before and after for the
   worst few; smoke each changed isle's scene (the motif yard, its own
   study, `studies/zenscape.tscn -- --no-title`,
   `studies/aqueduct_isle.tscn`). This changes isles outside the editor,
   with the user's go (2026-10-16).

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

**Parked by the user: the aqueduct isle as a base.** It is a study, not a
motif (studies/aqueduct_isle.gd, art from aqueduct_isle_base.gd, the foot
route and sluice hosted by the study). It needs a KitMotif adapter over
BaseArt and a new host for the foot route and sluice; the options are in
commit cc471269's Notes. Not this loop.


Swing ropes, moving and drifting stones, cannons and enemies in the
palette; typed section ends and the join check between sections; agents
writing variations of the user's motifs. Note anything learned that bears
on them in the handoff.

## Loop

- Branch `iter/editor-traps`, worktree `.claude/worktrees/iter-editor-traps`.
- No lanes: the work is ordered and mostly in the editor.
- Model Opus (input, placement, live bodies). Cap: the iterate skill's default (.claude/skills/iterate/SKILL.md, The cap), budget
  150000 tokens per iteration.

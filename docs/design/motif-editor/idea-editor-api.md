# Idea: the motif editor as a tool agents use (not started)

Parked 2026-10-16, to pick up once the `editor-traps` and `editor-enemies`
loops (spec-editor-traps.md, spec-editor-enemies.md) have proved solid in
the user's hands. Not a spec yet; a spec is written when the user says go.

## The idea

The user hand-builds sections and places in the motif editor; agents make
variations and assemble them, in the same JSON the user opens, fixes and
plays. For that, the editor and the agents share one set of operations.

## Parts

1. **A command layer** under the editor's actions: every edit (stamp,
   stroke, outline, place piece / trap / enemy, set knob, turn, snap,
   delete) is a command. The UI's clicks call them; so do scripts. The
   editor's undo stack is the starting point.
2. **`tools/editor.py`**: open a motif headless, apply commands, query,
   take stills, walk routes (the harness's drive.gd), save. Agents build
   under the same snapping, lip and pilot-grid rules the user has, so they
   can't place what the user couldn't.
3. **Queries**, not only edits: the lips, the grid cells the pilot reaches
   from a point, what's at a point, where every trap and enemy is at time t
   (the time scrubber as a query), a still from the eye view at a trap.
4. **A catalogue** command: everything placeable (kit pieces, traps,
   enemies) with its size in pilot terms, what it asks of the pilot, its
   connectors and knobs. Replaces hand-kept coverage tables.
5. **A silhouette library**: named massings (landform + big pieces) saved
   as editor JSON with a far still, seeded by the user. Agents start a
   place from one. A **far-view check** shoots the place small against the
   sky from its approach distance beside its silhouette, before handoff.
6. **Themes**: a named palette (stone, turf, water, light, sky) as an
   additive field in the motif JSON. Unchecked: how much of the look can be
   set per motif today (there are look editors in the repo); find out
   before promising it.
7. **Session logs**: the user's editing sessions saved as command logs,
   and the diff between an agent's motif and the user's fix of it, as
   examples of what the user changes.

## The path for new things: code, register, compose

Code stays the way to invent (a kit piece, a set piece, an enemy, a
landform type). Once it works, it is **registered**, and from then on
recipes place it: the user in the editor, agents through the API. What
exists: kit pieces (`tools/kit_piece.py new` registers into the palette),
traps (`scripts/traps/trap_registry.gd`, from loop editor-traps); queued:
enemies (spec-editor-enemies.md). Next: landform types (the editor's
presets and stamps, a fixed list today), then set pieces (own state and
triggers: the belfry's bell, the roost).

## The registry contract

Every kind registers the same way, so the palette, the knob panel, save
and load, play and reset, and the catalogue are built once and every new
kind gets them. An entry answers:

| Field | What |
|---|---|
| id | stable key, saved in recipes; never renamed |
| kind | piece, trap, enemy, landform, set piece |
| script | what builds it |
| name | display name for the palette |
| knobs | defaults, read from the built thing (not a copied table), with types, so the panel and the save of changed knobs are generic |
| size | in pilot terms (jumps, ledges, openings via WorldScale), for the catalogue and the grid |
| asks | the moves it asks of the pilot (the trap contract's `verbs`) |
| snaps | connectors and snap rules (lip, top, post, end, grid; `ruin_kit_fit.gd`'s kinds) |
| save | its recipe entry: the fields beyond id, at, turn, knobs (a trap's `on`, an enemy's wake and route) |
| live | how it goes live for play and back to its built state (`go_live` / reset), or "static" |
| thumb | a palette picture, or a drawn stand-in, labelled |

The existing registries (RuinKit's FAMILIES and `ruin_kit_fit.gd`, the
trap registry) are brought to this shape when touched, additively; ids stay.

## An agent's build, with all of it

Pick a silhouette, pick a theme, place sections from the catalogue, walk
the routes, check the far view, hand over the JSON. The user's fixes are the
next round's examples.

## Related, also parked

- **Enemy cycles.** Most enemies hunt reactively (the guacharo's hunger,
  the body following the head's calls), so a place can only be checked by
  playing out paths. Traps run on cycles (period, tell, window) and can be
  read, designed to and checked by time. An idle cycle while asleep, with
  hunting only once woken (the wake trigger as the line), would make
  enemies authorable and checkable the same way. A change to how enemies
  think: its own round, after the user has placed some by hand.
- **A time scrubber** in the editor: drag a slider, see every trap (and
  cycled enemy) where it is at that moment.
- **Section ends and the join check** (from the first talk): typed entry
  and exit states on traps and crossings, and a harness check that one
  section's exit feeds the next's entry.

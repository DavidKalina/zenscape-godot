# Spec: enemies in the motif editor (loop `editor-enemies`)

Queued after loop `editor-traps` (spec-editor-traps.md). It reuses what
that loop built: the palette pocket, ghost and lip snap
(`studies/motif_editor_traps.gd`), the generic knob panel, the pilot grid,
save/load in the motif JSON, live play on P with reset on return, the grey
look and the snappy rebuild. Read that loop's handoff first. Where its
pieces are generic, extend them; don't copy them.

The user places enemies the way they place traps: pick one, drop it, set
where it sleeps, what wakes it and where it goes, tune its knobs, press P
and meet it, press P and keep editing, save, and find it again on load, in
the motif yard and in the generator.

## Three ways enemies are laid today (read these first)

- **Field enemies** (`scripts/enemies/enemy.gd` and its children: plinth
  ram, millstone beetle, weeper, sun keeper, ...): stepped by an
  `EnemyField`; an authored motif's `live(g)` lays one with
  `g.enemy(script, at, face, knobs)` (`scripts/roguelike/layer_greybox.gd`).
  Table of record: `studies/enemy_yard.gd` ENEMIES.
- **The Olmec head and its body** (`scripts/enemies/inhaler_head.gd`,
  `headless_body.gd`): a motif answers `heads()` ([{at, face, knobs},
  knobs may hold a `route`]); `LayerGreybox.lay_heads` puts them in the
  plan and the stage spawns, voices and steps them, and the headless bodies
  come for them (`--knob=bodies=0` turns bodies off).
- **The guacharo** (`scripts/enemies/guacharo.gd`, laid by
  `scripts/roguelike/layer_flyers.gd` `lay`/`dress`/`setup`): a layer-wide
  flyer with a home over the widest gulf, not an `enemy.gd`.

## Done looks like

1. **One enemy list for the editor:** a registry (beside
   `scripts/traps/trap_registry.gd`) naming each placeable enemy, its kind
   (field / head / flyer), its script and display name. Keys are saved ids:
   keep them stable. The enemy yard reads it if that is a small change.
2. **An Enemies pocket in the palette**; a ghost of the real enemy (its
   look, at its real size) placed on the ground, a piece top or the pilot
   grid, facing set with Z / X; select, drag, delete, undo as traps.
3. **Sleep, wake and route, drawn in the world:**
   - **Sleep spot:** where it is placed.
   - **Wake trigger:** a radius ring the user drags out (default from the
     enemy's own knobs), or, where the enemy wakes some other way (a head's
     call heard by its body, the guacharo's exposure), that rule shown as a
     label and its knob in the panel, not a fake ring.
   - **Route:** for enemies that walk one, click out points in order (a
     line with arrows; drag a point, Delete removes it); for those that
     path on their own, none.
   The knob panel shows the enemy's knobs (`default_knobs` / its knobs
   dictionary), as for traps.
4. **The Olmec head with its body** is one placement: the head where it is
   dropped, its body placed with it (a second handle, dragged on its own),
   and a toggle for "no body". Their link is drawn.
5. **The guacharo:** placed as a home point over open air (a ring at its
   circling height), with its range and hunger knobs; one per motif.
6. **Play:** P runs them live through the same paths the game uses
   (EnemyField, the stage's heads, the flyer layer's setup) round the real
   motor. P back to editing puts every enemy back asleep where it was
   placed. A **wake now** key on a selected enemy (while playing) wakes it
   at once, so the user can test an ambush without walking up to it.
7. **Saving:** `"enemies":[{id, at, face, knobs:{changed only}, wake?,
   route?, body?}]` in the motif JSON, additive (files without it build as
   before). `scripts/kit_isle/motif_authored.gd` lays them the game's way:
   field enemies through `live(g)` / `g.enemy`, heads through `heads()`,
   the guacharo through whatever the flyer layer needs (add a small,
   additive hook if it has none for a motif's own flyer). The motif yard
   runs them on an editor slug.

## Order (the loop's trunk)

1. Registry and **one field enemy end to end** (the plinth ram: place,
   knobs, wake ring, play, reset, save, reload, motif yard).
2. **The Olmec head and body** pair, with route and the "no body" toggle.
3. **The guacharo** home point.
4. **The rest** of the field enemies that build and reset cleanly in the
   editor; any that don't are left out and listed.
5. Wake-now key; a demo motif `motifs/authored/editor_enemy_demo.json`
   (traps and enemies on one landform) and its open command; the end
   proof.

## Rules

- Don't change how an enemy thinks. A small additive fix in its own file
  so it can be built, put to sleep and reset twice in the editor is fine;
  note it. Anything deeper: leave it out of the palette and list it.
- AGENTS.md, The motif editor: stable ids, additive format, existing
  `motifs/authored/*.json` build as before; smoke a kit motif
  (`bell_spires`) and an `editor_*` one in the motif yard after any change
  to `motif_authored.gd`.
- New work in new files beside the editor (e.g.
  `studies/motif_editor_enemies.gd`); small hooks in `motif_editor.gd`.
- Sizes from WorldScale and the pilot (AGENTS.md, Sizes).
- Prototyping round: no committed tests, no full suite. Prove each task
  with smokes and throwaway drivers through the real editor input (the
  traps loop's `scratch/editor_traps_*.gd` are the pattern; set
  `root.size = Vector2i(1440, 900)` before `open()` headless).

## Checks every iteration

- `python tools/smoke.py studies/motif_editor.tscn` (plain and
  `-- --load=editor_aqueduct_gorge`), `studies/enemy_yard.tscn`,
  `studies/trap_yard.tscn`.
- Motif yard on `editor_aqueduct_gorge` and `bell_spires` when
  `motif_authored.gd` changed.
- The traps loop's drivers still pass.
- Anything seen: rendered stills of the editor, looked at.

## Proof at the end

A driver that in the editor places a ram (with a wake ring), an Olmec head
with its body and a route, and the guacharo home; saves to a temporary
slug; reloads (all kept); plays and walks the pilot into the ram's ring
with real input until it wakes and acts on him; returns to editing (all
asleep where placed); then opens the motif yard on that slug and sees the
enemies stepping. The temporary save is deleted. Stills of the editor with
an enemy selected (ring, route and body link showing).

## Out of scope

Enemy behaviour changes, new enemies, cannons, swing ropes and moving
stones, section ends and the join check.

## Loop

- Branch `iter/editor-enemies`, from `iter/editor-traps` once that loop
  finishes; its own worktree.
- No lanes (ordered, mostly in the editor).
- Model Opus. Cap 15 iterations, budget 150000 tokens per iteration.

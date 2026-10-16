---
name: motif-greybox
description: Build playable place studies of motif cards or plans, on the real terrain, pieces and look, so the user can judge the place, its routes and its threat by playing. Use when the user asks to greybox, block out or prototype motif cards.
---

# Motif place round

Stage 3 of the motif pipeline (docs/design/motifs/motif-brief.md, "From
card to isle"). Input: motif cards in
`docs/design/motifs/brainstorm/roundN/`, and their plans if any. Output: one motif per card as
`scripts/kit_isle/greybox/gb_<slug>.gd` on `scripts/kit_isle/motif_greybox.gd`
(its header says how), one line in `scripts/kit_isle/greybox/registry.gd`,
played in the motif yard (`studies/motif_yard.tscn --motif=<slug>`).

A plan (`docs/design/motifs/plans/<slug>/plan.md`, from `/motif-plan`), when
there is one, is the spec: its numbers, collectibles, enemies and landing
are built as written.

**The real look, isolated.** A place study is a slice of the real map in a
scene of its own: the game's terrain (`KitLand.island`), its pieces
(RuinKit, the live rope bridges), turf, flora, life, sky and light. Grey
boxes appear only where the kit lacks a piece, labelled STAND-IN. A card
that extends an isle that already exists (a hero such as the colonnade
spine) is built onto that isle as an opt-in knob of its motif and played in
that isle's own study scene, with a `run-<slug>.command` launcher; any
other card stands alone in the motif yard with `--sky`.

Inside each motif: land, then routes, then threat.

1. Pick the cards (the user's picks, or every motif card of the round).
2. Launch one agent per card in one message, in the background, on
   **Opus** (terrain, platforming distances and enemy placement through
   the real motor; AGENTS.md, Subagent models). Each prompt is
   [agent-brief.md](agent-brief.md) with the card path (and plan path, if
   any), the slug, the scene it is played in, and one
   **focus** line: the card's riskiest question (e.g. "is the cliff route
   a real alternative to the stair"). A card that needs a motor/trap/enemy
   change is out of scope: stand it in and list it.
3. When all are back, check whether the branch moved under the round
   (`git log` since the round began, for scripts/kit_isle, scripts/traps,
   scripts/enemies, scripts/pilot_motor.gd): other sessions land work here.
   If something a motif uses changed, resume that agent to rebuild on it.
   Then smoke every motif yourself in its scene, e.g.
   `python tools/smoke.py studies/motif_yard.tscn -- --motif=<slug>`.
4. Look at every arrival still yourself, in its scene with the real look
   (`python tools/shot.py studies/motif_yard.tscn --frame Motif_gb_<slug>
   --view three -- --motif=<slug> --sky`, or the isle's study scene). Send
   back any place that reads as boxes where the kit has the real piece.
5. Write a "Place" section into the round's README: a table of card, yard
   command, the routes, the threat, what is stood in, and your read of the
   stills.
6. Leave everything uncommitted (AGENTS.md, Prototyping). Open each place
   for the user in its scene with the real look (its launcher, or the yard
   with `--sky`), one window at a time. They judge by playing;
   picks go on to the dressing pass (`/motif-turf`).

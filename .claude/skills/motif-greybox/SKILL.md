---
name: motif-greybox
description: Build playable place studies of motif cards (from a motif-brainstorm round), on the real terrain and look, so the user can judge the place, its routes and its threat by playing. Use when the user asks to greybox, block out or prototype motif cards.
---

# Motif place round

Stage 2 of the motif pipeline (docs/design/motifs/motif-brief.md, "From
card to isle"; its first pillar, **a place first**). Input: motif cards in
`docs/design/motifs/brainstorm/roundN/`. Output: one motif per card as
`scripts/kit_isle/greybox/gb_<slug>.gd` on `scripts/kit_isle/motif_greybox.gd`
(its header says how), one line in `scripts/kit_isle/greybox/registry.gd`,
played in the motif yard (`studies/motif_yard.tscn --motif=<slug>`).

The order inside each motif is the point: **land, then routes, then
threat.** The place reads as a place before any hazard goes in.

1. Pick the cards (the user's picks, or every motif card of the round).
2. Launch one agent per card in one message, in the background, on
   **Opus** (terrain, platforming distances and enemy placement through
   the real motor; AGENTS.md, Subagent models). Each prompt is
   [agent-brief.md](agent-brief.md) with the card path, the slug, and one
   **focus** line: the card's riskiest *place* question (e.g. "does the
   gorge read as one split mesa from the arrival rim", "is the cliff route
   a real alternative to the stair"). A card that needs a motor/trap/enemy
   change is out of scope: stand it in and list it.
3. When all are back, check whether the branch moved under the round
   (`git log` since the round began, for scripts/kit_isle, scripts/traps,
   scripts/enemies, scripts/pilot_motor.gd): other sessions land work here.
   If something a motif uses changed, resume that agent to rebuild on it.
   Then smoke every motif yourself:
   `python tools/smoke.py studies/motif_yard.tscn -- --motif=<slug>`.
4. Look at every arrival still yourself (`python tools/shot.py
   studies/motif_yard.tscn --frame Motif_gb_<slug> --view three --
   --motif=<slug> --sky`) beside the same shot of an original kit motif
   (`--frame Motif_sundered_gorge ... --motif=sundered_gorge`). A motif that reads as a different game
   (grids, stacked plates, boxes on a plinth, more stone than land) goes
   back to its agent with what you saw, before the user plays it.
5. Write a "Place" section into the round's README: a table of card, yard
   command, the routes, the threat, what is stood in, and your read of the
   stills against the kit motifs.
6. Leave everything uncommitted (AGENTS.md, Prototyping). Open the yard
   for the user one motif at a time, one window. They judge by playing;
   picks go on to the dressing pass (`/motif-turf`).

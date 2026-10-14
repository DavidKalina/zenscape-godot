---
name: motif-greybox
description: Build playable greybox studies of motif cards (from a motif-brainstorm round) so the user can judge layout, distances and combo chains by playing. Use when the user asks to greybox, block out or prototype motif cards.
---

# Motif greybox round

Stage 2 of the motif pipeline (docs/design/roguelike/motif-brief.md, "From
card to isle"). Input: motif cards in `docs/design/roguelike/brainstorm/roundN/`.
Output: one playable study per card in `studies/greybox/<slug>.tscn`.

1. Pick the cards (the user's picks, or every motif card of the round).
2. Launch one agent per card in one message, in the background, on
   **Opus**: every card's chains need links placed so one throw lands in
   the next, which is spatial physics work (AGENTS.md, combos). Round 1 ran
   on Sonnet; it measured well but rarely found a layout that made a chain
   hold. A card that needs a motor/trap/enemy change is still out of scope
   for a greybox: stand it in and list it for a link-fix round. Each prompt is [agent-brief.md](agent-brief.md)
   with the card path, the slug, and one **focus** line: the card's riskiest
   link to test (e.g. "does head 1's blast land in head 2's pull", "does a
   miss land on the bench below", "does a jump off the wave clear the gulf").
3. When all are back, check whether the branch moved under the round
   (`git log` since the round began, for scripts/enemies, scripts/traps,
   scripts/cannon, scripts/pilot_motor.gd): other sessions land work here.
   If a link changed, resume the affected agents to rebuild on it before
   reporting. Then smoke every scene yourself:
   `python tools/smoke.py --greybox` (or the slugs' scenes). It runs
   the one shared import first if one is needed, under a lock, and
   reports PASS/FAIL with the errors (tools/README.md).
4. Write a "Greybox" section into the round's README: a table of card, run
   command, chains that work, chains stood in or broken, engine gaps found.
   Gaps that block combos feed the next Opus round; check them against the
   README's "What blocks combos today" list and update it.
5. Add each new greybox to `GREYBOXES` in studies/greybox/hub.gd (one
   line) and launch only the hub, one window: `--path .
   res://studies/greybox/hub.tscn -- --no-title [--start=<slug>]`, Page
   Up/Down to switch. Never open one window per greybox.
6. Leave everything uncommitted (AGENTS.md, Prototyping). Hand the user
   what to try first; they judge by playing. Remind them
   the grey look is a sketch: picks go on to the turf pass
   (`/motif-turf`).

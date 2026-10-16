---
name: motif-brainstorm
description: Run a brainstorm round of new level motifs and/or ruin-kit pieces from the shared brief (docs/design/motifs/motif-brief.md). With free text, spins many variations of that one idea. Use when the user asks to brainstorm motifs, isles, kit pieces, "a motif round", or variations of an idea.
argument-hint: "[count] [kit] [free-text idea]"
---

# Motif brainstorm round

Arguments: $ARGUMENTS

## Modes

- **No idea given: spread.** Cover new ground: lenses rolled toward the
  coverage table's empty cells. Defaults: 5 motif agents (current kit only)
  and 5 kit agents.
- **An idea given: variations.** The free text is the seed (an image, a
  mechanic, a combo, a mood: "a bell that throws you when it rings").
  Every agent keeps the seed and varies it along a different lens. Default 6
  agents, all motif cards (or kit pieces if the text says `kit` or the seed
  is plainly a piece). A leading number sets the count. One agent is
  **literal** (the seed as written, the baseline); one is **contrarian**
  (the seed inverted: it catches instead of throws, it's silent, it's
  tiny); the rest get rolled lenses. Variation agents may
  ask for new kit (their "Kit asks"), since the seed may not exist yet.

## Steps

1. Read `docs/design/motifs/motif-brief.md` (lenses, coverage, card
   formats) and list `docs/design/motifs/brainstorm/` for the next
   round number N and what earlier rounds already proposed. In variations
   mode, name the round folder `roundN-<seed-slug>`.
2. Ask nothing the user already said; the arguments and defaults above
   decide counts.
3. Roll lenses so agents spread apart: each agent a different verb and
   purpose (no two the same), plus one or two of scale, mood and shape
   among isles. Spread mode: favour empty coverage cells. Variations mode:
   favour lenses that pull the seed furthest from its first reading. Kit
   agents each get a different theme (grab/climb, moving, launch/carry,
   state-change, or ones the user names).
4. Launch all agents in one message, in the background. Models per
   AGENTS.md: motif cards from existing pieces → Sonnet; new kit pieces →
   Opus. Each prompt: read the brief first; the seed (variations mode),
   verbatim; its lens roll or theme (or "literal" / "contrarian"); the docs
   and code to ground it (pilot numbers from scripts/pilot_motor.gd,
   RuinKit's Scale section, WorldScale; scripts/pilot_motor.gd's header
   for knocks, tosses and stun locks); write cards in the brief's format to
   the round folder (motif-mK-<slug>.md, one per card; kit-kK-<theme>.md,
   one per agent), each motif card with its Layout block; brainstorm only,
   no code edits, no Godot runs.
5. When all are back, write the round folder's `README.md`:
   - a table of every card (name, lenses/theme, one line, cost);
   - **the kit-ask tally**: group the "Kit asks" and match them to any kit
     pieces proposed; rank by how many cards want them;
   - a spread pick: the 3 cards that differ most from each other (and, in
     spread mode, from the coverage table); in variations mode, say which
     beat the literal baseline and whether the contrarian found something;
   - overlaps and duplicates between agents; engine gaps that keep pieces
     from combining.

   Then draw the round: `python tools/motif_cards_html.py <round folder>`
   writes its `index.html` (each card's top and side views, routes,
   moments and notes). A card whose Layout is missing or won't parse
   shows its ASCII instead: send it back to its agent to fix. Look at the
   page yourself (a headless Chrome `--screenshot` of it) and send back
   any card whose map contradicts its text.
6. Add the round to the brief's "Rounds" list. Leave everything
   uncommitted (AGENTS.md, Prototyping). Hand the user the picks and the page
   (`open <round folder>/index.html`) and let them choose. Next stages: `/motif-plan` for a pick, then `/motif-greybox`, then `/motif-turf`.

If the user changes the brief mid round, message every running agent and
re-brief any that already finished.

---
name: motif-plan
description: Plan one picked motif card in detail before it is built: real sizes from the code, collectibles, enemy spawns and wake triggers, the landing strip, set pieces and moments, drawn as an HTML page of switchable map layers. Use when the user asks to plan, detail, spec or lay out a motif or card, or wants its collectibles, spawns or landing worked out.
---

# Motif plan

Between the card (`/motif-brainstorm`) and the place (`/motif-greybox`):
one card the user picked, worked out in detail, so the place round builds
from a spec instead of a sketch. Output: `docs/design/motifs/plans/<slug>/plan.md`
and its page `plan.html`.

1. Take the card (its path) and a slug. A place already built can be
   planned too: the plan then reads the built layout and says where it
   departs from the card.
2. Launch one agent in the background on **Opus** (sizes, enemy logic and
   landing are read from the code; AGENTS.md, Subagent models) with
   [plan-brief.md](plan-brief.md), CARD, SLUG and the user's asks filled in.
3. When it's back, draw it: `python tools/motif_cards_html.py
   docs/design/motifs/plans/<slug>/plan.md`. Screenshot the page (headless
   Chrome `--screenshot`) and look at it with every layer on. Send the plan
   back to its agent until all of these hold:
   - every number in the Numbers table names its source (file and constant);
   - the landing note gives the run's measured length against what the
     plane needs, and the strip is drawn on clear turf;
   - every enemy has a sleep spot, a wake trigger and a route;
   - every collectible has a kind, a name, a place and how it's taken;
   - the moments, set pieces and the maps agree with each other.
4. Leave it uncommitted (AGENTS.md, Prototyping). Open the page for the
   user (`open .../plan.html`) with a short summary. Next: `/motif-greybox`
   with the plan as its spec.

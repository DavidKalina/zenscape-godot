# Plan agent brief (fill in CARD, SLUG, ASKS)

Plan one motif card in detail, as the spec its place round builds from.
Your card: CARD. Slug: SLUG. The user's asks: ASKS.

Read AGENTS.md (Sizes, Motifs), docs/design/motifs/motif-brief.md (the
card format and its Layout block) and the card, with its round's README
(its gaps). Planning only: no code edits, no Godot runs, no commits.

## Gather the real numbers

Read each from the code and cite it; where the card guessed, correct it
and say so.
- The pilot: reach, grab, chain, jump gaps (scripts/world_scale.gd,
  scripts/pilot_motor.gd, RuinKit's Scale section in scripts/ruin_kit.gd).
- Each enemy: size, step, climb, leap, sight, hearing, chase speed, what
  wakes it (its script's header and knobs in scripts/enemies/).
- The landing: what a hand landing needs (scripts/plane_strip.gd,
  scripts/manual_landing.gd, a motif's `landing_run`), and the strip's
  length, direction and clearance on this layout.
- The collectibles the game has: on-foot tokens (scripts/kit_isle/
  kit_tokens.gd, buried finds in scripts/buried_find.gd), flown tokens
  (scripts/collectible_lines.gd and a motif's TOKENS: thread, knife,
  keel, break), plane parts (scripts/plane_arc/), and the ledger's
  objective types (data/ledger/, scripts/ledger/ledger.gd).
- The pieces: which exist (by id), which need a stand-in, which to build.

## Write docs/design/motifs/plans/SLUG/plan.md

```
# <Name>
Card: <path to the card>
Pitch: one paragraph.
Fit: role, footprint, height span, where it stands in the sky and its clearances.
Play: 2-4 plain sentences: what the player does and the feeling it leaves.
Set pieces: one line each: the piece, and what happens at it.

## Numbers
| What | Value | Source | Card said |

## Kit
| Piece | Exists / stand-in / build | Where it's used |

## Open questions
What the place round must answer by playing (one line each).

Layout:
(the json block)
```

The Layout block is the card format's (isles, links, pilot, threat, tips,
landing, end, moments, notes) with these layers added, all in the card's
frame:

```json
{
  "collectibles": [{"at": [x, y, z], "kind": "token|flown|buried|part|moment",
                    "name": "the ledger row's name", "how": "the move that takes it",
                    "plane": true}],
  "enemies": [{"id": "olmec", "kind": "headless body", "sleep": [x, y, z],
               "wake": {"at": [x, y, z], "r": 30, "by": "what wakes it"},
               "route": [[x, y, z], ...], "note": "what it does"}],
  "landing_note": "measured length and direction against what the plane needs"
}
```

- **Collectibles:** 4-8 for an isle, each asking for a move or a moment
  (a flown thread between two islands, a token on a ledge only the chain
  reaches, a buried find under a slam). Name them the way data/ledger/
  names its rows. `plane` marks those that need the plane.
- **Enemies:** where each sleeps or spawns, what wakes it (a radius and
  what crosses it), the route it takes and where its moves fire.
- **Moments:** 3-6, in the order met; each tied to a set piece.

Check the json parses: `python tools/motif_cards_html.py
docs/design/motifs/plans/SLUG/plan.md` writes the page with no JSON error.

Final reply (120 words or fewer): the plan path, the numbers you corrected
from the card, the landing measurement, and the open questions.

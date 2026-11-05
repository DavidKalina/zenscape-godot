# Handoff: the burrower's rocks, cracked spurs and partial walls (ITER(burrower-rocks))

Spec: `spec-burrower-rocks.md`. Branch `iter/burrower-rocks`, four rounds, each
flown by the user ("not bad, I like it", "felt pretty good").

## What's built

- **Rocks** (`scripts/endless/bore_rocks.gd`): 4-5 per tunnel by its seed, in
  gaps between spurs, clear of plugs. Tell 0.55 s (the rock swells at his head,
  glow flare, creak; the parry's rising whistle), then 38 m/s back down the
  bore, steering on the plane until 0.5 s out. A hit is a jolt, not a crash:
  shove, shake, debris, the unbanked chain lost. A surge smashes one for free.
- **Parry** (existing `parry.gd`, `parry_source`): the rock flies home along
  the bore and lands on him: a flare, a stagger (35% speed for 0.7 s) and 0.15 s
  off his lead per hit (up to 0.6 s). The parry never spends the gauge
  (a452d30b, cherry-picked from `iter/raider-embers`; applies to every source).
- **Cracked spurs** (`bore_spurs.gd`, shader): about 1 in 4 by the seed, pale
  with ember seams. A parried rock smashes the first cracked spur on its way
  home (the surge's `break_spur`) and still hits him; a solid one shatters it.
  40% of rocks are placed 45 m before a cracked spur.
- **Partial walls** (`scripts/endless/bore_gates.gd`, built on the plug): top,
  bottom, left or right, a half or two thirds closed (thirds dropped: the user
  wanted at least half). Up to 3 per tunnel, a quick plug tell, down ~0.75 s
  after he passes, ember-lit cut edge. The open part is at least
  `WorldScale.opening(7.0)`. Hitting the closed part crashes.
- **Full plug**: its hole widened, `TOY_PLUG_HOLE` 6 to 9 (12 m to 18 m).

## Play

`python3 tools/play.py -- --at=3400,4384 --heading=90 --alt=60`, then follow
him into the cave (mouth 1_1/a, ~27 s). Z rolls and parries.

## Open

- The two directions are still undecided: a forced boss fight in a looping
  tunnel (parried hits weaken him, a surge catch ends it), or an encounter
  you survive to the exit. Everything here serves both.
- Rocks still fly through plugs and walls between him and the plane.
- A solid spur stopping a parried rock is coded, never seen in a run.
- The open-part floor can trim a wall below half in a narrow bore.
- The reverse-way test pilot crashes at s ~1467 in 1_1 (its line, untraced).
- No committed tests; full suite not run. No test names these scripts.

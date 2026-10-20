# Handoff: the Olmec at a ledge, and no vanishing (prototype round `olmec-ledge`)

**Play:** `godot --path . res://studies/crag_reach.tscn -- --no-title --olmec`.
The old behaviour comes back with
`--body-knob=ledge_stare=0 --body-knob=cliff_leap=0 --body-knob=dive=1`.

## What changed

All in `scripts/enemies/headless_body.gd` behind two new knobs, off by
default and on in `OLMEC_KNOBS` (`studies/crag_reach.gd`), which drops
`dive`. olmec_field and whole_body_chase are unchanged.

**Fix 1, the ledge stare (`ledge_stare`).** At a rim in the chase with no
leap straight on, he goes to a new state `stare`:

- He plants and turns once to you with his stood steps. The head's gaze is
  already on you. The beat (`stare_hold`) counts only once he faces you and
  his steps are done, so the turn onto his way never cuts across it.
- From that stand he works out his way over frames (2.5 ms a frame, no body
  turns): a leap or drop in a fan round your way, `down_to`'s floor below,
  a face across (`leap_catch`), a cliff on land nearer you (`cliff_leap`),
  and rim stands within 18 m that he can walk to in a straight line and go
  from. Each way is scored by how far it leaves him from you plus a cost by
  kind. A way must gain 1.5 m on you.
- Then he turns once onto the way (state `stare`, `stare_why` "turn") and
  goes: the windup, or a walk to the stand, where he checks the leap again
  and goes.
- If you move 3 m, he plans again, still facing you. With no way he stays
  in the stare (`stare_why` "none") and looks again every `stare_replan`
  s. Out of his sight for `hunt_search` s, he takes your scent (as his seek
  does) and turns to where you are.
- The skirt along a rim is gone (the skirt round walls stays). Two other
  causes of the back-and-forth are fixed under the same knob:
  - Over a lip, his first stood step went the way he had before the climb,
    then back. Going into the chase now resets his heading to you.
  - His seek no longer swings ±0.9 rad. He stands turned to where he lost
    you and the gaze does the looking.

**Fix 2, no vanishing (`cliff_leap`).**

- No dive, no take, no out-of-view teleport. In crag_reach the never-stuck
  watch (`_never_stuck_ledge`) only walks him (`ledge_walk`) to the rim most
  your way to stare and plan there. If he is staring with no way, it walks
  him to another rim no more than 4 m farther from you, at most 3 times
  until you move.
- `_cliff_find`: from the rim, 11 ways round yours. It looks for a steep face
  across up to `cliff_gap` (10 Hh, 34 m), met with his feet anywhere from
  half a head height over his own down to `cliff_deep` (6 Hh, 20 m) under.
  The face needs:
  - a lip within `climb_max`, at least 5 m nearer you than he stands,
  - room over the lip and past it,
  - no shelf short of the lip (the study's `_face_clean`, ported),
  - an arc that meets that face (`_wall_arc`).
- Only catches his arc can make (`_catch_ok`): the arc is flown to where his
  feet or bulk meet the face, and `_catch_at` (split out of `_catch_wall`)
  must find the face and lip from there. This also guards the old
  `_wall_leap`. That fixed the one void fall seen in testing: a cliff leap
  at the fallen pillar's flank.
- A void fall still brings him back through the existing fall-off-world
  respawn (6 s, up a cliff). No hidden respawn was added. Now he comes back
  up a clean face with room, and a face he let go of within 2 s is noted
  and passed over next time. He isn't taken.

Smaller changes: `_down_to` and `_wall_leap` are split into finders
(`_down_find`, `_wall_leap_find`). With `ledge_stare`, a drop's bulk check
is flown turned toward the landing (as the windup turns him), not as he
stands.

## Knobs (default / OLMEC_KNOBS)

| knob | value | meaning |
|---|---|---|
| `ledge_stare` | 0 / **1** | the stare, plan from the stand, one turn |
| `stare_hold` | 1.0 s | the stare's beat once he faces you |
| `stare_replan` | 3.0 s | no way: how often he looks again |
| `cliff_leap` | 0 / **1** | cliff faces in the plan; never-stuck walks, no dive or take |
| `cliff_gap` | 10 Hh | farthest face (flat) |
| `cliff_deep` | 6 Hh | deepest catch under his feet |

Constants: STARE_MOVED 3 m, STARE_FACED 0.3 rad, STARE_US, STARE_FAN,
STAND_RADII, WAY_COST (cliff +8 m, wall +3, walk +2), WAY_GAIN 1.5,
CLIFF_GAIN 5, CLIFF_FAN, CLIFF_DOWN; crag_reach OLMEC_LEDGE_WALKS 3,
OLMEC_LEDGE_WORSE 4.

## Numbers (headless, 20 places, 60 s; before = the knobs above off, dive on)

Rim turning, per rim visit (on the ground with no floor his reach off some way
round him), counting only turns while planted. A reversal is a turn back of
more than 0.15 rad.

| | reversals/visit | rad/visit | worst visit |
|---|---|---|---|
| seen, before | 1.08 | 1.78 | 11 reversals |
| seen, after | 0.96 | 1.39 | 6 |
| blind, before | 1.48 | 2.27 | 8 |
| blind, after | 1.00 | 1.08 | 4 |

Where the reversals happen (blind):

- Before: chase skirts 27, seek swings 13.
- After: a stare's turn to you and its turn onto the way 16, chase 7, walks
  to a rim stand 2.

What's left is mostly whole decisions: turning to you, then onto the way, or
walking to a stand and then turning to the leap. Some of it is the stood
steps' anticipation, and some is the climb-after route's corners when seen.

Reach (time to reach):

| place | seen before | seen after | blind before | blind after |
|---|---|---|---|---|
| main | 0 | 0 | 0 | 0 |
| main_terrace_1 | 15 | 15 | 49 (take) | 20 |
| main_terrace_2 | 12 | 14 | 27 | **stare, no way** |
| main_terrace_3 | 22 | 21 | no (2 takes) | 27 |
| main_knoll | 5 | 6 | 5 | 6 |
| east | 31 | 30 | 38 | 33 |
| east_terrace_1 | 27 | 32 | 39 | 38 (cliff leap) |
| east_terrace_2 | 39 (take) | no, cliff leap, 7 m off* | 47 (take) | no, cliff leap* |
| east_knoll | 48 (take) | 35 | 35 | 30 |
| north | 20 | 22 | 27 | 34 |
| north_terrace_1 | 32 | 33 | 39 | 46 |
| north_terrace_2 | no (take) | 49 | no (take) | no (cliff leap in some runs) |
| west | no | no | no | **stare, no way** |
| west_terrace_1 | 31 (take) | **stare, no way** | no | **stare, no way** |
| west_spire | 19 (take) | no | no (take) | **stare, no way** |
| islet_12 | 20 | 20 | 26 | 30 |
| islet_14 | 60 (2 takes) | **stare, no way** | no | **stare, no way** |
| bridge / pillar / aqueduct | 11 / 7 / 5 | 11 / 7 / 5 | 10 / 18 / 21 | 10 / 17 / 21 |

\* At east_terrace_2 he gets there (cliff leap onto east, then a drop onto the
terrace), and his landing wave throws you off the terrace into the void. That
is the known "throw into the void" issue.

- Reached, seen: 18 to 15. Blind: 14 to 13. Every place lost was one only a
  take reached.
- Despawns (dives and takes): 16 before, **0** after.
- Falls into the void after the catch check: **0** in 80 runs. Every wall
  leap and cliff leap was caught and climbed: 4 to 6 of each kind per table.
  Before the catch check there was one, at the pillar.
- Frame times: worst 37 ms seen, 63 ms blind once, with 8 runs at a time.

**Stares with no way:** west_terrace_1, west_spire and west (the gap from
main to west is about 43 m, and the aqueduct breaks under him), islet_14 (54 m
under main's rim), and main_terrace_2 blind. At main_terrace_2 the drop's arc
puts his bulk through the rim's rock when flown turned to the landing.

## See it in play

- **The stare:** stand on islet_14 (about (-64,-24,53)), or on west_terrace_1
  (-86,30,-21). He comes to main's west rim, turns to you and holds. Walk about
  and he turns with you and plans again. Out of sight, he turns to where you
  are after about 4 s.
- **Jump to a cliff and climb:** stand on east_terrace_2 (74,19,-36). From
  main's east rim he stares, then leaps at east's west face. He catches it just
  under the lip and hauls over. (East's face is only about 5 m high there, so
  the climb is short.) Stand on east_knoll for the same move as a wall leap.
- Rendered sheets (git-ignored): `scratch/shots/stare_east_terrace_2_e_sheet.png`
  (he turns once and holds, still) and `scratch/shots/cliff_east_terrace_2_e_sheet.png`
  (windup, leap, catch, haul).

## Still off

- Ledge walks with no way (going to another rim and turning back to you) are
  2 big turns each.
- A plan takes the smallest gain (1.5 m), so he can drop to a terrace that
  helps only a little. From main's west rim toward islet_14, he drops to
  main_terrace_2 once you have moved.
- Cliff leaps are rare. On this map, faces within 34 m are mostly east's face
  from main. Climbs are short because the faces are low.
- The landing wave still throws you off narrow terraces.
- Up-close repeated pounces are not touched (as asked).
- A void fall (none seen) still respawns him after 6 s through the old
  fall-off-world path. **Suggestion:** keep it. If it shows up, make it
  visible: for example, he climbs up out of the void under the nearest mass,
  rather than appearing up a cliff near you.

## Proof

- Headless import. Smoke PASS: crag_reach plain and `--olmec`, olmec_field,
  whole_body_chase.
- Throwaway drivers (scratch/, uncommitted):
  - `olmec_reach.gd` (the reach table, plus the rim-turn measure, the reversal
    states, `--old`, `--film-stare`, `--film-cliff`, `--starelog`, `--downlog`)
  - `stare_move.gd` (you walk about while he stares: his facing error stayed
    under 0.03 rad, and he planned again each 3 m)
  - `table.sh`, `sum.py`, `cmp.py`, `cliffs.py`
- No committed tests. Full suite not run. No test refers to the changed code
  (dive, down_to, wall_leap, crag_reach), so I expect no breaks.

## Harness gaps

- `sweep.py` puts `--arg` axes after a driver's own `--scene-args`, so scene
  flags can't be passed through `--`. This round worked round it with a driver
  flag (`--old`).
- A "facing reversal" probe (turning and reversals per span while an enemy is
  planted) would be a useful `watch()` column.

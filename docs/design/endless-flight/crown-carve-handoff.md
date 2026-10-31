# The carve at the Peak: handoff

Round of 2026-10-31 on `claude/mountain-peak-visual-polish-d83e07`, not pushed. The user, after
playing the new climb: it's an open space, with nothing to fly past. This round gives the way up
things to carve past. Trail: `git log --grep='carve:'`.

**The lines are unproved.** The flight matrix was stopped at the user's word, before it finished
and before the gorge and landing re-checks, so they can run it later and make changes of their
own. Only the smoke check passed on the final code. The numbers below are partial.

## What's there

All of it is hand-sited on seed 1 in `scripts/endless/peak_carve.gd`, in the massif's frame (a, v,
y over the sea). The rock is `scripts/endless/rocks/peak_carve_rock.gd`.

- **The Dike:** a basalt wall along the prow's main crest, a 1810 to 715, 6 holes through it.
- **Two Sills:** walls across the Slot at a 1180 and a 750. Each has a low gap on the line and
  higher gaps over the crests, so it's a choice of gaps: 3 in the first, 2 in the second.
- **The Slot** (`LINE_SLOT`): the hanging valley between the prow's two crests, then over to tower
  0's root. Rock: fins and 8 eyes (a short wall with one hole on the line).
- **The Bench** (`LINE_BENCH`): the broken shelf the far side of the Dike, then up tower 2's root.
  Ruins: 15 pilgrims' pieces and 2 eyes. A gate stands on the ground if it's near the line, and
  becomes an arcade with long piers if the ground is more than 16 m under it.

## Finding it from the start

Fly at the three spires, up the glacier, to where the prow splits the valley. The ice gorge is on
the right, the rock gorge with the stair on the left.

- **Slot:** go right of the nose, low, between two tall fins. Pull up over the lip and through the
  first hole, then follow the slot between the cliffs. The next walls have a big low gap.
- **Bench:** go in at the rock gorge's mouth and pull up hard to the right over its wall (about 55
  degrees) to the first arches. Don't go on up the gorge.
- **Crossing:** the Dike is the wall on the crest between the two lines. Holes are at about a 1570,
  1480, 1365, 1160, 1040 and 860. They alternate which way they suit, Slot to Bench then back.
- **After the prow:** the Slot swings right over the top of the ice gorge to tower 0, the
  tower on the right from the front. The Bench swings left round the rim to tower 2, on the left.
  The eyes climb each root at about 50 degrees.

## Flag

`.\run-endless-flight.cmd --peak-carve=0` stands none of it. Smoke passes with it. Without the flag
the near-miss and slalom changes below are still there, but do nothing on the mountain: the gate
list is empty, and no carve stone stands for the slalom to find.

## How it's built

- Pieces are specs in `LandArches`, so they use the arches' worker build, streaming, handles
  (`peak/carve/<kind>/<n>`) and flight answers. Their cells stand from 6.5 km (`CARVE_REACH`).
- Rock is a distance field meshed on a worker, with the towers' own beds (`PeakTowerShape.strata`),
  columnar joints and blocks over it. It takes `LandRocks.bare`, so `peak_basalt` applies by height.
- The collider is the mesh at full detail. The flight solid is read off the field, half-cell
  columns, about 1.5 m. It first came from `BoxSolid.from_faces`, where a missed crossing filled an
  opening with a phantom column. **Worth knowing:** natural rock arches still use `from_faces`.
- Openings are toy widths through `WorldScale.opening`. At the defaults a table's number is the
  half size in metres.
- `NearMiss` scores a thread from `LandArches.gate_crossed`, a list of every opening. The roof ray
  counted few of them on a climb: before this, a Bench run scored 1 thread in 16 gates. A lintel
  doesn't pay twice (`GATE_QUIET`). `LineMoves` slalom now counts stone as well as trees.
- `Aqueduct.run` has a new `dry` argument: the broken span's fall read as a stark white bar.
- `rival_line.gd` skips carve pieces as candidates. Rivals still avoid them through `inside`.

## Partial numbers: medium only, seed 1 land, bot on the real stick with wobble

Light and heavy weren't proved. An earlier matrix, on older geometry, passed few of them, and
heavy fell well short on both main lines. The user only flies medium, so that was dropped.

The last medium matrix, on final geometry, 30 line runs (the two main lines on 3 wobble seeds each,
the 9 crossing lines once each, with and without Boost):

| | Through | Notes |
|---|---|---|
| No Boost, bot leads the climb 0.5 s | 15/15 | 0 scrapes. Slot 86 s, Bench 77 s. Least room past a wingtip at any opening 6.5 m |
| Boost, bot leads the climb 0.5 s | 6/15 | Scrapes on 5 of the 6, and it failed at the Bench gate near a 1390, the Slot root and upper Sill, and at x0, x1, x5, s4 |
| Boost, bot leads 0 or 0.2 s (rerun of 8 failing lines plus 2 more) | 12/12 | Slot, Bench on 3 seeds at lead 0, x0, x1, x5, s4 at lead 0, Slot and Bench at 0.2. 0 scrapes. Least room at an opening 4.5 m on the Bench, 12.3 m on the Slot |

**Read the Boost row with care.** The 12/12 came from changing the bot, not the place. A lead of
0.5 s fails 9 of 15 at the same spots across seeds, so a pilot who pulls early may well clip these
places at Boost speed. That's thin, not a margin. x2, x3, x4, s1, s2 have only the 0.5 s run with
Boost: all through, but s2's least room was 1.3 m and x2, x3 and s2 scraped.

A through-run scored about 15 threads on the Slot and 20 on the Bench. Canyon runs also scored.
**A slalom never scored in the bot's runs,** so the stone change in `_slalom` is untested. Carve,
skim and stack orbit weren't checked; orbit reads `LandRocks` only, so carve fins don't count for it.

## Cost, measured before the last geometry changes

| Rendered, the Slot line | Carve on | Off |
|---|---|---|
| Flight p50 / p95 / p99 / max (ms) | 9.5 / 31.5 / 44.5 / 55 | 9.0 / 31.7 / 40.4 / 52 |
| Frames over 33 ms in a flight | 145 | 133 |
| First 1200 frames: max, frames over 33 ms | 81.6 ms, 7 | 88.4 ms, 5 |

- That's one run each, and the p95 is the land's own.
- **The slowest commit reads 32 to 38 ms, about one 30 fps frame's worth,** so "no frame spikes"
  isn't met for certain. Which piece causes it wasn't traced. Rock meshes are packed on the worker.
  The likely suspects are the arcades.
- Worker time for everything is 21 to 30 s, slowest cell about 10 s, at 2 tasks.
- Triangles at full detail were 1.1M at the last whole count, mostly kit ruins at 90,000 to 107,000
  an arcade. Rock pieces are 4,000 to 44,000.

## Tests

Smoke passes on `endless_flight`, `--world=regions` and `--peak-carve=0`, 0 errors. The suite wasn't
run. No file under `tests/` names `near_miss`, `line_moves`, `land_arches` or `rival_line` by those
words, so a grep finds none this breaks. That's a grep, not a run.

## Not verified

- Crown matrix through the gorges, landings out of them, strip landings, spire tours, gaps between
  spires: **none re-run with the carve standing.** Piece sites keep off the gorge floors, strip,
  apron and lanes by hand. No tool checked that, though `peak_carve.gd`'s header states it.
- Nobody has flown it by hand. Motion hasn't been looked at.
- **All stills predate the last geometry changes.** The far views looked clean around the crown, but
  the side view showed the Dike's low end as a bump with a hole on the prow's skyline. It was lowered
  30 m to answer that, and hasn't been looked at again.
- Collider against the flight solid wasn't measured. Trees don't keep off the pieces. Breaks on the
  ruins weren't tried. Dusk, night and other hours: unseen.

## Weak

- **Pieces stop at about 1120 m on the Slot's root and 1100 m on the Bench's.** The lines run on to
  about 1250 m, but nothing stands on the spires, because anything big enough to fly past would
  break their outline. So the last 200 m and more to the tips has only the spire and its clouds.
- **There's little over the plateau.** A plane on the direct climb, 100 m or more over the prow, has
  the pieces below it. The Bench has a gap of about 300 m at the strip's lane. A ruined colonnade
  round the rim was considered and not built.
- **A climb steeper than the lines has nothing near it.** The lines rise at about 20 degrees, 50 on the
  roots. That's the user's complaint for anyone who pulls straight up.
- **Reading it in shade:** the front of the mountain sits in its own shadow, so in the Slot rock is
  near-black on near-black. Gaps read when there's sky or snow behind them, not otherwise.
- **Far clouds show over shaded rock,** in a band at horizon height. It shows on the carve's walls,
  and a cloud shows the same way on a shaded cliff with the carve off. Not traced.
- A hole's shape can still read a bit round and placed. Eyes on the roots look like slabs from some
  angles.
- The tables are fitted to today's land: a land change wants them refitted.

## `docs/art/model-budget.md`

| Trick | Applies | Estimated saving |
|---|---|---|
| Import LODs | In: vertices clustered at 2 and 4 cells | Already taken, roughly a quarter and a sixteenth of the triangles. Kit ruins use `RuinLod` |
| Fewer arcades, or thinner kit detail | The real one: arcades are about half the triangles | Dropping them to `set_detail` thinned spans could save 300-400k of 1.1M; under 0.5 ms by estimate, not measured |
| Skip the buried floor and back faces | The field closes under the land | About 15% of rock triangles; under 0.1 ms |
| Sculpt high, bake low | Possible; the rock is 3 m cells, with detail from RockShape and paint | 30-50% if cells went to 4-5 m, but it risks the broken edges that keep it from reading as clay |
| Silhouette geometry | Already the method: joints and holes are real | None further |
| Vertex-colour grime | Partly: a shade noise | Look only |
| Parallax depth, rigid parts on bones | No | None |

## Next

Run the matrix when wanted. Drivers are in the git-ignored `scratch/carve/`: `fly.gd` (`--line=
slot|bench|x0..x5|s1|s2|s4`, `--lead`, `--noboost`, `--perf`), `par.py`, `shots.gd`, `env.gd` (the
land's top along a line, for fitting) and `probe2.gd` (a cross-section of an opening). The bot's
medium lead defaults to 0.5 s, the setting that fails with Boost, so pass `--lead` deliberately.
`climb_proof.py`'s medium copy is `scratch/carve/proof_medium.py`, not yet run.

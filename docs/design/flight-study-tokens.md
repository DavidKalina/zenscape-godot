# Flight study: token placement (round 5, tokens pack)

Branch: `study/flight-tokens` (from main 752c98f8). The question for this
round: **in the same space, which way of placing tokens makes flying it
fun?** Nine new stations keep their geometry exactly as it was and change
only where the tokens go. Six use `sundered_flow`'s hall (key 0, the only
5/5 so far) and three use `open_swoop`'s two lone pillars (key 7, open air,
fun 2). The work is greybox only, and no main station changed: every
existing hash is still pinned, and their bench numbers are unchanged.

## Launch

    ./run-flight-tokens.command                                   # starts in the pack; N cycles within it
    ./run-flight-tokens.command --station=tokens_hall_detours     # straight to one
    ./run-flight-tokens.command --station=tokens_hall_hidden --bot=sharp
    godot --path . res://studies/flight_study.tscn -- --no-title --pack=tokens

    godot --headless --path . -s tools/flight_bench.gd -- --pack tokens --runs 20               # bots chase bonus tokens
    godot --headless --path . -s tools/flight_bench.gd -- --pack tokens --runs 20 --no-bonus    # the main line alone
    godot --headless --path . -s tools/flight_tokens_check.gd -- --pack tokens   # rooms, needs, bonus visibility; no flying
    python3 tools/flight_tokens_layout.py                                        # regenerate scripts/flight_pack_tokens.gd

The pack's stations have no digit key. N steps through them, and without
`--pack` it carries on from `-` into the pack. Bonus tokens are drawn
**blue**, normal tokens gold. Guides are not drawn. The HUD shows
`bonus n/m`, and the end panel shows a "Bonus tokens" line.

## What's new under the hood (minimal, opt-in per station)

- **Guides** (`"guides": [indices]`) are points of the route that are not
  drawn and not counted toward `collected`, the total or the clear. They
  keep the line whole, so the metrics' line, the rooms and the demand are
  the same as the dense trail's, and the bots fly the same route. This is
  how sparse and gate-only share sundered_flow's line while showing 5 or 9
  of its 21 points. A guide otherwise behaves like a token, including the
  "taking a later one misses earlier ones" rule.
- **Bonus tokens** (`"bonus": [Vector3]`) are optional and sit off the
  line. They are unordered and never missed, and they aren't needed to
  clear. A bonus is taken whenever the path passes within reach, and it
  has `bonus_seen` / `bonus` events. Its metrics are `bonus_total`,
  `bonus_taken` and `bonus_seen`, added only when the station has bonus
  tokens. `FlightCourse.tight` flags a bonus where level wings don't fit,
  meaning it needs the knife edge.
- **Bot** (still VERSION 2: it behaves exactly as before on any station
  without bonus tokens). A bot goes for a bonus once it has seen it for its
  reaction time (perfect knows all, as on a second pass), if the bonus is
  ahead within 45° and 30 m with a clear line, **and nearer than the next
  token it needs**. It never trades a required token for a bonus. While
  chasing, it aims at the bonus alone and goes on edge for a tight one,
  `knife_lead` s out (with its `knife_forget` chance). `"bonus": false` in
  its params, or `--no-bonus` on the bench, turns this off.
- **Packs**: `scripts/flight_pack_tokens.gd` (generated) is appended to
  `FlightCourse.STATIONS` (`] + TokensPack.STATIONS`). Each station has
  `key -1` (`NO_KEY`), `pack`, `style` and its own `origin`, in a row at
  z +1300, so merge order never moves it. `Course.pack(name)`,
  `key_name`/`station_by_key` handle the sentinel, and the study's floor
  now covers every origin. The hash includes guides and bonus only when
  present.
- **Survey cache**: its key now includes the origin. A copy of a station
  with the same hash at another origin would otherwise get the first
  copy's knife zones, which are in world space. No numbers change.

## The variants

### The hall (sundered_flow's 15 bays, unchanged)

| id | style | tokens | what |
|---|---|---|---|
| `tokens_hall_dense` | dense | 21 | the baseline: sundered_flow's own trail, a token at every bay line. Its hash is the same as key 0's, since it is the same layout |
| `tokens_hall_sparse` | sparse hints | 5 (+16 guides) | one token at each opening that tells you which way to go: over the first high tie, under the low tie, out the torn end, under B's low tie, out of the roof. The rest of the line is yours to find |
| `tokens_hall_gates` | gate-only | 9 (+12 guides) | one token per opening, at the moment you pass it: the gate's mouth, the three ties of A, the torn end, B's mouth, B's two ties, the roof exit |
| `tokens_hall_detours` | risk detours | 6 + 4 bonus | an easy line (the gate, A's low tie, A's second high tie, the torn end, B's mouth, the roof) plus four bonus tokens: **under** the first high tie where the line goes over it, a knife-edge gap between a row column and the wall at A's bay line 24, and **both** of B's knife slits (the lane the line weaves past). The openings a detour takes the other way are guides, so a detour never costs a token |
| `tokens_hall_hidden` | hidden | 9 + 5 bonus | the gate-only line plus five bonus tokens the line never shows: on A's roof, in the lee of a column, just outside the arch breach, under A's floor at its torn end, in an alcove of B's right aisle. All read 0-0.1 s in view from the line |
| `tokens_hall_outback` | out and back in | 27 | a new route: down A's corkscrew, out through the **arch breach** in its left wall at 60°, round a 9.5 m loop outside along the wall, back in over bay 8's torn wall, out the end and on to B as before. A dense trail, so the comparison is with dense |

### Open air (open_swoop's two pillars, unchanged)

| id | style | tokens | what |
|---|---|---|---|
| `tokens_swoop_dense` | dense | 8 | the baseline: open_swoop's own trail (same hash as key 7) |
| `tokens_swoop_skim` | skim the rock (gate-only) | 2 (+10 guides) | a wider S that passes each lone pillar close (the line about 1.8 m from its face, the wingtip about 1 m), with a token only at each skim |
| `tokens_swoop_detours` | risk detours | 8 + 3 bonus | the baseline plus bonus tokens tight on each pillar's face and one behind the second |

## Comparison (20 runs per skill, bots VERSION 2; reference = perfect bot)

"Main line" is `--no-bonus`, where the bots ignore bonus tokens. "Greedy"
is the default, where the bots go for bonus tokens under the rule above.
The line numbers (threading, flow, demand) are the main-line reference.
Clear rates are sloppy/decent/sharp/perfect.

| station | tokens | clear, main line | band | clear, greedy | bonus taken (of n) | threading | openings/s | still | longest straight s | demand peak / mean | time s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| hall_dense | 21 | 0.00/0.90/1.00/1.00 | medium | = | – | 37% | 0.45 | 4% | 0.32 | 0.67 / 0.42 | 13.4 |
| hall_sparse | 5 | 0.15/1.00/1.00/1.00 | medium | = | – | 37% | 0.45 | 4% | 0.32 | 0.67 / 0.42 | 13.4 |
| hall_gates | 9 | 0.00/1.00/1.00/1.00 | medium | = | – | 37% | 0.45 | 4% | 0.32 | 0.67 / 0.42 | 13.4 |
| hall_detours | 6 + 4 | 0.15/1.00/1.00/1.00 | medium | 0.05/0.75/0.70/1.00 | 1.6/2.1/2.9/**4.0** of 4 | 37% (46% greedy) | 0.45 | 4% | 0.32 (0.52) | 0.67 / 0.42 | 13.4 (18.1) |
| hall_hidden | 9 + 5 | 0.15/1.00/1.00/1.00 | medium | 0.05/0.80/0.25/**0.00** | 0.3/0.0/0.1/1.0 of 5 | 37% | 0.45 | 4% | 0.32 | 0.67 / 0.42 | 13.4 |
| hall_outback | 27 | 0.00/0.10/1.00/1.00 | **hard** | = | – | 34% | 0.33 | 7% | 0.33 | **0.89** / 0.48 | 15.1 |
| swoop_dense | 8 | 0.70/1.00/1.00/1.00 | easy | = | – | 0% | 0 | 14% | 0.57 | 0.24 / 0.18 | 9.3 |
| swoop_skim | 2 | 0.95/1.00/1.00/1.00 | easy | = | – | 0% | 0 | 22% | 1.43 | 0.48 / 0.26 | 11.3 |
| swoop_detours | 8 + 3 | 0.75/1.00/1.00/1.00 | easy | = | 0/0/0/0 of 3 | 0% | 0 | 14% | 0.57 | 0.24 / 0.18 | 9.3 |

Bonus tokens: how long each is in view from the line (`flight_tokens_check.gd`)

| station | bonus | in view from the line | tight (knife edge) |
|---|---|---|---|
| hall_detours | under the first high tie | 1.4 s | no |
| | aisle gap at A24 | 2.4 s | yes |
| | B's first slit | 1.7 s | yes |
| | B's second slit | 2.0 s | yes |
| hall_hidden | on A's roof / behind a column / outside the arch / under A's floor | 0.0 s each | no |
| | B's right-aisle alcove | 0.1 s | no |
| swoop_detours | skim pillar 1 / skim pillar 2 / behind pillar 2 | 0.3 / 1.6 / 1.4 s | no |

How to read it:

- **Dense, sparse and gate-only fly the same line**, so their threading,
  flow and demand are identical. What changes is forgiveness: fewer
  tokens means fewer to miss, so decent goes from 90% to 100%. The
  differences that matter here (whether a player finds the line from five
  hints, and whether a token at every bay line feels like breadcrumbs or
  like rhythm) are things bots can't measure. That is the human test.
- **Risk detours give the clearest skill gradient of anything so far.**
  The main line is as forgiving as gate-only (decent 100%). Greedy, the
  bonus count climbs with skill (1.6, 2.1, 2.9, then 4 of 4 for perfect),
  which is "skill as optional mastery". Even with the never-trade rule,
  greed costs the main line some of the time (decent 75%, sharp 70%). The
  three knife-edge bonuses mean long wall scrapes for any bot that arrives
  misaligned (100-250 bumps per run on average). The greedy reference
  threads more (46%) but has a longer straight (0.52 s).
- **Hidden is a trap when the hidden token sits next to a gate.** Four of
  the five are never seen from the line, and the bots take about 0 of them.
  The one bots do glimpse, B's right-aisle alcove, gets chased and costs
  the high tie just after it, so sharp's greedy clear drops to 25%. The
  perfect bot, which "knows" them all as if on a second pass, goes for
  them and clears 0%. A secret should sit where going for it doesn't wreck
  the line, or on a line of its own.
- **Out and back in is the only hard variant**, and that comes from the
  geometry, not the tokens. The arch's near jamb sits 1.4 m past the row's
  s48 column, so the line can't turn out until it is past the column, and
  must then cross the row and the wall in about 4 m: a 60° crossing at about
  1.0 × TURN_RATE. Sharp clears 100% (about 1 bump) and decent 10%.
  Openings per second fall (0.33 against 0.45), because the loop outside is
  open air, and still rises to 7%.
- **Open air: tokens alone don't make it threading.** Skimming the pillars
  leaves threading at 0% (a single pillar on one side isn't threading by
  the metric). The wider S is stiller (22%, longest straight 1.4 s) and its
  demand doubles. Whether a 1 m wingtip skim *feels* like threading is a
  human question. On the swoop, the bots never go for the detour bonuses,
  because the dense trail always has a needed token nearer. **A dense trail
  crowds out detours.**

## Surprises

- **Opposite-side bonuses cost the token they mirror.** The first detours
  layout kept every gate token and put a bonus *under* a tie whose token
  was *over* it, and bonus slits beside a required token. Every bot,
  perfect included, cleared 0%. The fix is a design rule worth keeping: on
  a detour, the opening it takes the other way must not have a required
  token.
- **The bot cut past a bonus.** Its look-ahead ran on to the next token, so
  it swerved toward the bonus but never got within reach. While chasing, it
  now aims at the bonus alone.
- **Sloppy's bump counts are seed noise.** The same line gives 3, 13 or 32
  mean bumps on dense, gates and sparse, because the bench seeds by station
  id and one long wall scrape is 100+ bumps. Compare sloppy's clear rates,
  not its bumps.
- **The outback loop needed a fine polyline.** With four points round the
  loop, sharp cut from the arch to the next point and scraped the far jamb
  (5-65% clear across tries). With six points on the arc, it is 100%. Tight
  curved lines need tokens (or guides) every 3-4 m, or the pursuit chord
  cuts into the stone.

## Unverified

- **Nobody has flown any of these by hand.** The study is in fun, and the
  bots don't measure fun, discovery or the joy of a secret. The comparison
  above is skill and forgiveness only.
- I took 8 rendered stills (`tools/capture_flight_tokens.gd`, in
  /tmp/flight_tokens). The hall layouts read right: the outback trail
  visibly goes out the arch and back over the torn wall, and the hidden
  bonus tokens are on the roof and outside the arch. The skim tokens sit
  beside the pillars. I didn't check the chase-camera views closely, the
  blue bonus colour against the grey, or whether a knife-edge bonus in the
  aisle gap can be read from the chase camera.
- The bots' bonus rule (45°, 30 m, nearer than the next needed token) is a
  guess at a sensible player. A person may happily sacrifice a token for a
  shiny one.
- The knife-edge bonuses rely on a crude lean (it goes on edge by distance,
  with no line-up), so the bots' scrape counts there overstate how hard
  they are for a person.
- Tests: I ran the headless import check, `run_tests.py --tests
  'test_flight_*.gd'` (4/4 pass, including the new `test_flight_tokens.gd`)
  and the bench. I did not run the full suite. The user's 40 `_human_`
  run files were checked by md5 before and after the saved bench, and are
  unchanged. The saved bench is the `--no-bonus` one, so `bands.json`
  holds the main-line bands.

## Files

- `scripts/flight_pack_tokens.gd` (generated), `tools/flight_tokens_layout.py`
  (the generator, reusing `flight_flow_layout.py`'s hall frame).
- `scripts/flight_course.gd`: the pack appended, `NO_KEY`, `pack()`,
  `origin` override, `guides()`, `bonus()`, `tight()`, hash and survey-cache
  keys.
- `scripts/flight_run.gd`: guides not counted, bonus tokens seen and taken,
  `required()`, `bonus_taken()`, and the JSON's `guides`, `bonus` and
  `result.bonus`.
- `scripts/flight_metrics.gd`: `collected`/`total` without guides, and
  `bonus()`.
- `scripts/flight_bot.gd`: bonus chasing (`_bonus_target`, `_bonus_lean`).
- `tools/flight_bench.gd`: `--pack`, `--no-bonus`, `pack_table`.
- `tools/flight_tokens_check.gd`, `tools/capture_flight_tokens.gd` (new).
- `tools/flight_trace.gd`: bonus indices in the event list.
- `studies/flight_study.gd`: `--pack`, N within the pack, guides hidden,
  blue bonus tokens, floor over every origin, and the HUD and panel bonus
  lines.
- `run-flight-tokens.command`, and the tests `test_flight_tokens.gd` (new)
  and `test_flight_metrics.gd` (the 9 pack hashes pinned in their own
  dict).

## Suggested next round

1. **Fly the pack and rate each one**, especially dense vs sparse vs gates
   on the same line (does the line feel the same with 5 hints?) and
   detours (do the blue slits tempt you?). That is the round's real data.
2. If detours win, write the rules down: an easy line with no token at the
   openings a detour takes the other way, bonus tokens seen 1-2 s ahead,
   and the hard ones on a knife edge. Then bench generated detour layouts
   against them.
3. Hidden should get its own line: a secret that's reached by leaving the
   main line *between* gates, not beside one.
4. For a forgiving out-and-back, the geometry has to change, which was out
   of scope here: a wider breach, or no column right before it, so the turn
   out can start earlier.
5. Make the bots' bonus appetite a skill knob (sloppy timid, sharp greedy)
   and give the knife-edge bonus a real line-up, so bump counts mean
   something.

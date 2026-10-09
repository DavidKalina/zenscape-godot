# Flight study: the nature pack (round 5, natural formations)

Branch: `study/flight-nature` (from main 752c98f8). Five greybox stations
built from natural landforms, in the spirit of Wuhu Island's flyover rather
than a ruined hall: a river canyon, a sea-stack field, a waterfall cove, a
ridge and a sea cave. Each one was laid out flow-first. The line came
first, drawn so that it never settles, and the rock was then stood round
it in the line's own frame. Only greybox, no art.

## Launch

    ./run-flight-nature.command                          # starts at the canyon; N cycles the pack
    ./run-flight-nature.command --station=nature_cave    # start at one station (still inside the pack)
    ./run-flight-nature.command --bot=sharp              # watch a bot fly it
    godot --path . res://studies/flight_study.tscn -- --no-title --pack=nature
    godot --path . res://studies/flight_study.tscn -- --no-title --station=nature_ridge

The pack's stations have no digit key (`key` -1). They come after
`sundered_mix`. N reaches them from there, and `--pack=nature` starts at
the pack and keeps N inside it. The sign over each entry shows the name
without a key.

Bench and layout:

    godot --headless --path . -s tools/flight_bench.gd -- --station nature_stacks,nature_cove,nature_canyon,nature_cave,nature_ridge --runs 20
    python3 tools/flight_nature_layout.py --check              # the designed line's needs, flow, room, threading, extent
    python3 tools/flight_nature_layout.py --png /tmp/n         # top views (north up), /tmp/n_<id>.png
    python3 tools/flight_nature_layout.py --station ridge --png /tmp/n --zoom 50,120 --px 0.25
    python3 tools/flight_nature_layout.py --write              # rewrite the stations in the pack file

Edit the tool, not the numbers in the pack file. `--write` rewrites the
block between the `# >>> nature stations` and `# <<< nature stations`
markers in `scripts/flight_pack_nature.gd`.

## Files

- `scripts/flight_pack_nature.gd` (new): `STATIONS`, written by the tool,
  and `part_solids`, which expands the three new part kinds into the
  course's own boxes and drums. Because of that, room, threading rays,
  colliders, drawing and the camera all work unchanged.
- `scripts/flight_course.gd`: preloads the pack.
  - `STATIONS` is `[...]+Nature.STATIONS`, a one-line change at its end.
    Other packs append the same way.
  - `solids` hands `wall`, `stack` and `arch` to the pack.
  - `key_name` returns "" for key < 0, and `station_by_key` ignores
    negative keys.
  - New: `pack_stations(pack)`.
- `studies/flight_study.gd`: `--pack=<name>` and `pack`. `next_station`
  cycles inside the pack. The sign drops an empty key.
- `tools/flight_nature_layout.py` (new): the layout tool.
- `run-flight-nature.command` (new).
- Tests:
  - `test_flight_metrics.gd`: pins the five nature hashes in their own
    `nature_pins` block. The 11 existing pins are untouched, and the
    existing hashes are unchanged.
  - `test_flight_bench.gd`: the pack has five keyless stations, and each
    stands. The sharp bot clears each one with 0 bumps. The perfect line
    (look 9) keeps swinging (still ≤ 10%, longest straight ≤ 0.8 s) and
    threads at least 10%.

## New part kinds

All are in station metres, with the floor at −40 (`-ALT`).

- `["wall", [Vector3(x, top, z), ...], thick, side]`: a strip of rock.
  - It is one box per pair of points, from the floor up to their mean top.
  - Its face lies on the points. The rock is on `side` of them: +1 right of
    the way they run, −1 left, 0 centred.
  - A drum at each inner point fills the chink where two boxes meet at an
    angle.
  - Used for canyon walls, sea cliffs, the ridge, the notch sills, the
    waterfall sheet and the cave's sides.
- `["stack", Vector2(x, z), base r, top r, top, hole]`: a tapered sea stack
  of 7 m drums.
  - `hole` is `{}` or `{"y","w","h","yaw"}`: a tunnel through the stack,
    with two blocks either side of it at that height.
- `["arch", bottom-middle, width, height, depth, yaw, crown, sill, (leg)]`:
  a natural arch.
  - The legs run from the floor up to `crown`.
  - The soffit has 8 slices. It is upright to 40% of the height, then a
    half ellipse.
  - With `sill`, it is a hole through a rib. Without it, it is a bridge.
- The cave's roof and its pinnacles are plain `box` parts.

## How a line is designed (`flight_nature_layout.py`)

- The line is integrated from **heading knots** (degrees) and **climb
  knots** (flight path angle).
- Both ease between their knots by half a cosine. The heading is blended
  50% toward straight interpolation (`TURN_LIN`), so an S flips its turn at
  the knot and never lingers near zero curvature. Before this, every
  inflection was a short "straight" in the flow metric.
- A `bob` adds a gentle up-and-down. Its pitch swings hardest exactly where
  the turn flips (round 3's hand-over of axes). It is ±0.08 to 0.14 rad of
  path angle, so about 1 to 2 m of height.
- The rock goes in the line's frame. For example: canyon walls 6 m either
  side, with the inside of a bend 1.8 m closer. A stack's surface 4.5 m off
  a bend's apex. An arch square across the line, its soffit 4.4 to 5 m over
  it. So the room is set by design.
- Tokens sit at the moments (a bend's apex, through a gap, under an arch,
  in a tunnel, through a skylight) and are spread evenly between them,
  about 10 to 11 m apart.
- `--check` also tests round 4's "3 m past" miss rule against every
  earlier point on the line. No station curls back. The worst margin is
  −6.2 m everywhere.

## The stations

Each station is 270 to 330 m of line, about 19 to 23 s.

| id | what you fly |
|---|---|
| `nature_canyon` | A winding river canyon, 12 m wide at the line. S-bends of ±30° hug the inside wall, under a natural arch (s 118). Then up and **out over a low saddle**, where the walls fall away below you, past two hoodoos, and **back down into the next reach**. More bends, then out under a natural bridge (s 318) while climbing. Stepped benches over the walls. 34 tokens at every bend's apex, both arches and the hoodoos. |
| `nature_stacks` | A sea-stack field and a lazy ±22° weave. Each bend wraps round a stack on its inside, 4.5 m off, with another across the way 7 m off. Pairs of slim stacks make a gate at every crossover. Down low among the stacks' feet, **through a tunnel in a big stack** (7 × 6.5 m, s 150), then a long climb out under a sea arch. 55 scattered stacks fill the field. `ease` 1.3. |
| `nature_cove` | Along a sea cliff (on the right, 5.5 m off, 15 m tall) past stacks on the open side. It turns in to the cove (+60°), diving 14 m, round the back **behind the waterfall** (a sheet 4.5 m left, so a 10 m way between fall and cliff), then up and out **through an arch in the headland** rib (−44°). `ease` 1.3. |
| `nature_ridge` | Hugging a ridge's east face (4.5 m off), with pinnacles on the open side to pass between. A ±64° S **through a notch** to the west side, then **under an overhang** shelf (3.6 m over the line, s 140 to 176). A second S **back under a natural bridge** over a second notch to the east side, then up over the ridge's falling end. The ridge is 18 m thick and 13 m tall. |
| `nature_cave` | **In at a sea cave's mouth**, weaving inside (walls 6 m off, roof 6 m over the line). **Up and out through a skylight** in the roof, over the roof between two pinnacles, **back down in through a second skylight**, and out at the far mouth. |

This is the user's "leaving and coming back in" five ways: the canyon's
saddle, the stack tunnel, the ridge's two crossings, the cove's headland,
and the cave's two skylights.

## Bench (VERSION 2 bots, 20 runs; reference = the perfect bot's best, which is its fastest clear: look 12)

| station | band | clear sl/de/sh/pf | time s | demand peak | room min m | **threading** | openings/s | **still** | straights | **longest s** | yaw share | swing rev/s | bumps sl/de/sh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **sundered_flow** (5/5) | medium | 0.0/0.9/1.0/1.0 | 13.37 | 0.67 | 0.59 | 37% | 0.45 | 4% | 0 | 0.32 | 65% | 0.75 | |
| nature_stacks | **easy** | 0.8/1.0/1.0/1.0 | 22.53 | 0.31 | 2.21 | 13% | **0.67** | 5% | 0 | 0.43 | 71% | 0.31 | 0/0/0 |
| nature_cove | **easy** | 0.6/1.0/1.0/1.0 | 18.85 | 0.18 | 2.21 | 25% | 0.48 | 8% | 0 | 0.40 | 74% | 0.27 | 0/0/0 |
| nature_canyon | medium | 0.0/1.0/1.0/1.0 | 22.90 | 0.39 | 1.70 | **63%** | 0.35 | 6% | 1 | 0.50 | 75% | 0.39 | 0.25/0/0 |
| nature_cave | medium | 0.1/1.0/1.0/1.0 | 19.65 | 0.27 | 1.70 | 52% | 0.10 | 5% | 0 | 0.38 | 59% | 0.51 | 0.6/0/0 |
| nature_ridge | medium | 0.1/1.0/1.0/1.0 | 22.42 | 0.38 | 1.69 | 21% | 0.31 | 5% | 1 | 0.65 | 75% | 0.36 | 0.05/0/0 |

The room column is capped by the token reach, which is 2.21 m on the two
eased stations. Bumps are means per run. The bench is saved in the usual
`user://flight_runs`, so `bands.json` holds these bands under their
hashes, and the study's end-of-run report shows them.

Hashes:

| station | hash |
|---|---|
| canyon | 9ccee47628b3 |
| stacks | 70f8a5630bc8 |
| cove | ea9f8c1d807f |
| ridge | 7dc1b3277775 |
| cave | c3f1c938a98b |

How the pack reads:

- **Forgiving at decent everywhere.** Decent clears every station 20/20,
  sharp and decent never bump, and room never drops under 1.69 m. Demand
  peaks are 0.18 to 0.39, against 0.67 for `sundered_flow`.
- **The spread is two easy and three medium. Nothing is hard.** A hard band
  needs decent under 60%, which is the opposite of "forgiving at decent".
  Skill is left as optional mastery: hugging the inside walls, cutting
  closer to the stacks.
- **Flow is at `sundered_flow`'s level.**
  - Every perfect line is 5 to 8% still, against 4%.
  - The longest straight is 0.38 to 0.65 s, against 0.32.
  - The designed lines themselves are 0 to 1% still. What remains comes
    from the look-12 bot cutting corners.
  - At look 9 (the test), every station is 2 to 4% still with no straight
    over 0.4 s.
- **Sideways share is 71 to 75%** (59% in the cave, which climbs out and
  dives back). That is the side-to-side the user asked for. The
  verticality is long climbs of 10 to 14 m over 50 m.
- **Threading.**
  - The canyon (63%) and the cave (52%) are enclosed nearly throughout.
  - The stacks have the most openings per second of any station so far
    (0.67), a gate or wrap about every 1.5 s, but are only 13% enclosed.
  - The cave is one long spell (0.10/s), because the threading rule counts
    the roofed stretches as one opening each.

## Surprises

- **Sloppy can't clear long stations on noise alone.** On the gentlest
  line (need 0.21), sloppy took 25 to 35 of 35 tokens. Each miss was a
  random wobble outside the 1.7 m reach, not a hard spot, and over 30+
  tokens they add up. Two levers made the easy stations easy:
  - Tokens at the moments, about 10 to 11 m apart instead of 9.
  - `ease` 1.3, a 2.2 m reach, the same lever `sundered` uses at 1.05.
  - Only the stacks and the cove have `ease`. The cove sits on the line at
    sloppy 0.6, so its band can flip between benches.
- **The perfect reference flattens small wiggles.** The bench keeps the
  perfect bot's fastest clear, which is look 12. It cuts through ±10°
  wiggles and through bobs under about 1 m, and reads them as straights.
  The ridge's face sections were ±10° at first and read 14% still. At
  ±14° with a 0.14 bob, they read 5%.
- **A ridge crossed at an angle needs its cut ends pulled back.** A box
  cut square to the ridge leaves a corner that juts into a diagonal line.
  Cutting so the nearest corner stands NOTCH (6 m) from the line fixed it,
  but the notches read wide on the diagonal.
  - My first idea for the second crossing was a 9 × 7 m tunnel through
    the 18 m ridge, a block square to the line. The line still curves as
    it crosses, so it clipped the block's corners (room −0.2 m).
  - It became a bridged notch: a natural bridge over a second notch.
- **The cave's skylights are long.** A slot in the roof has to cover the
  whole stretch where a gently climbing line passes through the roof's
  height (±2 to 3 m), so the skylights are 24 to 32 m long. They read as
  slots, not round holes.

## Rendered stills

Four stills of the canyon, two of the cave and two of the ridge were taken
from the perfect bot's run, with `--no-title`, through a throwaway script.
They were not saved in the repo. What they showed:

- The canyon reads as a canyon, with deep walls, stepped benches, the
  arch, and the saddle opening up under you.
- The cave's skylight reads from the roof.
- The overhang reads as you pass under it.
- The ridge's first notch is a wide square gap with a sill, more cut block
  than V.
- The joint drums show as discs on the saddle's and walls' tops.

## Unverified

- **No person has flown any of the five.** Their fun and felt difficulty
  are unknown. The bands are the bots'.
- **The cove and the stacks are only half-seen.** I took no still of
  either. Whether the cove reads as a cove is the weakest point. In plan
  it is a sinuous cliff with a headland, not a round bay.
- **Rendering cost.** The pack adds about 1,440 solids, each its own body
  and mesh, to a study that had about 760. Frame rate in the study isn't
  measured.
- **The waterfall is a solid sheet in greybox**, so it bumps. A real fall
  would be passable. The way behind it is 10 m wide either way.
- **`--pack=nature` was never driven by hand.** The headless smoke test
  covers the scene, and the bench test covers `pack_stations` and the keys.
- **Tests run:** the headless import check, and
  `run_tests.py --tests 'test_flight_*.gd'` (3/3 pass). Not the full suite.
- **The user's runs are untouched.** The 40 `_human_` run files were
  checked by md5 before and after, and are unchanged.

## Suggested next round

1. **Fly the pack and rate it** (`./run-flight-nature.command`). The A/B
   that matters is the canyon or cave (enclosed, long threading) against
   the stacks (many short openings). That says whether "through" means
   time inside or count of gaps. On round 2's nine runs, openings/s
   tracked fun at r 0.8.
2. If the cove doesn't read as a cove, close its mouth with a south
   headland and give the back wall a real bay curve. That means a longer
   left sweep: watch the past rule.
3. Try a hard but forgiving station: a slot canyon with a knife-edge crack
   as an optional shortcut, with no tokens in it, so decent still clears
   the main line.
4. The heading-knot and climb-knot format is small. A generator could emit
   it and the landform builders reuse it (canyon, field, cliff, ridge,
   cave), then filter on the bench as round 4 suggested.
5. If the frame rate suffers, merge the stacks' drums and the walls' boxes
   into one mesh per part in `FlightCourse.build`, and keep separate
   colliders.

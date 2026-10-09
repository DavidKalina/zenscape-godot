# Flight study: the lines pack (round 5)

Branch: `study/flight-lines` (from main 752c98f8). This round covers three things:
green/yellow/red token lines through the same stone, halls that bend up
and down along their length, and lines that leave a hall and come back in.
Three new greybox stations are in a new pack, `lines`. Every station from
before keeps its order, origin, key and hash.

## Launch

    ./run-flight-lines.command                      # starts on the pack; N cycles within it, L switches line
    ./run-flight-lines.command --line=red           # every station on its red line
    ./run-flight-lines.command --station=lines_stitch@yellow --bot=sharp
    ./run-flight-study.command --station=lines_crest   # the full study, starting at one of them

Bench and tools (all headless):

    godot --headless --path . -s tools/flight_bench.gd -- --pack lines --runs 20   # every line of every station
    godot --headless --path . -s tools/flight_bench.gd -- --station lines_bend@red --runs 20
    godot --headless --path . -s tools/flight_lines_check.gd                        # rooms, tight spots, knife zones, per line
    python3 tools/flight_lines_layout.py --check     # each line's needs, swing, wall crossings
    python3 tools/flight_lines_layout.py --write     # rewrite the pack from the layouts
    godot --path . --script tools/capture_flight_lines.gd -- --no-title /tmp/flight_lines   # stills (opens a window)

Tests: `python3 tools/run_tests.py --tests 'test_flight_*.gd'`. The new test
is `tests/test_flight_lines.gd`.

## Keys (new)

| Key | Does |
|---|---|
| L | next token line on this station: green → yellow → red → green |
| N | next station; with `--pack=lines` it stays within the pack, on the same line |

The pack stations have no digit key. Use N, `--station=<id>` or
`--pack=lines`.

## Token lines (how a "line being flown" works)

- A station's own `tokens` are its **green** line. An optional
  `lines` dict holds the others: `{"yellow": {"intent", "ease"?, "tokens"},
  "red": {...}}`.
- `FlightCourse.flown(s, "red")` returns the same station with that line's
  tokens, intent and `ease`. Its id is **`id@red`** and it carries `base` and
  `line`. `FlightCourse.station("lines_bend@red")` resolves it, so the run JSON, file
  name, hash, `bands.json` row, bench row, trace and backfill all treat each
  line as its own station without other changes. `origin` looks up the
  base, so the stone stands once.
- Helpers: `line_names`, `line_of`, `base_of`, `pack`, `NO_KEY` (-1, which `key_name` gives as "" and
  `station_by_key` ignores), `LINE_SEP` "@".
- **Each line has its own pickup reach (`ease`).** Green is 1.3 (2.2 m),
  yellow is the game's 1.7 m, and red is 0.75 (1.28 m). So the orbs are
  generous, normal and precise. This was a deliberate lever. Without it,
  the sloppy bot cleared only 10-20% of a 15-19 s green line with ~20
  tokens: its misses were scattered noise, not bumps. And decent cleared
  the first red at 55-80%, because a slit token can be taken while scraping
  the jamb. Say if you'd rather keep one reach. Then green needs fewer or
  gentler tokens, and red needs other tightness.
- In the study, the line being flown has full-size orbs in its colour. Where
  the other lines leave it, their orbs are small and faint (not
  collectable), so you can see the branches. Tokens shared with green are
  the very same points: the layout snaps them.

## The geometry additions (`_bay`, only used when present)

- `pitch`: the bay is tilted along the nave, so a hall can rise and dip as one
  curve. The columns stay upright on the tilted floor.
- `rows`: which outer row columns stand at the bay line. A fallen column
  widens a breach.
- `screen: "right"`: the knife-edge screen across the right of the nave
  (`true` is still the left).

Older stations don't use these keys, so their solids are unchanged.

## The layout tool (`tools/flight_lines_layout.py`)

Each line is laid out first, and the hall is built round it:

- A line is beats in the nave's frame, `across` and `up` (over the local
  floor). Between beats it follows a half cosine.
- A half cosine depends only on its two neighbouring beats. So a branch
  that replaces green's beats between two of them flies exactly green's
  line outside that stretch, and rejoins on green's tokens (the tool
  asserts this).
- The floor has its own beats (the vertical bend), and the nave its curvature
  steps.
- `openings` cut the walls wherever a line crosses them: `collapse` opens
  every bay within 9 m and drops the row columns within 7 m, while `arch`
  opens only the bay the crossing is in. `open_roof`, `spires` (outside
  pillars) and `gates` (on the roof) do the rest.
- `mirror` flips a layout left for right. `lines_bend` uses it, to turn away
  from `sundered_mix`: as first laid out, it came within ~46 m of that
  hall.

## The stations

All are at the real hall's dimensions (8 m bays, rows ±9.4, walls ±12.4).
Their solids are ≥ 126 m from any neighbour.

**`lines_bend`: Bending nave.** 27 bays. The floor climbs 11 m to a crest
and falls 16 m to a trough as one curve (slope ≤ 16°), while curving one
way and then the other in plan.
- **Green** sways up the middle. Past the crest it leaves through a wide
  collapse on the inside of the bend, swoops down outside between the wall and a spire, and comes back in
  through a second collapse as the hall falls away.
- **Yellow** leaves earlier, while the hall is still climbing, through an
  arch (5.2 m; it threads it with ~0.1-0.5 m to spare). It stays out longer,
  passes outside a first spire and round the far side of green's spire,
  and rejoins green on the way back in.
- **Red** stays in when the others leave. It goes under a low tie (0.7 m
  room), through a knife-edge slit, swings hard across the nave and back,
  and through a second slit.

**`lines_stitch`: Stitching hall.** 27 bays. The floor rolls as a wave
(±3 m, crests where the line crosses the nave), and the nave makes an S in
plan.
- **Green** stitches through both walls in one big S: out left, in, across
  the nave, out right, in, out left, home. That's three exits and three
  re-entries, each outside pass inside a spire.
- **Yellow** takes the same breaches but swings wide round the far side of
  the second and third spires.
- **Red** stays in and threads three knife-edge slits (left, right, left),
  swinging across the nave between them while the others are outside.

**`lines_crest`: Over the crest.** 21 bays. The floor arches 8 m like a
bridge, and the hall bends harder in plan at the crest.
- **Green** climbs out through the open roof as the hall rises, flies over
  the roofed crest through three big gates (7 × 5.5 m) standing on the roof
  (the climb rings, on top of a building), then dives back in through the
  open roof.
- **Yellow** stays under the roof and weaves round three inner columns over
  the hump.
- **Red** goes over with green but beside it, on its knife edge through the
  three slit gates (1.15 m) that flank the big ones.

## Bench (bot VERSION 2, 20 runs; reference = perfect bot's best)

| line | intent | band | clear sl/de/sh/pf | ref s | demand peak | room min | threading | openings/s | still | longest straight s | sideways |
|---|---|---|---|---|---|---|---|---|---|---|---|
| lines_bend | easy | **easy** | 0.7/1.0/1.0/1.0 | 16.6 | 0.30 | 1.55 | 60% | 0.48 | 20% | 0.77 | 73% |
| lines_bend@yellow | medium | **medium** | 0.0/1.0/1.0/1.0 | 16.6 | 0.50 | 0.13 | 49% | 0.30 | 33% | 1.15 | 75% |
| lines_bend@red | hard | **hard** | 0.0/0.3/1.0/1.0 | 17.0 | 0.69 | 0.00 | 67% | 0.65 | 15% | 0.87 | 73% |
| lines_stitch | easy | **easy** | 0.8/1.0/1.0/1.0 | 17.5 | 0.30 | 2.21 | 29% | 0.92 | 13% | 1.05 | 81% |
| lines_stitch@yellow | medium | **medium** | 0.1/1.0/1.0/1.0 | 19.2 | 0.55 | 1.70 | 18% | 0.52 | 21% | 1.35 | 84% |
| lines_stitch@red | hard | **hard** | 0.0/0.5/1.0/1.0 | 16.2 | 0.62 | 0.08 | 44% | 1.11 | 22% | 1.28 | 70% |
| lines_crest | easy | **easy** | 0.9/1.0/1.0/1.0 | 14.5 | 0.16 | 1.88 | 23% | 0.41 | 13% | 0.68 | 51% |
| lines_crest@yellow | medium | **medium** | 0.1/1.0/1.0/1.0 | 14.2 | 0.45 | 1.25 | 49% | 0.28 | 18% | 0.53 | 73% |
| lines_crest@red | hard | **hard** | 0.0/0.3/1.0/1.0 | 14.9 | 0.50 | 0.05 | 22% | 0.40 | 12% | 0.62 | 63% |

Every line lands in its intended band. For comparison, `sundered_flow`
(the 5/5) is still 4%, longest 0.32 s.

Knife moments: bend red has 2 slits, stitch red 3 and crest red 3. Sharp
threads them all, clean. Decent is clean on 1.0/2, 1.65/3 and 2.15/3.
(Bend yellow's arch reads as a knife zone to the bots, so they lean
through it. A person flies it level.)

Saved: the bench's runs and `bands.json` rows went into the shared
`user://flight_runs`, so the study's end panel shows each line's band. The
user's 40 `_human_` files were checked by md5 before and after: unchanged.

## Surprises

- **Sloppy can't clear a long green line on accuracy alone.** On a 17 s
  line with ~20 tokens at the game's reach, sloppy cleared 10-20% with no
  bumps. Its stick noise misses one token in ten. "Easy" on a long station
  needs generous orbs or few of them. The old easy stations were 6-9 s
  with 7-8 tokens.
- **Slit tokens aren't strict at the game's reach.** Decent scraped
  through the first red slits and still took the token (1.7 m reach). The
  smaller red orbs fixed it.
- **The perfect bot straightens wide curves.** With a 2.2 m reach it flies
  the chord of a ±1.5 m sway, and a big S across the nave becomes straight
  diagonals. The designed lines are 6-13% still (`--check`). The flown
  reference is 13-33%. What helped:
  - curving the nave itself (≥ 1/110: 7°/s even when the line is straight
    in the nave);
  - putting the floor's crests and troughs where the line crosses the nave
    (the stitch hall's wave);
  - bigger vertical bobs (yellow over the crest).
- **Shallow wall crossings need long breaches.** At ~30° a line needs
  ~11 m of wall gone. The real arch (5.2 m) only fits crossings ≳ 33°, and
  then only just (yellow's 0.1-0.5 m). A crossing steep enough for a
  roomy arch (≥ 50°) needs a turn of 2+ × TURN_RATE. So arches are a
  yellow/red thing, and collapses with a fallen column are green's.
- **The halls drift sideways.** A hall that keeps curving one way walks
  100+ m across and runs into its neighbour's 260 m slot. S-plans and
  `mirror` fixed it.

## Unverified

- **Nobody has flown these.** The bands are the bots'. Whether green
  feels forgiving, and whether leaving and coming back in feels as good as you
  hoped, is untested.
- **Rendered: a handful of stills only** (`tools/capture_flight_lines.gd`).
  - The chase camera reads well inside the bending nave, at the stitch
    hall's exit and spire, and on the crest's gates with the slit gates
    beside them.
  - The faint orbs read, but small.
  - Untested: the camera through the tilted bays' wedge chinks, and diving
    back in through the crest's roof.
  - The overview shot is too foggy to judge the whole layout.
- **The tilted bays leave wedge gaps and overlaps at joints** (pitch
  changes ~0.04 rad per bay). The bump treats them as stone.
- **The arch in bend yellow** is tighter than "medium" suggests (0.1 m on
  the smooth line). The bots lean through it. A person flying it level
  may scrape.
- **Flow is short of `sundered_flow`.** The worst lines are bend yellow
  (33% still, longest 1.15 s) and the stitch reds (the knife holds).
- Tests: import check and `run_tests.py --tests 'test_flight_*.gd'` (4/4
  pass) only, not the full suite.
- **Merging with the other packs:** each pack appends `+Pack.STATIONS` to
  the same line of `flight_course.gd`, and touches `station`/`key_name`/
  `station_by_key`/`next_station`. Expect small textual conflicts. Origins
  shift with order, but hashes don't depend on them. Re-check neighbour
  distances after the merge, since my halls wander up to ~100 m across
  their slot.

## Files

- `scripts/flight_pack_lines.gd` (new): the three stations, generated.
- `scripts/flight_course.gd`:
  - the pack hook;
  - `flown` / `line_names` / `line_of` / `base_of` / `pack` / `NO_KEY`;
  - `station("id@line")`;
  - `origin` of a line;
  - `_bay` `pitch`, `rows` and `screen: "right"`.
- `studies/flight_study.gd`: `--pack`, `--line`, L, line colours and faint
  orbs, N within a pack.
- `tools/flight_bench.gd`: `--pack`, and every line under `all` or `--pack`
  (`with_lines`). Each stone is built once.
- `tools/flight_lines_layout.py`, `tools/flight_lines_check.gd`,
  `tools/capture_flight_lines.gd` (new).
- `tests/test_flight_lines.gd` (new): the 9 line hashes are pinned. Also
  covers branches rejoining, reaches, sharp clearing the bending nave's
  lines, and the study's N/L.
- `run-flight-lines.command` (new).

## Suggested next round

1. **Fly the pack and rate each line.** Start on green: is leaving and
   re-entering through the wide collapses the fun you meant? Then say which
   red is the good kind of hard: the knife slits inside, or the slit gates
   on the roof.
2. **Decide on per-line orb size.** If you like big green and small red
   orbs, keep them. Otherwise drop `ease` and retune the token spacing.
3. **Fix flow** where it's weakest (bend yellow's long outside arc, the
   stitch reds' holds), using the levers above.
4. **Generate variants** from the layout tool (nave curve, floor beats,
   opening kinds, spire placement). Filter on bands per line and still
   ≤ 15%.
5. **Make the lines choices, not separate runs.** Today each colour is its
   own run. Real play would have all three standing at once, with the run
   scoring whichever orbs you take. That needs optional tokens (round 4's
   suggestion) in `flight_run.gd`.

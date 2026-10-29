# Spec: the wilderness loop (`wild-loop`)

Loop slug `wild-loop`, trail prefix `ITER(wild-loop):`, branch
`claude/wilderness-gameplay-combos-a07806`. Model: Opus for every agent.
Cap and budget: the iterate skill's defaults. A prototype round
(AGENTS.md, Prototyping): smoke checks and throwaway checks in `scratch/`,
no committed tests, no full suite. Each handoff lists the existing tests
its change breaks.

## What done looks like (what the user plays)

`.\run-endless-flight.cmd` in the wilderness (the default world):

1. **The line reads moves.** Flying a mixed line (carving the meadow,
   weaving trees, a canyon, up a mountain face and down it, round a sea
   stack, a late pull from a dive, knife edge through a split) earns named
   moves on the near-miss tag. Its multiplier climbs with **how hard** each
   move was (how close, how fast, how tight the opening, knife edge or
   inverted), not with how many moves there were. A move repeated in one
   line is worth less each time, and a new kind is worth the most. When the
   line banks, the tag reads it back for a moment: the moves in order, the
   kinds of land crossed (meadow → forest → canyon → peak → sea) and, for a
   rich line, a short name. The banked line pays money.
2. **Landing ends a flight.** Coming to rest shows a summary card: time
   and distance aloft, the best line (its read-back), money earned, trees,
   clouds and the rest of that flight's tallies, any challenge's result,
   and any new records. It goes when you take off.
3. **The logbook** (J): every tally, record and find, lifetime, plus
   money. It holds the keys while open, and J or Esc closes it.
4. **Beat routes.** Starters stand in the land, visible from far off.
   Flying through one runs a short preview pan of the route (start, the
   beats in rough order, the finish), which you can skip. Then one beat at
   a time: a single bright collectible that flashes faster as its time runs
   out and goes if you are late. The finish stands as a beacon on the
   horizon. Any way there counts. The time is set so the safe, wide way
   just makes it and a bold shortcut gains time. The last beat is a landing
   on a strip by the finish. A miss ends the route gently, with what you
   got. It pays money, shows in the summary and counts in the logbook.
5. **A shop.** A place in the land with a landing strip beside it, seen
   from far off; the first is near the start. Stopping on its strip opens
   an overlay: buy and wear paints for the plane (and one other kind of
   item that leaves the flight alone), with the money earned. What you wear
   is kept between runs.
6. **Photo mode** (O; the pad's `photo`, L3): the flight held, a free
   camera, the HUD hidden; a key saves a still to `user://photos/`. The
   logbook counts photos.

Out of scope this round: new sound (its own round after; leave the existing
sound working), the Amberlands' named openings and routes, ghosts, shared
routes, daily seeds. Keep the Amberlands (`--world=amberlands`) and the
rival race working.

## Foundation (done, in the spec commit)

- `scripts/endless/pilot_book.gd` (`PilotBook`): money, tallies, records,
  finds, owned and worn items, kept as JSON at `user://pilot.json`. Its
  `flight` dict is this flight's own. Read its header for the API: `count`,
  `best`, `find`, `earn`, `spend`, `own`, `wear`, `worn_in`, `line_banked`,
  `challenge_done`, `new_flight`.
- `studies/endless_flight.gd`: `book` (opened in `_ready`, a new flight on
  `lifted`, `flight.t` stepped in `tick`, saved in `_exit_tree`) and
  `overlay` (an overlay that holds the keys; `_unhandled_input` returns
  while it is set; open one only when it is null).
- **Every driver, smoke and capture passes `--pilot=fresh`** (or
  `--pilot-file=` under scratch/), so no check writes the user's real book.

## Lanes (run at once, one agent each, its own worktree)

Each lane keeps its code in its own new files. Its edits to shared files
(`studies/endless_flight.gd`, `scripts/endless/near_miss*.gd` for the line
lane only) are small and additive: a construction line, a call in `tick`,
a key in the match. Commits are `ITER(wild-loop): lane <part>: <task>`.
Each lane's last commit ends with **Notes for merge**: the shared lines it
touched. Stage by explicit path only. The headless import rewrites `.import`
files' line endings: never commit them.

Keys taken in the main scene: F, F1, F2, R, V, P, T, L, [, ], C, G, H, K,
Q, E, Esc, Tab (the rival), WASD, the arrows, Space, Shift, Ctrl, Alt.
This round adds **J** (logbook) and **O** (photo). No other new keys
without checking the match in `_unhandled_input`.

### lane `line`: moves, difficulty and the read-back

Files: `scripts/endless/near_miss.gd` (the chain), new
`scripts/endless/line_moves.gd` (move recognition), the default tag
`scripts/endless/near_miss_hud_handoff.gd` (keep the `--near-hud=glyph`
trial working), `near_glyphs.gd` for new glyphs.

- **Moves**: the current moments (pull-out, graze, thread) stay as moves.
  Add at least these: carve (a hard bank low over open land, held), slalom
  (tree passes alternating sides in a few seconds), canopy run (a held skim
  over treetops), canyon run (walls close on both sides, held), climb (up a
  steep face hugging it), surf (down a steep slope hugging it), stack orbit
  (round a sea stack close, most of a turn), late pull (a long steep dive
  ended in a razor pull-out; dive height counts), knife edge (any thread or
  graze with the wings past ~60° of roll), inverted (any move flown upside
  down). The land, the plane and NearMiss's rays are the inputs. Find the
  queries the land has for grass, trees, sea, slope and splits.
- **Difficulty is the multiplier**: each move adds its own difficulty to
  the multiplier (how close, its band, speed over cruise, the opening's
  width over the span where both sides are measured, attitude, dive
  closing). Base points per move are "what". A move's repeats in one line
  add less each time, and a new kind adds the most. Cap the multiplier
  well above today's 5 so a wild line can reach it and an easy one can't.
  Keep the farming cut. Keep `multiplier()`, `chain_points` and the rest
  the rival race reads meaningful (`rival_race.gd`).
- **Terrain**: each moment notes the kind of land under it (meadow, forest,
  canyon, mountain, sea, river, lake, ruin), so a line knows the land it
  crossed.
- **Bank**: a banked line calls `game.book.line_banked(line)` with
  `{points, mult, moves, terrain, t}` (the book pays it) and
  `book.best("tightest_gap", m)` for threads. Put the line in the frame's
  events as `"line"` for the HUD. The read-back holds a second or two on
  the tag: move glyphs in order, the terrain sequence, money paid, and a
  name for a rich line from a few tiers (placeholder words; the user names
  them later). The tag stays small and beside the plane.
- Proof: a driver through the real play loop that flies (via input) a
  mixed line and a repeated one, and prints both banked lines: the mixed
  one must out-multiply the repeat. Rendered stills of the tag mid-line and
  at the read-back.

### lane `logbook`: tallies, the logbook and the landing summary

Files: new `scripts/endless/pilot_tallies.gd` (the counting hooks), new
`scripts/endless/logbook_view.gd` (J), new
`scripts/endless/landing_summary.gd` (the card).

- Tallies (`book.count`): metres flown, seconds aloft, landings (on the
  `stopped` edge; ManualLanding's `stopped` repeats every frame, so use
  `stats.stopped` or an edge), crashes, scrapes, trees knocked (tree_knock's
  `knock` event), grass cut (metres flown low over grass, from what feeds
  `grass_react.gd`, shown as an estimate of blades), clouds flown through
  (entering `clouds.in_cloud(plane.position)`, `endless_clouds.gd:913`),
  flocks flushed (`endless_birds.gd`'s flush), water skims. Records: top
  speed, the highest flown, the longest flight.
- The landing summary: shown on coming to rest, read from `book.flight`
  (the line lane's lines and best_line, the beats lane's challenges, the
  records set, the finds). It doesn't take keys, it hides while an overlay
  is up, and it goes on lift-off. Until the line lane lands,
  `flight.lines` is empty: show that cleanly.
- The logbook overlay: sets `game.overlay` while open. It lists money,
  tallies, records and finds (gaps, starters, shops by count), in the
  game's own look (the gilt numbers, the near-miss tag's type).
- Proof: a driver that flies, knocks a tree or skims grass, lands, comes
  to rest and prints the summary's lines, then opens and closes the
  logbook. Stills of both.

### lane `beats`: beat routes

Files: new `scripts/endless/beat_routes.gd` (starters, the route, the
run), new `scripts/endless/beat_marks.gd` (the beat, the beacon, the
starter), new `scripts/endless/beat_pan.gd` (the preview pan).

- Starters: one per grid cell by the seed (deterministic, like
  `split_sites.gd`), standing over open land, visible from ~800 m, flown
  through to start. None while the rival race runs, and no rival offer
  while a route runs (`rival_race.gd`'s state). `book.find("starter/<id>")`.
- The route: 4 to 7 beats over the land's features (crests, sea stacks,
  splits, a canyon or river, a meadow), ending at a landing strip
  (`rival_strip.gd` `find`, or the flats the sites use). Reuse
  `rival_course.gd` / `rival_line.gd` candidates where they fit. Each
  beat's time comes from a safe, wide line between them at cruise with
  slack, so a hand-flown wobbly line makes it and a shortcut gains. The
  last beat is to stop on the strip.
- The pan: the chase camera handed over for 4 to 6 s along the route
  (`studies/endless_flight.gd` `_frame` / `chase`; the menu orbit in
  `menu_stage.gd` is a model), skipped by any fly input or Tab, with the
  flight held meanwhile. Then the camera comes back smoothly.
- The run: one beat shown, flashing faster as its time runs out; the
  finish beacon always shown; a late beat fades and the route ends gently.
  Spare time adds to the score by default (`--beat-spare=carry` carries it
  to the next beat instead). `book.challenge_done({id, kind:"beats", got,
  of, time, points, money, done})`.
- Proof: a driver that flies a route through the real input path on a
  wobbled safe line and finishes it with time to spare at every beat
  (print each beat's margin), and one that misses a beat and ends cleanly.
  Over a few seeds, starters must stand where a route can be built. Stills
  of a starter far off, a beat, the beacon and a frame of the pan.

### lane `shop`: the shop

Files: new `scripts/endless/shop_sites.gd` (placement), new
`scripts/endless/shop_view.gd` (the overlay), new
`scripts/endless/shop_stock.gd` (the items).

- Placement: one per large cell by the seed, the first within ~1.5 km of
  the start, beside a flat landing strip (never on it; the meadows rule),
  named for layout overrides as `shop/<cx>_<cz>`
  (`scripts/layout_overrides.gd`). It reads from far off: a mast, a
  windsock and a small hangar or stall, built simply. A new model assesses
  `docs/art/model-budget.md` in its handoff. It works in any world, but
  prove it in the wilderness.
- The overlay: stopping on its strip opens it (`game.overlay` set). Items,
  prices, owned and worn state, money. Buy with `book.spend` +
  `book.own`, wear with `book.wear`. Esc or taking off leaves. Paints:
  5 or 6 liveries via `PlaneFigure.paints(livery)` (`plane_figure.gd:545`;
  the traffic liveries in `sky_traffic.gd:89` show the shape), applied at
  launch from `book.worn_in("paint")`. One more kind of item of the lane's
  choice that leaves the flight alone. Prices are placeholders; the trunk
  tunes them.
- Proof: a driver that flies to the first shop, lands and stops on its
  strip, sees the overlay open, buys and wears a paint with seeded money
  (`--pilot-file=` with money in it), relaunches and sees the paint kept.
  Stills of the shop from 600 m, on its strip, and the overlay.

### lane `photo`: photo mode

Files: new `scripts/endless/photo_mode.gd`.

- O (and the pad's `photo`) enters it: the flight held (no plane step, the
  world's time held too where it can be), `game.overlay` set, the HUD
  hidden, and a free camera orbiting and flying from the plane with the
  usual look keys and stick, with FOV. One key saves a PNG to
  `user://photos/` (named by date). O or Esc leaves, and the flight carries
  on exactly where it was. `book.count("photos")`.
- Proof: a driver that enters, moves the camera, saves, leaves, and checks
  that the plane's state is unchanged across it. A still saved by it.

## Trunk (after the lanes are merged, in order)

1. **Money and balance**: money per point, challenge pay and shop prices,
   so a first paint takes about ten minutes of decent flying and a wild line
   pays clearly more than a safe one. The summary, the logbook and the shop
   agree on the money.
2. **The whole loop**: one driver through the real play loop that flies a
   line and banks it, finds the first shop, lands, buys, takes off, runs a
   beat route, lands at its finish and reads the summary. Fix what breaks
   between the lanes. Smoke `studies/endless_flight.tscn` (wilderness and
   `-- --world=amberlands`) with `--pilot=fresh`. Stills of each step.
3. Done: `<promise>COMPLETE</promise>`.

### Found at the merge (trunk 1 and 2 fix these as they go)

- **Money is far too generous**: one mixed line paid 221, and the dearest
  paint is 180. Re-tune `PilotBook.MONEY_PER_POINT`, the beat pay and the
  prices together (trunk 1).
- **The read-back is hard to read** over busy land (trees, grass): the
  land-crossed row and the name are small and pale (`line_read_a.png` in
  the line lane). Give it a backing or weight, and keep it small.
- **"longest flight" record** showed 0:02 for a 1:38 flight
  (`pilot_tallies.gd`).
- **The shop opens during a beat route**: it must not, just as it doesn't
  during a race. A route's landing on a shop strip goes to the route.
- **The hint line** (the bottom key list) lacks J logbook and O photo.
- **Beats**: seed 5's route had a beat missed by the safe driver (look at
  why: the time, or the line). The beats are small dots in the pan, the
  starter is only a thin shaft from 800 m, and the strip's posts don't read
  from 420 m.
- **Triangulation errors**: `near_miss_hud_handoff.gd` `_bar` still threw
  "Invalid polygon data" in the beats lane's runs. Check after the merge,
  as the line lane fixed some of them.
- **Amberlands smoke**: one run in about six leaks a JoltBody3D RID at exit.
  Find whether it is new (try it at `cdc6961c`) and fix it if it is ours.
- **The rival** is slowed less now (full flow at x12, not x5). Check that a
  race still feels like a race, and re-map if not.

### After trunk 1 (2026-10-28)

- Done: the money (lines pay points/1600 x sqrt(mult), at least 1; beats 2
  a beat, 6 the finish, 1 per 15 s spare; prices kept), the read-back's
  plate, "longest flight" (it read a faked tally; now one source), the shop
  shut during a route, J and O on the hint line, the beats' look (pan
  glows, the starter's crown, lit strip ends), the rival's flow (full at
  x5 again).
- Seed 5's miss was the driver's: it flew into a crest at 9 m and kept
  steering by the crashed SkyPlane (a crash launches a new one); re-read,
  it took beats 1-5 (7.7-19.5 s spare), then touched down 56 m short of the
  strip with 25 s left. No route change.
- Triangulation errors: none in any run of trunk 1.
- Amberlands smoke: 8 of 8 PASS at `cdc6961c` and 8 of 8 at the trunk, run
  alone; one FAIL ("Initializing already initialized RID", "unimplemented
  base type ... scene cull") came with two smokes at once. Not traced.
- Left for trunk 2: **the beat planner's frame cost**. While squares are
  planned (the first ~10-20 s, and as new ones come in reach) headless
  frames in the Amberlands go from ~4 ms to ~25 ms (spikes 40-60 ms; the
  wilderness ~14 ms in the first 5 s). A 1 ms slice changes nothing and no
  stretch between the planner's own checks passes 12 ms, so the cost is
  outside its slices: suspect work its far sampling sets off (the field's
  caches). The smoke's 400 frames: 4.5 s at `cdc6961c`, 16-19 s now.
  Probes: scratch/frame_cost.gd, scratch/step_cost.gd (not committed).

## Smoke checks

`python tools/smoke.py studies/endless_flight.tscn -- --pilot=fresh` and
`python tools/smoke.py studies/endless_flight.tscn -- --pilot=fresh --world=amberlands`.

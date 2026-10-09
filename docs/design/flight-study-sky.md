# Flight study: the sky pack (round 5, sky-native set pieces)

Branch: `study/flight-sky` (from main 752c98f8). Four greybox stations built
from floating masses (islets, a spire, rope spans, a pierced isle) with open
sky and the floor 40 m below, not ground terrain. Every one was laid out line
first, the way `sundered_flow` was: design a flowing line, stand the masses
round it, then put the tokens along it. Greybox only. Nothing in the game is
touched.

## Launch

    ./run-flight-sky.command                          # starts at sky_weave; N cycles the four
    ./run-flight-sky.command --station=sky_pierced    # straight into one
    ./run-flight-sky.command --bot=sharp              # watch a bot
    godot --path . res://studies/flight_study.tscn -- --no-title --pack=sky [--station=sky_spire]

The pack's stations have no digit key (the digits are all taken). Reach them
with N, `--station=<id>`, or `--pack=sky`, which starts at the pack's first
station and keeps N cycling inside the pack. Without `--pack`, N runs through
every station and the sky ones come after `sundered_mix`.

Bench, layout, tests and stills:

    godot --headless --path . -s tools/flight_bench.gd -- --pack sky --runs 20
    python3 tools/flight_sky_layout.py --check [--station sky_spire --gaps]   # the line's numbers, no Godot
    python3 tools/flight_sky_layout.py --write                                # rewrite the pack's STATIONS block
    python3 tools/run_tests.py --tests 'test_flight_*.gd'
    Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_flight_sky.gd -- --no-title [--only=sky_spire]

## The stations

All four stand after `sundered_mix` (indices 11-14, x 2860-3640). Every
existing station keeps its order, origin, key and hash.

| id | band | what you fly |
|---|---|---|
| `sky_weave` | easy | **Islet weave.** A lazy corkscrew (±5 m across, ±2 m up, 38 m half beats) curling gently left through 12 islets. At each swing out it rounds an islet on the inside of the bend: at its flank, or under its rim (`under`). Where it crosses back, it ducks under a hanging keel at the bottom of the bob, or threads the gap between a pair's edges at the top (an `air` gap, 6-7 m rim to rim). It ends under a big isle's keel. 21 tokens, 15 s, reach eased ×1.25. |
| `sky_spire` | easy | **Spire spiral.** A 68 m floating spire. The line climbs 30 m round it over 1¼ turns, and the radius breathes 20-28 m. At each pinch it passes under a ledge jutting from the spire (`under`). At each bulge it passes under a rope span from the spire to an outrider islet. Between them it passes through a gate of two floating rock stacks. This is the game's spire `air` arc stretched into a whole climb. 23 tokens, 15 s, reach ×1.25, `miss_near` 16. |
| `sky_spans` | medium | **Chain of spans.** Six islands on alternate sides down a long right-hand curve, each tied to the next by a sagging rope bridge that crosses the way. The line weaves round each island's flank (leaving the chain) and back in under the next bridge (an `air` line under a bridge), five times. The island tops are raised so every deck clears the line by at least 3.6 m, so the line rises and falls with them. The third island hangs low, and the line ducks under its rim. 20 tokens, 14 s. |
| `sky_pierced` | medium | **Pierced isle.** The line dips under a small islet's keel, then rises into a tunnel mouth under the big isle's overhanging top. The tunnel is a 9 × 7 m bore on a long level S-bend, left then right, about 55 m. The line comes out, swings wide round a falling right-hand loop (under an outrider's rim, between two stacks), and comes back in under the big isle's hanging keel, heading west. Then it threads the "veil" between two islands' edges (6.4 m apart) and climbs away. You leave the structure and come back in. 29 tokens, 20 s, `miss_near` 10. |

## Bench (VERSION 2 bots, 20 runs; reference = perfect bot's best)

| station | band | clear sl/de/sh/pf | ref time s | demand peak | mean | room min m | threading | openings/s | **still** | **longest s** | straights | sideways | swing rev/s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| sundered_flow (round 3, the 5/5) | medium | 0.0/0.9/1.0/1.0 | 13.37 | 0.67 | 0.42 | 0.59 | 37% | 0.45 | 4% | 0.32 | 0 | 65% | 0.75 |
| sky_weave | **easy** | 0.7/1.0/1.0/1.0 | 14.72 | 0.23 | 0.16 | 1.53 | 51% | 0.34 | 6% | 0.52 | 1 | 73% | 0.34 |
| sky_spire | **easy** | 0.6/1.0/1.0/1.0 | 15.28 | 0.31 | 0.23 | 1.57 | 29% | 0.52 | 5% | 0.57 | 1 | 96% | 0.00 |
| sky_spans | **medium** | 0.1/1.0/1.0/1.0 | 13.97 | 0.31 | 0.25 | 1.63 | 18% | 0.36 | 5% | 0.33 | 0 | 74% | 0.57 |
| sky_pierced | **medium** | 0.0/1.0/1.0/1.0 | 19.98 | 0.37 | 0.21 | 1.58 | 42% | 0.35 | 9% | 0.77 | 1 | 83% | 0.25 |

- **Decent clears every station every time, and sharp clears every one
  without a bump** (`test_flight_sky.gd`). Each one's least room is over
  1.5 m past the wingtips, about three times `sundered_flow`'s. "Fast
  without bumping" is forgiving by layout, not by the bot.
- Two easy and two medium, no hard. Sloppy is the only bot that varies. It
  clears weave and spire 60-70% of the time (both sit near the 60% line, so
  they may flip at other seeds). It almost never clears spans or pierced.
  Its misses are scattered noise misses on long trails, not bumps.
- **Flow is close to `sundered_flow`'s** (still 5-9% against 4%, longest
  straight 0.33-0.77 s against 0.32 s). Demand is about half, because the
  vertical moves are long and gentle (pitch need ≤ 0.28 on every line) and
  the sideways share is 73-96%.
- Threading share is as high or higher (weave 51%, pierced 42%), but
  openings/s is a bit lower (0.34-0.52 against 0.45). Only `sky_spire`
  (0.52) beats it.

## Files

- `scripts/flight_pack_sky.gd` (new): the pack. It holds `PACK`, `NO_KEY`, the
  generated `STATIONS` block and the part kinds' geometry (`solids_of`):
  - `rock`: a floating upright drum.
  - `isle`: a flat top with a stepped hanging keel, drums at 0.66, 0.46,
    0.30 and 0.16 of the radius. That's the inverted cone in greybox.
  - `span`: a sagging rope-bridge deck in 6 planks, with rails.
  - `bore`: a tunnel stretch (floor, roof and walls round an opening). A
    curving tunnel is a chain of them.
  - `slab`: a box turned by yaw and pitch.
- `scripts/flight_course.gd`: it preloads the pack as `SkyPack`, and
  `STATIONS` is the course's own list plus `SkyPack.STATIONS`. `solids`
  hands any unknown part kind to `SkyPack.solids_of`. `key_name` returns ""
  and `station_by_key` returns {} for `NO_KEY` (-1). `pack(name)` lists a
  pack's stations. `station_hash` includes `miss_near` only when a station
  has it, so every old hash is unchanged.
- `scripts/flight_run.gd`: **opt-in** `miss_near`. On a station that has it,
  the "3 m past it" miss also needs the plane within that many metres of the
  token. Stations without it behave exactly as before.
- `studies/flight_study.gd`: `--pack=`, N cycling within the pack, and a
  key-less label.
- `tools/flight_bench.gd`: `--pack sky`.
- `tools/flight_sky_layout.py` (new): the layout tool. It builds the line
  (a natural cubic spline through control points, or the `weave_ctrl`
  corkscrew, or a breathing helix) and places masses against it:
  `under_rim`, `beside`, `under_keel`, `span_over`, `stacks` and
  `bore_along`. Its checker rebuilds the study's own line through the
  tokens and reports room, needs, still/longest, threading and early misses.
- `tools/capture_flight_sky.gd` (new): rendered stills, a wide shot plus
  chase frames from the perfect bot.
- `tests/test_flight_sky.gd` (new): the pack's order and keys, the four
  hashes pinned, no first-tick misses, sharp clears each with 0 bumps, and
  the perfect line has still ≤ 15%, longest ≤ 1.2 s, threading ≥ 15% and
  openings ≥ 0.25/s.
- `run-flight-sky.command` (new).

Pinned hashes: sky_weave `96e136265314`, sky_spire `848860adf76c`,
sky_spans `05b9767b3537`, sky_pierced `14e3dda676fe`.

## Surprises

- **Sloppy fails long, easy trails on noise alone.** On the first weave
  (29 tokens, turn need ≤ 0.26) sloppy cleared 0%. Its misses are random,
  about one token in thirty, so the clear rate falls with token count. To
  make easy reachable, I used fewer tokens (10 m apart), a softer opening,
  and `ease` 1.25 on the two easy stations. A long station's band is partly
  a measure of its length.
- **The onset matters more than the peak.** On the spire, sloppy missed
  token 2 most runs: the turn need jumped from 0.18 to 0.54 within one
  token. Moving the spiral's centre so the need ramps up over three tokens
  (0.12, 0.25, 0.40, 0.49) took sloppy from 0.2 to 0.6. The weave got the
  same fix (`bend`, a turn already under way at the entry).
- **A breathing spiral turns hardest at its bulges, not its pinches.** With
  r = 24 + 4 cos 2a, the pinch is almost straight and the bulge is the
  tight part. That's why the spans sit at the bulges: the tight part is
  where you pass under something.
- **Spirals and loops need `miss_near`.** Without it, the spiral's late
  tokens and the pierced isle's under-keel tokens are "past" from the
  start (the round-4 surprise). It's opt-in, so no other station changes.
- **Keel profile.** With a gentler cone (0.72 of the radius at the top drum),
  an under-rim pass clipped the keel. Steepening the cone (0.66, 0.46, 0.30,
  0.16) gives a usable overhang of about 0.5 R − 2 m.

## Unverified

- **Nobody has flown these by hand**, so there are no ratings yet.
- **Rendered: three stills looked at** (weave wide, under its first rim;
  spire wide; the pierced mouth). They read as floating islands, a spire
  with ledges, spans and stacks, and a tunnel through rock. I haven't looked
  at the spans station, the veil, the under-keel pass, or the camera inside
  the bend of the bore. The pierced isle's mouth face is a flat box wall, so
  it reads as a block more than an island face. The floor is the study's
  grid floor, not a cloud sea.
- The "veil" is only a gap: there is no water or falling sheet.
- `bridge`/`foot` tokens weren't used. The plane can't take walker lines,
  so the categories here are `under` and `air` (gap, under-bridge, spire
  arc).
- I ran the import check, the bench and `run_tests.py --tests
  'test_flight_*.gd'` (4/4 pass), not the full suite. The bench was saved to
  `user://flight_runs` (bands.json too). The user's 40 `_human_` files were
  checked by md5 before and after, and are unchanged.

## Suggested next round

1. Fly the four, rate them, and set them next to `sundered_flow` (0). The
   key questions: does the spire's single long climb feel like
   "continuous", or monotone? Does leaving and coming back on
   `sky_pierced` land?
2. If they feel tame, raise the stakes in the layout, not the bot. Tighter
   gaps (the pairs at 4.5 m, the veil at 5 m), a knife-edge crevice between
   two island edges (the round-4 slit, sky-built), or the spire's radius
   breathing 18-30 m.
3. Openings/s is below `sundered_flow`'s on three stations. Adding a stack
   gate or a span between every pair of features is cheap with the layout
   tool (`stacks`, `span_over`).
4. Island looks: give the pierced isle a rounded mass round the bore (drums
   that skip the tunnel), and draw the veil as a non-colliding sheet.
5. Combine the pack with a generator. `weave_ctrl` and the helix are
   already parametric, so emitting variants and filtering them on the bench
   (still ≤ 8%, longest ≤ 0.6 s, openings ≥ 0.4/s, decent 100%) is a short
   step.

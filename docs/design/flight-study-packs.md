# Flight study: the station packs together

Branch: `integrate/flight-packs` (main 752c98f8 + `study/flight-lines`,
`study/flight-nature`, `study/flight-sky`, `study/flight-tokens`). The
merge brings the four packs into one build. Every pack works through the
same plumbing, and no station's parts or tokens changed. The 11
hand-placed stations keep their order, keys and hashes, and every pack
station keeps its pinned hash.

## Launch

    ./run-flight-packs.command                  # starts on lines_bend; N runs through every station
    ./run-flight-packs.command --pack=sky       # one pack only; N cycles inside it
    ./run-flight-lines.command                  # the same as --pack=lines (L switches line)
    ./run-flight-nature.command                 # --pack=nature
    ./run-flight-sky.command                    # --pack=sky
    ./run-flight-tokens.command                 # --pack=tokens
    ./run-flight-study.command                  # the 11 hand-placed stations first, then the packs on N

Any launcher takes the study's args, for example
`./run-flight-packs.command --station=lines_stitch@yellow --bot=sharp`.

Bench, headless:

    godot --headless --path . -s tools/flight_bench.gd -- --pack lines --runs 20    # every line of every lines station
    godot --headless --path . -s tools/flight_bench.gd -- --pack nature --runs 20
    godot --headless --path . -s tools/flight_bench.gd -- --pack sky --runs 20
    godot --headless --path . -s tools/flight_bench.gd -- --pack tokens --runs 20 [--no-bonus]
    godot --headless --path . -s tools/flight_bench.gd -- --station lines_bend@red,sky_spire --runs 20

Tests: `python3 tools/run_tests.py --tests 'test_flight_*.gd'`.

## Keys and args

| Key | Does |
|---|---|
| 1-9, 0, - | the 11 hand-placed stations (pack stations have no key) |
| N | next station: within the pack with `--pack`, else through every station. A lines station stays on the same line |
| L | next token line on a lines station: green, yellow, red |
| R | restart · B who flies · F1 live numbers · Esc frees the mouse |

| Arg | Study | Bench | Does |
|---|---|---|---|
| `--pack=lines\|nature\|sky\|tokens` | yes | `--pack name` | start on the pack's first station; N stays in it. The bench flies the whole pack, every line included |
| `--station=<id>` | yes | `--station id[,id]` | that station; `lines_*@yellow` / `@red` flies one line. A station outside `--pack` makes N cycle through every station |
| `--line=yellow\|red` | yes | | the starting station on that line (lines pack) |
| `--bot=sloppy\|decent\|sharp\|perfect` | yes | `--skills` | who flies |
| `--no-bonus` | | yes | bots ignore the tokens pack's bonus tokens (main-line bands) |

## How the packs plug in (scripts/flight_course.gd)

- `STATIONS` is the 11 hand-placed stations, then `PackLines`, `PackNature`,
  `PackSky` and `PackTokens` STATIONS, in that order. A pack station has
  `key` `NO_KEY` (-1) and a `pack` name. `key_name` gives "" and
  `station_by_key` never returns it. `pack(name)` lists a pack's stations
  in order, or every station for "".
- Origins: a station with its own `origin` stands there (the tokens pack:
  a row at z +1300, x 0-2080). Every other station stands at its index ×
  SPACING (260 m) along x, so lines are at 2860-3380, nature at 3640-4680
  and sky at 4940-5720. A line flown (`id@line`) stands where its station
  does. Hashes are local, so moving a station doesn't change its hash. The
  closest solids of neighbouring stations are 108 m apart (lines_stitch to
  lines_crest).
- Part kinds: `wall`, `stack` and `arch` go to `PackNature.part_solids`.
  `rock`, `isle`, `span`, `bore` and `slab` go to `PackSky.solids_of`.
- `station_hash` adds `ease`, `miss_near`, `guides` and `bonus` only when a
  station has them, so older hashes don't move.
- Each pack's opt-in mechanisms stay its own:
  - lines: `lines` per station and `flown` (per-line tokens, intent and `ease`)
  - sky: `miss_near` in scripts/flight_run.gd
  - tokens: `guides` (not drawn or counted) and `bonus` (blue, optional,
    never missed), plus the bench's `--no-bonus`
- `ease` is the only reach scaling. `reach` is REACH × `ease`. Every pack
  sets `ease` on the station, or per line on the lines pack.

## Each pack's handoff

- lines (3 stations × green/yellow/red): docs/design/flight-study-lines.md
- nature (5 landform stations): docs/design/flight-study-nature.md
- sky (4 floating-island stations): docs/design/flight-study-sky.md
- tokens (9 token-placement stations): docs/design/flight-study-tokens.md

Those docs describe each branch alone. Where they name a pack's preload
(`SkyPack`, `TokensPack`, `Nature`), the merged course calls it `PackSky`,
`PackTokens` or `PackNature`.

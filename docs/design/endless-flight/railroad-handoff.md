# The railroad: handoff (loop `railroad`, 2026-11-05/06)

Spec: `spec-railroad.md`. Trail: `git log --grep='^ITER(railroad)'` on
`iter/railroad` (two lanes, `lane/rail-line` and `lane/rail-train`, merged,
then the trunk).

## What's built (greybox)

- **The line.** An 18.47 km double-track loop round the Peak on seed 1, laid
  from the route drafted with the user: start station, north-east shore, farm
  plain, the west tunnel (1160 m, up to 259 m of rock over it), the mine
  trestle (51 m high), mine town, cattle plain, the bay bridge (1.6 km with
  its approach trestles, deck 40 m over the sea). Grade 3.5% at most, curves
  160 m or wider. Tracks 13 m apart: the gap between two trains' sides is
  `WorldScale.opening(3.5)` (7 m), owned by `rail_line.gd`.
- **In the land.** The bed is cut and banked over both the native and the
  GDScript field (no kernel rebuild). Trees and grass are kept off it, and 19
  creeks run under bridges. Four tunnels have double-track bores with lamps
  and stone portals. 24 spans: timber bents to thread over land, stone piers
  over water. Everything collides and scores near misses like arches and
  bores. You can land on decks, platforms and station yards.
- **The stops.** Platforms, a station house and a water tower to fly under at
  each of the four stops. A block town with a main street and alleys, in
  painted timber. Landmarks: freight shed (start), grain elevator (farm),
  headframe (mine), pens (cattle). The mine town sits on the bench above its
  station, since the valley under the trestle is a sea inlet.
- **The trains.** Two 12-car box trains (262 m) run opposite ways at 32 m/s,
  a bit under cruise:
  - The cars: engine, tender, boxcars and flats alternating, the doors car
    (a 10 x 6 m doorway to slide through), an open wagon, the smash car (a
    surge roll breaks a plate, you fly the corridor, the far plate breaks on
    the way out, both reseal 150 m off) and the van.
  - Moving solids hold at speed (`keep_out`), and near misses score by speed
    relative to the car.
  - Each train runs on a timetable read from a steady clock, so it holds no
    state and is the same on every machine. Its look is built within 4 km,
    its colliders within 600 m.
- **The meetings.** Stops of 30 s at start and farm and 90 s at mine and
  cattle make the two trains pass mid west tunnel and mid bay bridge every
  lap (1038 s). The split is solved at whatever `--train-speed=` is set.

## Play it

From `/Users/davidkalina/Documents/Projects/zenscape-railroad`
(or main once merged):

- Fresh start: `python3 tools/play.py --no-pull -- --pilot-file=/tmp/rail.json`.
  The trains meet on the bay bridge 35 s after takeoff, about 1 km off to your
  left. Turn left early to see it.
- Quick starts, each in the gap 30 m behind train 0's van:
  `python3 tools/play.py --no-pull -- --no-title --pilot-file=/tmp/rail.json --rail-start=<name>`
  - `beside`: the farm plain at full speed; about 50 s up the train to the
    engine.
  - `tunnel`: 16 s before the head-on meeting in the west tunnel.
  - `bridge`: the meeting on the bay deck.
- The test oval on the sea (the lane's sandbox): `-- --no-title --train-test`,
  with `--full-meter` for the smash car.
- Places without trains: the farm street
  `--no-title --at=-2481,-3240 --heading=0 --alt=8`; the mine trestle
  `--no-title --at=-4669,105 --alt=30`; the west tunnel
  `--no-title --at=-4676,-1479 --heading=-177.5 --alt=8`.

## Flags

| Flag | What it does |
|---|---|
| `--no-railroad` | none of it; seed 1's land hash is main's exactly (`9ceaddb3…fcb3c4e8`) |
| `--trains=0\|1\|2` | how many trains (default 2) |
| `--train-speed=M` | train speed in m/s (default 32); the meetings re-solve |
| `--track-gap-toy=T` | toy width of the gap between trains (default 3.5, i.e. 7 m) |
| `--rail-clock=S` | the train clock at the start |
| `--rail-start=beside\|tunnel\|bridge` | the quick starts |
| `--train-test` | the test oval on the sea |
| `--train-keep=0` | keep-out off, to compare |

## What it costs (headless CPU only)

A driven A/B low along the line through the tunnel meeting, the trestle and
the mine stop, each side run more than once:
- **Median frame:** up about 1.3 ms near the line with both trains near (on
  4.5–5.6 ms against off 3.4–3.8). The split: trains 0.25–0.44, near-miss
  scoring 0.15–0.47, camera sight checks about 0.4, rails 0.09, landing 0.07.
- **Spikes:** the 99th-percentile frame is 12–19 ms with the railroad against
  6–9.5 ms without. 46 of 6606 frames went over 16.7 ms against 5 of 4478,
  mostly near-miss scoring (up to 4.2 ms).
- **Trains far off:** 0.05 ms a frame.
- **Land chunks:** the finest chunk on the line builds in about 14 ms against
  4 ms off it, on a worker thread.
- **GPU: unverified.** Headless draws nothing. Measure a frame log of a
  flight the user flies low along the line through a meeting (AGENTS.md,
  Stutter).

## Landing flats

Along the line, the nearest landing flat is a median 120 m away (60 m on
main) and at worst 720 m, mid west tunnel, the same as main.

## Stood in

Box cars with no engine model, block towns, plain timber and stone spans,
painted colours on the stone shader. No smoke, whistle, sound or people. The
HUD calls a car graze "STONE GRAZE".

## Open: for the user

- **The start faces away from the line.** Nothing of it is in view ahead for
  the first minute; the meeting on the bridge is behind-left. Turning the
  start toward the bay bridge would put it dead ahead.
- **Flats on Boost.** A single 20 m flat passes in under a second, too short
  to dip into; only the two flats before the smash car allow a dip. Pairing
  the low cars would make the bob work on Boost too.
- **FAST tag.** A head-on graze pays about 1.5x, but the HUD never shows FAST,
  so the bonus only shows in the points.
- **Deck skims** score as grazes within about 2.8 m of the deck, about 1.4 m
  lower than over an arch top, because the deck isn't grown by the plane's
  reach (so the wheels can land on it).
- **Towns** read as a town now, but the buildings are tall, three storeys
  rather than one-storey false fronts.

## Open: for a later round

- **The real look:** a steam engine and car models, smoke, whistle and sound,
  frontier-height buildings, dirt streets (needs `land_field.gd`'s chunk pass
  to reach past the bed).
- **Leftovers:** level platforms (they follow the grade, needs a re-lay with
  `tools/rail_line.py`), a hump of hill in the mine town's street, the station
  house across the head of the farm and cattle streets, the hillside face
  beside each portal block, the stretched ground texture by the mine trestle
  (the land's own, it shows with `--no-railroad`).
- **Layout handles:** a layout can't move a span yet (its `rail/<span>` handle
  isn't read); stops and streets are.
- **Perf:** if the GPU log agrees with the headless one, look first at
  near-miss scoring's spikes near the trains and the camera's sight checks.
- **Later ideas:** a branch to a port town facing the pirate ships.

## Tests

Prototype: no tests were added. Existing tests the change touches:
- `test_world_scale_guard.gd` passes.
- `test_cloud_shade_steady.gd`, the only one that loads the main scene, is
  `suite: gpu` and was skipped headless.
- The full suite wasn't run (AGENTS.md: only when asked).

Seed 1's land changed on purpose with the railroad on, so anything that pins
seed 1's land with the railroad on will move. With `--no-railroad` it matches
main.

## Files

- New: `scripts/endless/rail_line.gd`, `rail_bed.gd`, `rail_track.gd`,
  `rail_bore.gd`, `rail_bore_shape.gd`, `rail_span.gd`, `rail_stops.gd`,
  `rail_train.gd`, `rail_trains.gd`, `rail_timetable.gd`,
  `rail_test_path.gd`, `assets/railroad/rail_line.json`, `tools/rail_line.py`,
  `tools/harness/rail_sample.gd`.
- Shared lines: `studies/endless_flight.gd`, `scripts/endless/land_field.gd`,
  `near_miss.gd`, `flight_contact.gd`, `land_stream.gd`, `tree_plan.gd`,
  `endless_grass.gd`.

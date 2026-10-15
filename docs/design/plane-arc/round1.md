# The plane's arc, round 1

The game now starts with the plane broken. Its six parts are spread over
region one at the new scale. You find each on foot, a different way. A
taken part stamps the ledger at once and rides at your side. Press Space by
the plane and it's fitted. With all six fitted, the plane flies.

Branch `feature/plane-arc-1` (from `main`).

## What's built, and where

New logic lives in `scripts/plane_arc/`, with small hooks elsewhere.

- **`plane_arc.gd`** is the arc, made by the aqueduct isle in `_add_life`
  (so the game, `studies/zenscape.tscn`, has it). It handles the state of
  each part (laid, carried, fitted), laying the parts, taking them on foot,
  carrying them, fitting them at the plane, the won't-start beat and the
  flags.
- **`part_spots.gd`** says where each part is, worked out by name from
  each isle's own geometry (see the table below). Motif isles are found
  through `MotifSky.PLACES`. Nothing uses a hard world position.
- **`plane_cough.gd`** is the won't-start beat, played on the parked
  figure: three coughs over 1.8 s, each fainter and lower (the kit's
  `engine-start.wav`, cut short), the plane shuddering, the propeller
  kicking round and falling back (with the propeller lost, the bare shaft's
  stumps), and a puff of grey smoke from the nose. Then the plane is still,
  in its old pose.

### The ledger

- **Plane state is in the save** (`scripts/ledger/ledger.gd`), in the same
  `progress.json` under `"plane": {"carried": [...], "fitted": [...]}`.
  The new calls are `carry_part(part, id)` (marks the objective done and
  saves once), `fit_part`, `is_carried` and `is_fitted`. `reset` and
  `--fresh-ledger` clear it. On load, a part's objective being done
  without the part being fitted counts as carried.
- **A new type, `part`**, counts under the card row **Plane**
  (`data/ledger/ledger.json`), after Runes. Its icon is `part` in
  `scripts/hud_icons.gd`: a brass coin with the propeller across it on its
  hub, the plane-parts coin drawn flat.
- **The six objectives** in `data/ledger/ruins.json` all have placeholder
  names:

  | Id | Name |
  |---|---|
  | `aqueduct_isle/wheel` | What Rolled to the Stones |
  | `aqueduct_isle/fin` | Riding the Old Serpent's Ridge |
  | `cloister_tarn/wingtip` | Beneath the Still Mirror |
  | `drowned_nave/windscreen` | Glass in the Drowned Aisle |
  | `sundered_gorge/propeller` | What the Salvager Trails |
  | `bell_spires/cowl` | Under the Silent Bell |

  The fin's entry is on the aqueduct isle: the serpent carries it past
  the home ledge, where the watcher watches it.
- **`needs_plane`** is on every objective (all 63 are `false` today). The
  registry reads it, defaults to false and rejects anything that isn't a
  bool. `region_progress(region, needs_plane)` and
  `isle_progress(isle, needs_plane)` count by it: `false` counts what's
  done on foot, `true` what needs the plane, and leaving it out counts
  everything.

### Hooks

- **`studies/kit_isle.gd`**:
  - a `plane_arc` var
  - `board_parked` asks `plane_arc.at_plane()` first (fit what he carries,
    or the won't-start beat)
  - `tick` calls `plane_arc.step_pilot`
  - `_make_plane_figure` calls `plane_arc.dress`
  - the foot hint shows the arc's line, and the board line by the plane
    says "fit what you carry" or "try the engine"
- **`studies/aqueduct_isle.gd`** makes the arc, and `watched_find()` gives
  the watcher the fin.
- **`scripts/plane_figure.gd`** gets `twitch_prop(angle)`.
- **`scripts/snag_plane.gd`** gets three things, with their defaults
  matching the study:
  - `yaw`: the loop turned about its ledge
  - `load_maker`: what hangs on the rope
  - `respawns` and `empty()`
- **`scripts/kit_isle/motif_bell_spires.gd`** gets a static
  `belfry_frame()`. `_crowns` uses it, so the belfry stands where it did.

## Where each part is, and how it's reached

| Part | Where (by name) | How |
|---|---|---|
| Wheel | Hovering over the stone circle's standing lintel farthest east, 18.6 m over the turf and 38 m from the parked plane, on the skyline from the start | Up the hill's tiers, the grand stair and the leaning stone onto the lintels. The same climb as the trilithon token, with the wheel on the way |
| Wingtip | 0.45 m under the cloister tarn's surface, in 2.6 m of water across from the shrine isle (at least 1.6 m deep, clear of the shrine's beach) | Swim out to it. Swimming counts as on foot. Wading can't reach it. Its glint sits just over the water, because the binoculars' sight ray stops at the surface |
| Tail fin | Upright on the rune serpent's back crest, 45 m back from its snout (the ring the watcher's rune rode) | Board from the home ledge (or any ledge), walk along its back to the fin and take it. Stay on and the loop carries you on to the cloister tarn |
| Windscreen | Lying 0.22 m under the drowned nave's surface in its aisle, two bays east of the crossing, between the causeway and the north row | Wade in. It rests there for now; the dusk fall comes later |
| Propeller | On a 7 m rope under the salvager's plane (the snag study's plane and verlet rope, `scripts/snag_plane.gd`, a 30 s lap). The loop is turned so its dip runs north along the Sundered gorge's west lip, past the gate tower at the rope bridge's head; its middle is over the west half | Climb the tower's fallen quarter to its crown (the `tower` token's spot), wait for a pass, and leap off the gorge-side edge into the load. Over a lap it comes 2.7 to 3.1 m from the edge and about a metre below it, at about 13 m/s, and never within reach of anyone standing on the crown (2.9 m at closest). Grabbing it tears it free, and the salvager lurches and looks back. No new load hangs |
| Cowl | Jammed under the bell in the bell spires' belfry, 0.3 m under its mouth, about 2 m over the belfry floor | Up the belfry's outer stair, then a jump. **For now, getting to the bell spires needs `--plane-fixed` flight**: they aren't on the serpent's loop, and the airship ferry and the downdraft on the bell come later |

The headless test checks every spot against the built geometry. Each
`--part-at` start was probed headless: each starts grounded at its spot.

## Taking, carrying, fitting

- **Taking:**
  - Only on foot, the pilot's middle within reach of the part (0.6 m plus
    half the part) along the way he moved since the last frame, the same
    sweep as the rune tokens. The rope load can be taken from 1.05 m, as
    in the snag study.
  - It stamps the ledger at once: `carry_part`, saved. A pop names it
    ("The tail fin, off the old serpent's back: it rides with you to the
    plane") and the moments chime blips.
- **Carrying:**
  - It rides at 0.38 of its size, glowing, 0.62 m round him and 0.85 m
    up. Several spread from one side behind him to the other.
  - It adds no weight and limits no move.
  - Flying (with `--plane-fixed`), the parts ride hidden.
  - A fall, a stranding, a respawn or Back to the plane loses none, and
    they're saved as carried.
- **Fitting:**
  - Space (pad A) by the parked plane fits everything he carries. All of
    it is saved as fitted at that moment.
  - Then each part flies from his side to its seat, 0.95 s apart, and
    `set_found(id, true)` plays the seating beat. The paint gets a step
    cleaner each time, and the gleam runs on the last part.
  - Pops: "The wheel seats home", then "All six home: the plane will fly"
    with the flourish.
  - Once all six are fitted, Space boards and takes off as before.

## The watcher (`--watcher`)

He now watches the tail fin, and his rune is gone. A host with
`watched_find()` lends him its find: the aqueduct isle lends the fin while
it rides. The arc places it and makes it glint, and when he takes it the
arc does the taking. Once the fin is gone, whether taken now or saved from
an earlier run, he is done. A host without `watched_find()` still gets the
old rune. The flag is unchanged.

## Flags

- `--plane-fixed`: starts repaired, so the plane flies. The parts are
  still laid and taken. Carried parts stay carried (Space boards). `--fly`,
  `--fly-at=`, `--near-ring` and `--dragon-fly-test` imply it.
- `--fresh-ledger` (existing) also clears the plane's state.
- `--parts-carried`: starts carrying every part that isn't fitted. This is
  a dev start, kept in memory: nothing it takes or fits is saved.
- `--part-at=<id>`: starts by that part. A motif isle is stood up at once.
  - `wheel`: on the same lintel, 1.2 m along
  - `wingtip`: on the shrine isle, facing it
  - `fin`: on the home ledge, the serpent coming (the route's
    `start_at`)
  - `windscreen`: in the aisle, half a bay west
  - `propeller`: on the gate tower's crown, a pass 7 s off
  - `cowl`: on the belfry floor
- `--plane-arc`: a script run (tests, tools) starts repaired unless it
  passes this. Without that default, the existing tests that board the
  parked plane on the aqueduct isle (front door, pause, manual landing,
  isle loop and others) would stop taking off. The game itself always
  plays the arc.

## Checks

- Headless import: exit 0, no errors.
- Load checks, `res://studies/zenscape.tscn --quit-after 300`, all exit 0
  with no script errors:
  - `-- --no-title`
  - `-- --no-title --plane-fixed`
  - `-- --no-title --fresh-ledger --ledger=/tmp/x.json`

  The quit-leak lines ("17–18 ObjectDB instances leaked", "1 resources
  still in use") came and went: none of the three printed them on the
  first pass, and two of three did on the final pass. Earlier handoffs
  (broken-plane round 2, binoculars) report the same lines on main.
  This round didn't compare against main directly.
- Each `--part-at=<id>` and `--parts-carried`: exit 0. One run
  (`--part-at=fin`) printed the known quit leak (15 ObjectDB, 1 resource);
  the others were clean.
- `python3 tools/run_tests.py --tests ...`: `test_ledger.gd`,
  `test_binoculars.gd`, `test_watcher.gd`, `test_snag.gd` and the new
  `test_plane_arc.gd` (about 40 s) all pass. `test_glyph_token.gd` (the
  new icon) passes too.
- **Tests updated for the new data:**
  - `test_ledger.gd`: 57 tokens plus 6 parts, the Plane row on the
    bell spires' and the aqueduct isle's cards, and a `needs_plane` count
  - `test_binoculars.gd`: the card's total is the sum of its rows, not the
    first row
- The full suite was not run.

`tests/test_plane_arc.gd` covers:
- broken on a fresh save, and the won't-start beat with no takeoff
- each part laid by name, and each `--part-at` start on solid ground
- the registry and the `needs_plane` count
- a pickup stamping the ledger and riding along, with the pilot still able
  to run
- surviving a fall off the isle (stranded and back) and a respawn
- fitting one, which cleans the paint a step
- the propeller snatched off the rope, with no respawn
- the fin taken off the serpent's back
- the save round trip
- all six fitted in turn, then the takeoff

## What's weak

- **Nothing was seen rendered.** Unverified: how the parts read in the
  world, the fin on the serpent, the underwater wingtip and windscreen
  through the water shader, the carried parts' spread, the cough's
  shudder, smoke and sound, the parts' flight to their seats, and the new
  card icon.
- **The fin and propeller takes are tested by teleporting.** Boarding the
  serpent and walking its back to the fin, and the leap off the gate
  tower's crown into a load passing about 3 m out at 13 m/s, haven't been
  played. The leap may be too hard. `SNAG_OUT` and `SNAG_UNDER` in
  `part_spots.gd` tune it.
- **The propeller has one way, not two.** The direction asks for an
  obvious-but-hard way and a clever one. Only the crown leap is real: the
  load passes about 9.8 m over the rope bridge's snapped west deck, past
  the updraft's reach (the snag study measured 8 to 10 m). The plane's dip
  also runs along the lip, its belly about 18 m over the turf, rather
  than down between the gorge's walls.
- **The salvager's plane is the snag study's,** drawn 2.5x the toy, so its
  pilot is a giant. It flies through anything, the serpent included. It is
  always there, even after its load is taken.
- **The cowl's glint may be hidden.** It sits inside the belfry, and the
  binoculars' sight ray stops on its walls except through the openings.
- **The wheel shares the trilithon's climb.** The lintel is on the way to
  the `trilithon` token, so the two are found together.
- **Script runs start repaired** (`--plane-arc` opts in). That differs
  from the game on purpose, but it means a test has to ask for the arc.
- **`--parts-carried` saves nothing,** so pairing it with fitting leaves
  the save as it was. That is intended, but it surprises.

## Left for rounds 2+

- **The downdraft** (round 2 in the brief).
- **The airship ferry** to the bell spires, so the cowl is reachable
  without the plane.
- **The cowl's real find:** jammed under the bell until a downdraft
  swings the bell and shakes it loose.
- **The windscreen's dusk fall:** a glint streaking down at dusk, then
  glinting in the nave's water.
- **A second, clever way to the propeller** (or a lower dip into the
  gorge), and tuning the crown leap once it's played.
- The crash opening, damage and losing parts in flight, and handling that
  changes with each missing part (all from the direction).
- **Open:** should the Plane row lead the card? Should a part's
  objective count as "needs the plane" while only the plane reaches it
  (the cowl, today)? Real part names.

# City breaks, round 1: the felled column and the drum floor

Two pieces of the new `city` kit (the underground Olmec city) where the
Olmec's power is the wanderer's tool. They come from the round 3 cards
`maker_felled` (kit-k4-destruction.md) and `colossus_drum`
(kit-k2-contrarian.md). They're built on the merged destruction system
(olmec-destruction rounds 1 and 2).

Branch `kit/city-breaks`, rebased on `roguelike` fd84889f (the walker-only
layer and the underground look).

## Play it

    ./run-city-breaks.command
    ./run-city-breaks.command --underground=haze     # or torch; L flips

This opens `studies/city_breaks_yard.tscn`, a greybox yard with a whole
Olmec hunting you (the chase, the periscope, and this round's chase
routes):

- **The column.** It stands by a gap too wide for you and for his leap
  (11.1 m against his 10.1 m jump gap). The far isle is east of it.
  - Lure him into it from the west and it falls east across the gap. It
    goes over slowly at first. Stand behind it and he either walks
    through it after you or pounces at you through it.
  - Climb the plinth, the stub and the pale spall onto the drums, run the
    span, and drop down onto the far isle.
  - He follows you over the bridge.
  - Lured from the east, it falls west onto the yard instead. The top
    three drums burst and roll. Stay out of their way.
- **The drum court.** It is south-west, with a 4.5 m gallery ledge along
  its north side.
  - Let him pounce at you on the court, then step aside. His landing makes
    the slabs hop in a ring running outward, each slab's carved ring
    flashing.
  - Standing on a hopping slab throws you.
  - Jump just as your slab hops and you are launched to about 5.7 m (your
    own jump reaches 1.5 m).

Keys: R puts everything back (you, him, the column standing, the court
quiet). B puts only him back. F1 shows the numbers. Flags:
`--body-knob=k=v`, `--head-knob=`, `--body-at=x,z`, `--body-face=x,z`,
`--no-body`, `--no-sight-overlay`.

## Registering the pieces in the city family

`scripts/city_kit_breaks.gd` is the entry point. Its `PIECES` are
`maker_felled` and `colossus_drum`, with `NAMES` and `FAMILY := "city"`.
In `scripts/city_kit.gd` (the other agent's file, untouched here):

```gdscript
const CityBreaks = preload("res://scripts/city_kit_breaks.gd")
# in the family's PIECES:  ... + CityBreaks.PIECES
# in piece(id, seed, weathered):
if id in CityBreaks.PIECES: return CityBreaks.piece(id,seed_value,weathered)
```

A scene that places them needs a breaker hub for its Olmecs. The yard's
`Slot` shows how:

```gdscript
var hub := preload("res://scripts/kit_isle/breakables.gd").new()
hub.field = enemies          # the EnemyField
hub.sound_hook = _voice      # optional
add_child(hub)
# every whole/headless body: body.breaker = hub (each frame for new spawns)
# camera: add hub.quake to the shake
```

The hub finds the pieces by the `breakable` group, so a generator can
place them anywhere under the scene. A colonnade's breaks can ride along
in `hub.others`.

## The APIs

**`scripts/city_kit_breaks.gd`** (the family file):

- Builders: `piece(id, seed, weathered)`, `drum_mesh`, `capital_mesh`,
  `plinth_mesh`, `mesh_of(mesher)`.
- `Mesher`: GiantStone's Mesher with smooth lathes, rune rings and a
  `moss` share.
- Sizes: `plinth_rise()`, `plinth_top()`, `column_h()`, `felled_from()`,
  `felled_length()`, `span_most()`.
- `fit(body_jump_gap, body_step)`: the numbers checked against the
  wanderer and the Olmec. The yard prints these at load.

**`scripts/city_breaks/felled_column.gd`**:

- `state`: "standing", "falling" or "settled".
- `how`: "bridge", "ground" or "abyss". It is picked by ray probes along
  the rest line when it falls.
- `fell(hub, sign, why, push)` fells it from code.
- Also: `reset()`, `crown(u)`, and `dealt` (the hits it gave the
  wanderer).
- Hub protocol: `standing_rids`, `rubble_rids`, `met`, `wave`, `veer`,
  `takes_shock`.

**`scripts/city_breaks/drum_floor.gd`**:

- `slab_at(p)`, `slab_top(k)`, `reset()`, `hops`, `dealt`.
- Hub protocol: `wave` and `takes_shock`.
- `slam(at, radius, strength)`: the wanderer's slam hops the slabs round
  his landing without throwing him.

**`scripts/kit_isle/breakables.gd`** (new): the hub. See below.

## What changed in the destruction system

- **A hub instead of one monolith.** `breakables.gd` is the body's
  `breaker` for any number of breakable pieces (the `breakable` group)
  plus `others` (a colonnade's `colonnade_breaks.gd`). It hands on the
  colonnade's whole protocol: `standing_rids`, `rubble_rids`, `met`,
  `wave`, `veer`, `ahead` and `smash`.
- **Shared services for pieces:** `pause` (hit-stop), `shake` (`quake`),
  `sound`, `changed(box)` (every body's routes `forget` it), `knocked`
  (a log of hits), `motor()`.
- **A directional two-way hinge.** The column doesn't snap at a drum
  joint into Jolt pieces. It goes over whole about the plinth's edge on
  the side away from the hit:
  - The fall is a rod under gravity, `PULL` 0.95, from `TOPPLE_W0` 0.3
    rad/s. His push adds at most 0.12 rad/s.
  - Its foot is kicked off the plinth over the last quarter-turn.
  - It is scripted end to end and comes to rest exactly in its authored
    rest (the card's three-state rule). It uses **zero Jolt bodies**, so
    it never touches the 24-body cap.
  - Its rest is ground and wall to both bodies. It is not rubble: he
    doesn't wade a 5.5 m drum.
- **`takes_shock(body, w)` (new breaker call).** A piece can take the
  shockwave's hit on the wanderer itself. The drum floor does, so the
  slab under him throws him, not the wave.
- **The body (`scripts/enemies/headless_body.gd`):**
  - `_shock_meets` asks `breaker.takes_shock`.
  - **Chase routes** (new knobs `chase_routes` 0 by default and
    `chase_replan` 3 s). Hunting, at an edge he can't leap with you
    beyond it, he plans a route to you with his planner and walks,
    climbs and leaps it as roaming does.
    - A failed leg bans that move and he replans at once, still hunting.
    - A route that doesn't reach you drops back to the old hunt, with no
      bail.
    - The yard turns it on. Elsewhere nothing changes.
- **The planner (`scripts/enemies/body_routes.gd`):**
  - `SLOT` 0.5: a floor with less than 0.5 m of room over it is no longer
    read.
  - Why: his column reads went through any solid resting flush on the
    ground and found the ground under it with room to his neck, because
    the room ray started inside the solid. The planner then walked him
    under the felled drums.
  - My rest shapes keep their feet `LIFT` 0.15 m clear (drawn down to the
    ground) so that ray meets their undersides.
  - The same phantom floors are likely under other kit solids. This only
    stops a slot being taken as the nearest floor.
- **The bodies are told one-two physics frames after the rest shapes are
  added.** Told the same frame, the planner re-read the old columns.

## The numbers

| | value | against |
|---|---|---|
| drum | 5.5 m across, 2.2 m tall, 7 of them (card: 6-8) | his hand span |
| plinth | 3 steps of 1.15 m (0.6 m treads), top 3.45 m | under the wanderer's grab 1.88; two treads a cell under the Olmec's stride 2.4 |
| stub | 0.35 m ragged pale foot of the bottom drum | |
| column | 21.6 m tall, capital 2.3 m (echinus 1.2, abacus 7 m square) | about twice him |
| fall | about 2.0-2.4 s from the hit to the impact, then a 0.28 s bounce and the capital's 0.6 s turn-over | card: about 2.5 s |
| felled | drums from 4.55 m out, 15.4 m long, crown 5.5 m (collision 5.58) | under the 6 m fall stun |
| bridge (yard) | rests 3.0 m on the near rim, 1.3 m on the far; gap 11.1 m | his jump gap 10.1, `span_most` 12.8 |
| spall | 1.6 x 3.3 x 3.6 m chunk, top 4.65 m | from the stub +0.85, onto the crown +0.85 |
| fells by shock | within 10 m of his landing (and inside the wave's reach) | card: about 10 m |
| rolls (ground) | the top 3 drums roll 2, 4.6 and 6 m at 6.5 m/s, spreading 0, +5.6 and -5.9 m across | card: up to 6 m |
| slab | 4 x 4 x 1 m, seam 8 cm, court 5 x 5 (20 m) | |
| hop | 0.7 m at his landing to 0.2 m at the wave's rim, times sqrt(power): a 0.05 s crouch, 0.12 s rise, 0.23 s fall, 0.16 s rebound, leaning 0.06 rad outward. Slabs under his feet dip 0.14 m | under the pump catch 2.58 |
| launch | a jump within 0.24 s before his slab hops, or 0.1 s after: up to 5.6 m at the landing (4.4 m at the rim), plus 1.2 m/s out | measured: peak 5.4-6.0 m, window about 0.2 s early to 0.05 s late |
| knock | 3 m up x share, 4 m/s out | measured peak 2.4 m |

## Knock and toss sources

Each source is its own node, so each gets its own `restun_gap`.

| source | when | call |
|---|---|---|
| `maker_felled` | under the falling shaft | `knock`: across the fall 7 m out, 2 m up, plus 0.6 m/s along it |
| `maker_felled` | standing on its top (the abacus) when it goes | `toss`: 5 m/s along the fall, 5 m/s up (no stun) |
| `maker_drum` | in a rolling drum's way | `knock` 9 m/s along the roll and 4.5 m/s up. Already stunned: `toss` (stays stunned). One hit per 1.2 s |
| `colossus_drum` | standing on a hopping slab | `knock` (see the numbers). Stunned: `toss` |
| `colossus_drum` | jumped in time | `toss` launch (no stun) |

His own shockwave (source: the body) is skipped while you're over the
court, so the slab's throw is the only one. Off the court the wave throws
you as before.

## Proof through the real play loop

The drivers are uncommitted in `scratch/`. All pass headless with real
input; setup is noted where it was scripted.

- **`city_lure.gd`** (yard defaults):
  - You stand just east of the column. He chases you and goes through
    it. It falls east as a bridge.
  - You are then set down on the far isle (setup). His chase route
    climbs onto the crown, walks it at 5.47 m, drops off the end, and he
    is on the far isle.
- **`city_cross.gd`** (`--no-body`, column felled by `fell()` as setup):
  - By stick and jump: up the plinth, onto the stub, the spall, the
    crown, along the span, and down onto the far isle.
- **`city_caught.gd`** (`--no-body`, felled as setup):
  - Standing under it: knocked out with `maker_felled`/under.
  - Felled west onto the yard: `ground`. A rolling drum knocks you with
    `maker_drum`/roll.
- **`city_drum.gd`** (`--body-knob=suck_max=0 --body-at=-26,64
  --body-face=0,-1`). The suck is off only so his pounce, not his inhale,
  is the event under test.
  - He pounces at you on the court and you step 6 m aside.
  - Standing: `colossus_drum`/knock, peak 2.4 m.
  - `--timed` (jump pressed as the front nears your slab):
    `colossus_drum`/launch, peak 5.7 m.
  - Swept `--lead`:
    - 0.2 to -0.05 s launches.
    - 0.3 s or more early: you're in the air and clear.
    - 0.1 s or more late: thrown.
- **Smoke checks:** 400 frames each, 0 errors:
  - `run_layer.tscn`
  - `city_breaks_yard.tscn`, also with `--underground=haze`
  - `headless_body_isle.tscn`
  - `whole_body_chase.tscn`
  - `colonnade_spine_isle.tscn --olmec`

## Stills (rendered, gitignored `scratch/film/`)

- **The topple** (`city_film.gd --film=column`, the real lure):
  - `column_default_sheet.png` and `column_haze_sheet.png`: 16 frames
    every 10 from the hit. It goes over slowly, picks up speed, raises
    dust along the line, and the capital turns over.
  - `column_*/21_settled_three.png`: the rest.
  - `column_*/31_olmec_on_bridge.png`: him crossing.
- **The hop** (`city_film.gd --film=court`, his real pounce):
  - `court_default_sheet.png` (high): the ring of lit slab rings staggers
    outward from his landing.
  - `court_haze_sheet.png` (low, haze): the dust wall and you thrown.
  - The hop itself reads less than the rings under the shockwave's dust.
    I raised it to 0.7 m after these frames, and haven't filmed it since.

## Models (`docs/art/model-budget.md`)

Estimated triangles:

- **Column: about 6.5k.** 7 drums of about 690 each (one shared mesh),
  the capital about 500, the plinth and stub about 400.
- **Court: about 7.6k.** Slabs 1.1k, rings 2k, drums under them 4.5k.

Draws: column 7 drums x 2 surfaces + capital 2 + plinth 1 = 17. Court 3
(slabs and rings are MultiMeshes, the drums one mesh).

- **Import LODs / visibility ranges: apply.**
  - The drum is one mesh: a 16-segment LOD past about 40 m halves it
    (-2.4k triangles a column).
  - A visibility range on the court's under-drums past 30 m (they only
    show through a hopping slab) saves 4.5k triangles and a draw.
  - A felled column could merge its drums into one mesh at rest
    (17 draws to about 4: roughly 0.05-0.1 ms render on the Mac).
- **Silhouette geometry: applies a little.** The stub's ragged top and the
  spall are real geometry. The abacus corners are chamfered but not
  chipped. Chips there would cost about 200 triangles.
- **Vertex-colour grime: used.** GiantStone's tone, foot occlusion and
  moss are in the vertex colours.
- **Parallax depth: would suit the glyph rings.** They are a lifted band
  of 48 triangles a drum; a height-map version would save about 340
  triangles a column. That is small.
- **Sculpt high, bake low; rigid parts on bones: don't apply.** These are
  procedural, unskinned pieces.

## Limits

- **The apron isn't built.** The card's flank apron for his lane: I built
  it as stepped tiers, then as a sloped heap. His planner read the tiers
  as a wall to climb. The heap gave him a launch for a 12 m drop leap
  beside the bridge that his body couldn't clear. His way up is now the
  plinth, as a stair: two treads a cell, under his stride.
- **His climb onto the crown is a flank climb** on the near bearing,
  over ground. The yard's gap is placed so 3 m of the felled line lies on
  the near rim. A generator placement needs that bearing too: ground
  under at least 3 m of the near end.
- **Rolls are scripted.** Rolling drums pass through anything in their
  way, and the capital's turn-over doesn't check for obstacles.
- **The fall checks only the ground.** It doesn't check for walls or
  other pieces in its sweep.
- **No ride.** A wanderer on the top is tossed off, not carried down.
- **No cracked state or `slam` trigger** on the column. The drum floor's
  slabs don't crack after 3 hops (both are card ideas).
- **He sees through the standing column.** It is air to his rays, as the
  colonnade's piers are. That is how he charges it.
- **His suck reaches across the gap** and can drag you into it. That's
  real play, but it's why the court trials turned the suck off.
- **Sounds are placeholder synths:** `drum_ring`, `drum_thud`, and the
  colonnade's `ruin_*`.
- **Fallen stays fallen until R.** R stands the column again in the yard.
- **The generator doesn't place these yet.** The ray-probed rest
  (`bridge`, `ground`, `abyss`) is ready for it. It wants two-level
  placement only for an abyss fall.

## Tests

- No new tests (prototyping).
- No committed test reads the headless body or its routes.
  `test_colonnade_spine_isle.gd` was run and passes.
- The `SLOT` and chase-route changes are untested by the suite. With
  `chase_routes` 0 the hunt is unchanged. `SLOT` changes what any
  body's planner reads under flush solids. Smoke runs of
  `run_layer.tscn`, the headless body isle and the whole-body chase are
  clean, but the generator's body routes weren't swept.

## Open questions

- Turn `chase_routes` on wherever the whole Olmec hunts (the generator
  too)?
- The court's launch is a skill window of about 0.25 s. Is that wide
  enough by hand?
- Is the column too tall at 21.6 m, with 7 drums and a 3.45 m plinth, for
  the city's isles? Six drums made the gap leapable to him.
- Should the felled column's rest ever be rubble he wades, or always a
  wall and ground?

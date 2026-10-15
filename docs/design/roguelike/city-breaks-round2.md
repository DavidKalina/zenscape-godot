# City breaks, round 2: where his power reshapes the routes

Four more pieces of the `city` kit, from the round 3 cards: `maker_corbel`,
`maker_skin`, `maker_chock` (kit-k4-destruction.md) and `colossus_plug`
(kit-k2-contrarian.md). Each one trades a route when it breaks. Each rest
is ground to both bodies, and his planner reads it afresh.

Branch `kit/city-breaks-2`, off `roguelike` 6f0129fc.

## Play it

    ./run-city-breaks2.command
    ./run-city-breaks2.command --underground=haze     # or torch; L flips

This opens `studies/city_breaks2_yard.tscn`, a greybox yard with a whole
Olmec hunting you (chase, periscope, chase routes). The pieces stand round
the yard:

- **North, the plug-stone.** A keystone fills the only gate in a 24 m wall,
  which is past his climb.
  - Stand at its face (station 2) and wait for him to pounce at you. Get
    out of the way late, once he's in the air.
  - His bulk landing at the face breaks it. Run through the hole into
    the plug court. He follows you over the heap.
- **East, the chocked slab.** A 15.4 m slab stands on its end at a 13.2 m
  gap, too wide for either of you. A rope holds it back to a timber lever
  jammed by a chock.
  - Climb the striker's block behind the plate (station 3), run off it and
    slam the plate (crouch in the air).
  - The chock flies and the slab swings down across the gap as a flush
    bridge. Don't stand on the far rim where it lands.
  - He also drops it if he steps on the plate or lands within 10 m.
- **South, the corbel vault.** The gate to the vault court. Its outer bay's
  capstone is cracked, with grit sifting from the seam.
  - Bring him to the mouth (station 4) and let him land there. The bay
    comes in.
  - He still walks the gate, over the heap.
  - You climb the heap, then the broken east haunch (a stair of standing
    courses), onto the roof and east onto the upper terrace (station 6).
    It was out of reach before.
- **West, the facing sheet wall.** A 9.6 m terrace wall, faced in sheets of
  bossed basalt.
  - Up the orange walker-only steps at its south end.
  - Stand on a column's top (station 5) over him. When he climbs the face
    under you, that column peels: you ride it down, and his fall's
    shockwave peels its neighbours.
  - Run up the earth slumped behind it to get back on the terrace.
  - With three columns down, the slope is his lane up.

Keys: R puts everything back, B puts only him back, 1-6 are the stations,
F1 shows the numbers (each piece's state and its hits on you). Flags:
`--broken=plug,chock,corbel,skin` starts with those broken.
`--body-knob=`, `--head-knob=`, `--body-at=x,z`, `--body-face=x,z`,
`--no-body` and `--no-sight-overlay` are as in round 1.
`--ground=grass|dust|moss|off` sets the underground's cover (grass by
default here).

## Registering them in the city family

`scripts/city_kit_breaks2.gd` is the family file. It has `PIECES`, `NAMES`,
`FAMILY := "city"`, `BREAKS` (the route contract per piece) and
`piece(id, seed, weathered)`. In `scripts/city_kit.gd` (not touched here):

```gdscript
const CityBreaks2 = preload("res://scripts/city_kit_breaks2.gd")
# in PIECES:  ... + CityBreaks2.PIECES
# in piece(id, seed, weathered, opts):
if id in CityBreaks2.PIECES: return CityBreaks2.piece(id,seed_value,weathered)
```

A scene needs round 1's breakables hub (`scripts/kit_isle/breakables.gd`)
set as each Olmec's `breaker`; the yard's `Slot` does this. The pieces find
the hub by the group `breakable`. For the wanderer's slam they look up a
node named "Breakables" in the scene, because a slam can come before he
calls. They join the slam's group (`scripts/slam.gd` GROUP) themselves.

## The APIs

**`scripts/city_breaks/stone_break.gd`** (new) is the base the four extend.

- Hub protocol: `standing_rids`, `rubble_rids`, `met`, `wave` (each wave
  is asked again until the piece says it's done with it), `takes_shock`
  (false), and `slam(at, radius, strength)`.
  - Subclasses override `_met`, `_wave`, `_slam` and `_step`.
- Services:
  - `source(name)`: one Node per source, so each source keeps its own
    stun gap.
  - `hit(m, source, kind, v, toss, down)`: a knock, or a toss when he is
    already stunned. It logs to the hub's `knocked`.
  - `tell(box)`: the hub's `changed`, two physics frames later.
  - `lift_bodies(boxes)`: an Olmec standing where a rest is laid is set
    on top of it.
  - `fly(node, to, delay, dur, arc)` and `fly_step`: the scripted falls,
    eased in like gravity. `_landed(f)` is called as each one lands.
  - `top_under`, `world_box`, `dust_line`, `part_mesh(blocks, centre)`
    (the city stone, `scripts/city_kit_stone.gd`), `static_body`,
    `box_shape`.
- State is `state` ("whole", "cracked", "falling", "fallen"), plus
  `cause`, `dealt` and `fall_s`.

**`plug_stone.gd`**:

- `fall(sign, why)`, `crack()`, `shocks`, `push_sign`, `heap()`, `reset()`.
- `fit(body_top, body_wide, climb_max)`.
- Constants: `WALL_H`, `OPEN_H`, `THICK`, `LANE`, `JAMB`.

**`chocked_slab.gd`**:

- `release(why)`, `gap()`, `phi` (the slab's angle from flat),
  `slab_xf(a)`, `rest_boxes()`, `striker_boxes()`, `reset()`, `fit(jump_gap)`.
- Constants: `SLAB`, `BEAR`, `PIER`, `PLATE_AT`, `PLATE`, `STRIKER`.

**`corbel_vault.gd`**:

- `fall(why)`, `heap_runs()`, `stair_runs()`, `rest_boxes()`, `roof()`,
  `outer()`, `reset()`, `fit(body_top, body_wide)`.
- Constants: `BAY_L`, `HALF`, `MASS`, `JAMB_H`.

**`skin_wall.gd`**:

- `peel(col, why)`, `cols` (each column's state, angle and cause),
  `col_x(c)`, `col_at(p)`, `down_count()`, `slope_y(p)`, `ride_point`,
  `let_off(m, jumped)`, `rest_boxes(c)`, `height()`, `width()`, `reset()`,
  `fit(climb_max)`.
- The ride is an inner `Ride`: the motor's `rider`, the swing rope's
  protocol.

Every piece's front is +Z.

| Piece | y 0 is |
|---|---|
| Plug | the sill |
| Chock | the rims' tops, with the near rim at z 0 |
| Vault | the hall floor; its cracked bay is toward -Z |
| Skin | the wall's foot, its face at z 0 and the terrace toward -Z |

## How each break goes, and what it trades

| Piece | Triggers | Before | After |
|---|---|---|---|
| plug | `body`: his bulk moving into it, a pounce coming down at its face. `shock`: a landing within 8 m cracks it, and the second breaks it | no way through (wall 24 m, past his 22.4 m climb) | through, over a heap of 0.4 m steps, for both |
| chock | `slam` on the plate; a stunned body thrown onto the plate; `shock` within 10 m, power 0.4 or more; `body` (his feet on the plate) | gap 13.2 m, past his 10.1 m jump gap and his 12.3 m leap | a flush bridge, his lane wide, for both |
| corbel | `shock` within 6 m of the cracked bay (on the floor or the roof); `slam` on its roof | through the hall (both); roof unreachable for the walker | through over the heap (both, open sky over it); heap, broken stair and roof (walker) |
| skin | `shock` (columns within half the wave's reach go for sure, out to 0.8 of it by chance); `body` (he climbs a column 0.7 s); `slam` on the cracked column | plumb 9.6 m: his climb only; the walker can't go up, and down is a stun drop | a 35° earth slope and scree per column; three side by side are his lane |

Every break is scripted. No piece makes a Jolt body, so none touches the
24-body cap. The rests are authored walk boxes, kept LIFT 0.15 m off what
they rest on (round 1's planner rule). Columns stand side by side: no rest
stands on another piece's top.

- **Plug.** It is air to his rays while it stands, so he plans and pounces
  into it (`standing_rids`).
  - Its four quarters topple out the way he pushed: the top two first,
    the foot two 0.35 s later.
  - They burst where they land, and the heap shows there.
- **Chock.** A 0.6 s tell:
  - the chock flies;
  - the counterweight drops;
  - the rope goes;
  - the slab rocks back.

  Then it swings like a rod about its foot. It is slow at the top and
  slams down, about 1.3 s in all. It bounces 0.025 rad and lies in sockets
  cut into both rims, its top flush with them.
- **Corbel.**
  - The bay's whole upper half goes: capstone, courses and haunch core.
  - 14 pieces drop into the hall and burst. The broken masonry swaps in
    under the dust.
  - The heap starts 1.8 m inside the fallen bay. That keeps his head clear
    of the whole bay's courses while he is on a step.
  - It rises in 0.8 m steps to a 3.2 m crest at the mouth, then spills out.
  - The east haunch is left as seven treads, 1.6 m up each, from 4.8 m to
    14.4 m. Then it is 1.2 m onto the roof at 15.6 m.
- **Skin.** Each column's two sheets go over as one board about their foot,
  in three stages:
  1. A 0.35 s tell.
  2. A rod's fall over about 1.4 s, its courses jittered apart as they
     land.
  3. The earth slumping into its slope over 0.8 s.

  Its rest is a convex prism (the slope, going down to LIFT) and the
  upper sheet lying beyond as scree, 1.2 m high.

## The numbers (printed by the yard at load, all ok)

| | value | against |
|---|---|---|
| plug opening over his bulk on the heap | 10.4 m | his bulk top 9.24 |
| plug opening | 8.8 m (his lane) | his breadth 6.72 |
| plug wall | 24 m | his climb 22.4 |
| plug heap step | 0.4 m | walker STEP_UP 0.45 |
| chock gap | 13.2 m | his jump gap 10.08 (and leap 12.3) |
| chock slab | 8.8 × 1.6 × 15.4 m | his lane |
| striker tiers | 1.2 and 2.4 m | grab 1.88; 2.9 m of air over the plate against the slam's 1.8 |
| corbel jambs | 9.6 m | his bulk 9.24 |
| corbel hall | 8.8 m; the lowest course leaves 6.6 m clear (at 9.6 m up, over his head) | |
| corbel heap step | 0.8 m a run of 1.2-1.5 m | under his wall rays' knee (2.5 m) within his reach |
| corbel stair rise | 1.6 m | grab 1.88 |
| corbel roof | 15.6 m (the upper terrace's top) | |
| skin wall | 9.6 m | the fall stun 6.0, his climb 22.4 |
| skin slope | 35° | the motor's slide-off 44° |
| skin scree | 1.2 m | |
| skin columns | 3 m each; three is 9 m | his lane 8.8 |

## Knock and toss sources

Each source is its own Node under its piece, so each has its own
`restun_gap`. I named the sources by piece rather than the card's shared
`maker_slab`, so the logs say which piece hit you.

| source | when | call |
|---|---|---|
| `colossus_plug` | a quarter landing within 3.5 m | `knock` 3 m out, 1 m up, laid down 0.5 s |
| `maker_chock` | on the far rim where it lands | `knock` along the swing, 6 m out, 1.5 m up |
| `maker_corbel` / under | on the hall floor under the bay | `knock` out to the nearer mouth, 8 m, 1.5 m up, laid down 1 s |
| `maker_corbel` / spill | in the spill's way outside the mouth | `knock` 6 m out |
| `maker_corbel` / roof | on its roof as it goes | `toss` (he falls in with it) |
| `maker_skin` / under | on the ground under a column landing | `knock` 4 m out from the wall, 1 m up |
| `maker_skin` / ride | on a column's top as it goes | the motor's `rider`: carried standing on its edge, put off at 1.25 rad with a `toss` hop (3 m/s ahead, 4.5 up), or Jump to hop off |

A stunned wanderer is tossed (he stays stunned), per the stun rules.

## Proof through the real play loop

The drivers are uncommitted in `scratch/`. They all pass headless. Setup
(teleports, his sight set full) is noted.

- **Plug** (`cb2_plug.gd -- --scene-args --body-at=-12,-4 --body-face=0,-1`):
  1. You stand at the face, and he sees you and pounces.
  2. You dodge by the stick once he is in the air.
  3. His landing breaks it (`body`).
  4. By the stick you walk through the gate into the court.
  5. His chase routes plan through it, and he follows over the heap (he
     stood at 1.6 m in the gate).
- **Chock** (`cb2_chock.gd`):
  1. By stick, jump and crouch from the striker's block, the slam drops it
     (`slam`). It is down in 1.87 s.
  2. By the stick you cross the bridge.
  3. Setup: he is put on the near side and has spotted you. He chases
     over the slab.
  - `--trap`, standing where it lands (released from code): knocked by
    `maker_chock`, out along the swing.
  - `--leapcheck`: before it falls he hunts you across the gap, plans,
    finds no route and doesn't cross.
  - He also dropped it once by walking over the plate (`body`).
- **Corbel** (`cb2_corbel.gd`):
  1. At the mouth (setup: spotted from 14 m), he pounces and you dodge by
     the stick. His landing brings the bay in (`shock`, at rest in 1.76 s).
     The spill knocks you (`maker_corbel`/spill).
  2. By stick and jump: four heap steps, the seven broken treads, the
     roof, then the upper terrace at 15.6 m.
  3. Setup: you in the vault court, him spotted. He walks the gate over
     the heap (crest 3.2 m) into the court.
- **Skin** (`cb2_skin.gd -- --back=10 --scene-args --body-knob=suck_max=0`):
  1. You start on column 1's top. You step back while he looks over the
     edge, then onto it when he lays his hand on the face.
  2. His climb peels it (`body`). You ride it down and are put off on the
     ground unstunned. His fall's wave peels three more.
  3. By stick and jump you go up the scree and the slumped earth onto the
     terrace.
  - `--lane` (three columns peeled from code): he comes up the slope onto
    the terrace with no climb (highest on the slope 7.9 m).
  - His inhale is off (`suck_max=0`) only so his suck isn't what moves
    you. With the haze on, his head's inhale over the edge pulled the
    wanderer off the terrace.
- **Smoke checks** (400 frames, 0 errors):
  - `city_breaks2_yard.tscn`, also with `--underground=haze`
  - `city_breaks_yard.tscn`
  - `run_layer.tscn --shape=sprawl --seed=2`

## Hub and body changes

- **The hub** (`breakables.gd`) is unchanged.
- **`headless_body.gd`, `_hunt_wall`:**
  - Hunting, at a wall past his climb, he plans a chase route (round 1's
    `_chase_plan`, knob `chase_routes`).
  - Without it he skirted the plug's jambs or scraped one, and never
    lined up with the gate he broke.
  - With `chase_routes` 0 (everywhere but the yards) nothing changes.

## Stills (rendered, gitignored `captures/cb2/`)

The bursts were made with `cb2_film.gd --rendered -- --film --piece=X
--scene-args --underground=haze`. I looked at all of them.

| Piece | Files | What they show |
|---|---|---|
| Overview | `whole_overview.png`, `broken_overview.png` | the yard before and after |
| Plug | `plug_haze/` (18 frames 4 apart), `plug_haze_sheet.png` | his pounce coming down at the face, the quarters bursting out, the hole, the heap (`31_rest_far_side`) |
| Chock | `chock_haze/` (20 frames 5 apart), `plug_chock_sheet.png` | the rope going and the slow then fast swing; `40_olmec_over_*` is him on the bridge |
| Corbel | `corbel_haze/`, `corbel_haze_sheet.png` | his landing at the mouth, the bay coming in under dust, and the rest; `31_stair` is the broken stair lit by the torch, `32_skylight` the open bay from above |
| Skin | `skin_haze/` (24 frames 8 apart), `skin_haze_sheet.png` | the column tipping out with the wanderer riding its top, the orange-brown core behind it, the lying sheets, the slump's dust |

Tuned from the stills:

- The heaps were pure white slabs in the haze. They are now darker, with
  tumbled chunks.
- The plug is a shade lighter than its wall.
- The chock's and the skin's camera framing.

## Models (`docs/art/model-budget.md`)

All four are procedural blocks in the city stone. There's no Blender model
this round.

| Piece | Whole | Fallen |
|---|---|---|
| Plug | 4.8k triangles, 8 draws | 7.3k, 3 |
| Chock | 8.7k, 11 | 8.7k, 10 |
| Corbel | 6.6k, 5 | 9.1k, 4 |
| Skin | 9.1k, 46 | 9.2k, 45 |

- **Import LODs and visibility ranges apply most.**
  - The chock's two 26 m coursed piers are about 6k of its triangles. A
    plain box past about 60 m, or no coursing under the rim, saves about
    5k.
  - The heaps' chunks past about 40 m: about 2-3k a heap.
- **Merging draws applies to the skin.** It is 30 course meshes plus 5
  cores. Merging each column's standing sheets into one mesh (split only
  as it falls) is about 46 to 12 draws, roughly 0.05-0.1 ms.
- **Silhouette geometry is used.** The broken stair, the heap chunks, the
  bosses and the plug's cracks are real geometry.
- **Vertex-colour grime is used.** Tone and foot occlusion are in COLOR.
- **Parallax depth would suit** the skin's earth core (roots and pits).
  The roots are 4 thin boxes now.
- **Sculpt high, bake low and rigid parts on bones don't apply.**

## Limits

- **Plug:**
  - The shock path (two landings) is coded but wasn't seen in play. Every
    run broke it on the first pounce, by his bulk.
  - The grass tufts poke through its heap's low steps. The heap still
    reads flat under dust.
- **Corbel:**
  - No `body` trigger: his shoulders never reach its courses (9.24 m
    against 9.6 m). The card's harmless face-shed isn't built.
  - The heap is lower than the card's ramp, because his wall rays treat
    anything over 2.5 m above his feet within reach as a wall.
- **Skin:** the ride carries you standing on the column's top end and puts
  you off near the bottom. There's no hang-at-the-lip ride.
- **Chock:** only the bridge rest is built. The lid, stair and rise-to-a-gate
  variants (the card's other swings) aren't.
- **His sight:**
  - The haze's dark and his head's inhale make him lose or pull you a lot.
  - The chock, corbel and skin proofs set his sight full as setup. The
    skin film triggered the peel from code.
- **The generator doesn't place these.** `BREAKS` holds the route
  contract for it.
- **All breaks:** an Olmec under a falling piece is only staggered (or set
  on the rest). Sounds are the colonnade's `ruin_*` synths. Breaks last
  until R.

## Tests

- No tests were added (prototyping).
- The `_hunt_wall` change only acts with `chase_routes` on. No committed
  test covers the body's chase. I know of no test it breaks; that's
  unverified, since the suite wasn't run.

## Open questions

- Is the plug's single-pounce break too easy? The card wanted a charge, or
  two landings.
- Should his own fall off a peeling column peel the neighbours? It cascades
  to 3-4 columns, which makes his lane at once.
- The corbel's roof route is ten jumps. Is that a good climb, or should the
  stair have wider treads?
- Should `chase_routes` be on wherever the whole Olmec hunts?

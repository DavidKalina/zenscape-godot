# City climb, round 1: lanes for two bodies

Six climb pieces for the underground Olmec city's `city` kit. Each one cuts
two lanes into the same stone:

- **His lane** is wide, plain and his size. He walks it, climbs it and leaps
  it with his own planner and chase.
- **Your lane** is narrow and broken. It's on the walker-only layer, so he
  never reads it, and each piece has a true safe room in it: out of his
  reach, his sight and his inhale.

The cards are in `brainstorm/round3-olmec-city/`:

| Piece | Card |
|---|---|
| `city_riser` | k2 `colossus_riser` |
| `city_lip` | k3 `oc_lip` |
| `city_pit` | k3 `oc_pit` |
| `city_wrap` | k3 `oc_wrap` |
| `city_terrace` | k7 `ol_terrace` |
| `city_wedge` | k7 `ol_wedge` |

Branch `kit/city-climb`, off `roguelike` 6f0129fc.

## Play it

    ./run-city-climb.command                       # torch look
    ./run-city-climb.command --underground=haze    # or L in play

This opens `studies/city_climb_yard.tscn`: a paved basalt plaza over the
abyss, with the six pieces round it and a whole Olmec hunting. He has the
chase, the periscope, chase routes and his breaks.

| Key | Station |
|---|---|
| 1 | Start |
| 2 | Giant's riser (SW). Your chimney's arch is in its west cheek. |
| 3 | Hauling lip (E). Your shelves are at its south end; the undercut is your hide. A lit brazier on the top draws him up the face and over the cornice every so often. |
| 4 | Leaper's pit (S), out to the far isle. The jump is his; the cornice along the fins is yours. |
| 5 | Wrapped pillar (NE, over the void). Its start corner sits on the plaza's edge. |
| 6 | Hanging terrace (N), off the plaza's edge. The undercroft is your hide. |
| 7 | Wedged chunk (NW). Your chimney runs beside it; the hollow under its high end is your hide. |

Other keys: R puts everything back (the pieces are rebuilt, so breaks are
whole again), B puts him back, L flips the look, J shows his sight, F1 shows
the numbers. The HUD says whether you're in your lane.

Flags:

- `--olmec=hunt` (the default), `none`, or `riser|lip|pit|wrap|terrace|wedge`.
  A piece name puts his headless body at that piece's foot and his head on
  its top, and he walks his planner's lane to it.
- `--no-brazier`
- `--ground=grass|dust|moss|off`. Grass is the default here.
- `--body-knob=`, `--head-knob=`, `--body-at=x,z`, `--body-face=x,z`

## Registering the pieces

`scripts/city_kit_climb.gd` has no class_name and is preloaded. It exposes
`PIECES`, `NAMES`, `CARDS`, `FAMILY := "city"`, and
`piece(id, seed, weathered, opts)`. In `scripts/city_kit.gd`, which belongs to
the other round and is untouched here:

```gdscript
const CityClimb = preload("res://scripts/city_kit_climb.gd")
# PIECES:  ... + CityClimb.PIECES
# piece(id, seed_value, weathered, opts), first line:
if id in CityClimb.PIECES: return CityClimb.piece(id,seed_value,weathered,opts)
# name_of: NAMES.get(id, CityBreaks.NAMES.get(id, CityClimb.NAMES.get(id, id)))
```

`city_kit_climb.gd` preloads `city_kit.gd` for `CityKit.Piece` and its
constants (`LANE`, `LANDING`, `CELL`, `GAP`, `SEAM`, `_unit_piece`, `_arm`).
If the weathered round renames those, this file follows them.

A scene with breaks needs the breakables hub, as in the city-breaks yard.
The yard's `ClimbSlot` gives every body `breaker = hub`.

## The API

Every piece is a CityKit Piece:

- a Node3D with its front toward +Z
- "Mesh" (the stone, then the runes)
- "Body" (layer 1)
- a walker-only body: "Chimney", "Shelves", "Cornice", "Recess" or "Hatch"

Where y 0 sits:

| Piece | y 0 |
|---|---|
| Riser | its foot's ground |
| Lip | the top he comes over onto (the face's foot is `height` below) |
| Pit | the plinth tops |
| Wrap | its start's ground |
| Terrace | the lower deck |
| Wedge | the ground |

Meta on each piece. CityKit's keys:

- `ports`, `mounts.cresset`, `breaks`, `walk_areas`, `triangles`

And this round's:

- `kind`
- `sizes`: every derived number
- `his`: what he can and can't do, as text
- `his_lane`, `hers`, `safe`: local AABBs (the yard's `in_hers(p)` uses them)

Other entry points:

- `numbers()`: both bodies' live numbers.
- `sizes()`: every derived size.
- `fit()`: each size checked against what it must clear. The yard prints
  this table.

Opts:

| Piece | Opts |
|---|---|
| Riser | `treads` |
| Lip | `height`, `width`, `depth`, `brazier` (lit: a flame, a light and a Beacon) |
| Pit | `gap` |
| Wrap | `turns`, `deep` (the first turn and the core go down into the void; the yard uses 30) |
| Terrace | `lower`, `host_down` |
| Wedge | `run`, `rise` |

Breaks, through the hub:

- **The lip's corner** (one cell square, 4 slabs) is a `FloorBreak`. It
  breaks after 1.2 s of his weight on it, or when his landing or mantle wave
  starts on it.
- **The terrace's outer tier** (3 m, 4 slabs) is a `FloorBreak`. It breaks
  after 2 s of his weight, or on his landing.
- **The pit's east cornice** is two walker-only `CorniceBreak` segments
  (an inner class). His landing wave takes the segment within 6.5 m of where
  he comes down.

## The numbers, and the cards' guesses fixed

These are live values, printed by the yard.

**The wanderer:**

| Number | Value |
|---|---|
| Height | 1.12 |
| Grab | 1.875 |
| Chain (the double-jump catch) | 2.575 |
| Set-off | 1.6 |
| Running jump | 2.0 |
| Long jump | 4.2 on the flat |
| Long jump plus pocket sail | about 9.4 |

**The Olmec:**

| Number | Value |
|---|---|
| Head height (Hh) | 3.36 |
| Width | 4.37 |
| Depth | 2.42 |
| Neck | 6.55 |
| Swat reach | 4.37 flat, within 3.93 up or down |
| Step | 1.23 |
| A riser he walks up | 1.97 |
| Press-up (he mantles a lip at once) | 3.60 |
| Climb | 22.4 |
| Jump gap | 10.08 |
| Bulk | 6.72 across |
| Planner fit | 4.5 |

| What | Card | Built | Why |
|---|---|---|---|
| Riser rise | 2.2 | **3.2** (2 set-offs) | Her chain catch is 2.575, so 2.2 is a step to her. 3.2 is over that and under his 3.6 press-up, so he presses up each riser at once. |
| Riser tread, stair width | 6 m, 6 m | **6.6, 8.8** | His fit, and his bulk's lane (the kit's figure). |
| Riser chimney | 1.6 m wall kick, mouths every second riser | **2.4, ledges 0.9 deep on alternate leaves**, behind the treads in the left cheek beside the summit | This is the refuges' proven chimney. One shaft from an arch at the foot to a door on the summit. |
| Lip overhang | 1.2 | **0.4**, with an undercut 1.4 deep and 1.6 tall behind a 1.3 sill | A 1.2 overhang blocks his planner's climb (`_face`) and his head clips it as he hangs. The sill hides you from his lifted head when he's below. |
| Lip undercut | the whole cornice | **only at your end** | A floor read inside the climb column ends his planner's climb there. His zone's face is plain to the top. |
| Pit gap | 9 m (her long jump "about 7") | **9.07** (his jump gap minus 0.3 Hh) | Measured: her long jump falls short. The long jump plus the pocket sail reaches the far lip (the card's "her glide"). |
| Wrap ramp | 6 m | **12.36** (his lane plus half his bulk) | At 8.8 his shoulders caught on the core. |
| Wrap rise | one turn every 24 m | **3.2 a side, 12.8 a turn**, 13.6° | Your recess climbs 12.8 between his passes. |
| Wrap core | — | **edges chamfered 2.5 m** | His shoulders caught the corners. |
| Wrap recess | open | **closed by a screen, with a door at each ramp pass** | His shoulders caught its jambs. |
| Terrace undercroft | 3.5 tall, 4 deep | **3.2 tall, 8.8 deep** | Under his neck and over you. Its back is out of his reach from the deck's front, and the upper deck cuts his sight. |
| Terrace "grab lips under the tiers" | — | **two shelves up to a hatch slot** | The motor can't climb an inverted ledge. |
| Terrace lower deck | — | **runs a landing past the stair's foot** | He had no room to get onto the stair. |
| Wedge chimney | 1.6–2.2 wall kick | **2.4, with alternate ledges** | — |
| Wedge slab | 15–40°, 8–12 thick | **17.3°, 4.8 thick** | Walkable for both. |

## What he can and can't do

| Piece | He can | He can't |
|---|---|---|
| Riser | Walk the treads and climb each riser. Homing took 4 climbs and reached the summit at 45 s. | Enter the chimney. Its arch and door are 1.4 wide, and its middle is 2.8 m in from the lane. Reach in, or see in past the doorway. |
| Lip | Climb the face anywhere but your end, hang his hands in the troughs and pull over the cornice. Homing: 16.5 s. Drawn by the brazier while you were far off: over at 40 s. Break the west corner. | Stand in or see into the undercut. Hit it with his mantle wave (2.8 m under, his band is 1.9). He does climb straight through your walker-only shelves. |
| Pit | Jump the gap either way. Homing: 1 leap, 27.8 s. His landing breaks the east cornice segment nearest him. | Walk the cornice, pounce onto it (his rays find no floor there) or climb a fin. |
| Wrap | Walk the ramp one and a half turns, then climb the core's last ~9 m to the crown. Homing: 1 climb, 107–111 s. | Enter the recess, the passage or the cell. The cell is 6.4 m from both of his ramps. |
| Terrace | Walk the lower deck, the stair and the upper deck. Homing: 10.8 s. Break the outer tier. | Stand under the upper deck (3.2 clear), reach the undercroft's back, see under the deck, or use the hatch. |
| Wedge | Walk the slab to the crown block (homing: 18.6 s) and the flanking wall's top. | Enter the chimney, stand in the hollow (4.6 at its highest), or reach its back. |

He never stood in your lane, in any run below: 0 frames.

## Proof

All through the real loop, with the drivers left uncommitted in `scratch/`.
`zsh scratch/proofs.sh` runs them all; `scratch/proofs.log` holds the last
run, with 0 FAIL.

**You climb each piece by stick and jump** (`climb.gd --piece=`):

- **Riser:** in by the arch, up 7 ledges, onto the platform, out of the door
  onto the summit.
- **Lip:** up 6 shelves, onto the cornice-front shelf, over the cornice.
  With `--hide`, into the undercut instead.
- **Pit:** down onto the west cornice, along it, up the far step onto the
  far plinth.
- **Wrap:** up 14 ledges, out onto the crown. With `--cell`, into the cell.
- **Terrace:** two shelves and up through the hatch.
- **Wedge:** up 5 ledges onto the wall's top.

**His lane** (`olmec_lane.gd`): with `--olmec=<piece>`, he got whole on top
of all six, with 0 frames in your lane.

**His lanes aren't yours** (`her_limits.gd`):

- The riser: 0 of 6 tries with a running jump and double jump made the
  first tread.
- The pit: 0 of 3 long jumps crossed. With the sail, 3 of 3 reached the far
  lip.

**Hunting** (`hunt.gd`, the whole Olmec), in both haze and torch. Every case
had 0 frames of him in your lane.

| Case | Result |
|---|---|
| `lip_over` | He comes over the hauling lip. |
| `lip_hide` | You in the undercut as he comes over: seen 0 frames, caught 0 times. |
| `riser` | Spotted, you run into the shaft: 0 catches. He scopes, loses you and gives up. |
| `terrace` | Spotted, you run into the undercroft: 0 catches. |
| `wedge` | Spotted, you run into the hollow: 0 catches in the hollow. He sucked you once on the way. |
| `wrap` | In the cell for 40 s: 0 catches. |
| `riser_open` (control) | On a tread in the open: caught by a pounce. |

**He doesn't climb a wall after you when he has lost sight of you.** At the
foot, his chase scopes and then seeks, and the existing chase AI won't climb
after a target that is out of sight directly above him. So "he comes over
the lip" is proved through the lit brazier (a Beacon), with his own planner
and climb.

**Smoke checks, all 0 errors:**

- the yard, torch and haze
- `studies/run_layer.tscn --shape=sprawl --seed=1`

## Stills

These are in `captures/climb/`, which is gitignored. I looked at each one.

- `<piece>_haze.png` and `<piece>_torch.png`: front views of each piece.
- `City<Piece>_<look>_three.png`: the framed back views.
- `lip_climb_haze_hide.png`, `lip_mantle_haze_hide.png`,
  `lip_over_haze_hide.png`, and `lip_*_torch.png`: the Olmec climbing the
  face, his hands over, and him on top with the brazier lit and you in the
  undercut. The sight overlay's rays show in these.

**What they show.** The weathered basalt reads and the coursing gives scale.
The lip sequence is the best moment: a colossus hauling over a coursed wall.
But the pieces are still blocky boxes. The riser reads as a stack of
squares, and the pit and wedge are plain. The riser faces' reliefs are
small, and the chunk doesn't yet read as broken. These need the hero
details next (see Limits).

## Models (`docs/art/model-budget.md`)

All procedural, one mesh per piece, plus the break units.

| Piece | Triangles |
|---|---|
| Riser | 15.8k |
| Lip | 7.0k |
| Pit | 11.6k |
| Wrap | 8.3k |
| Terrace | 6.2k |
| Wedge | 6.6k |
| **Total** | about 56k |

- **Instancing and merging the coursed blocks: applies most.** Every block
  is drawn with all its faces, so hidden joint faces are drawn too.
  - Courses drawn only on the visible faces would save about 40% (about 22k
    triangles).
  - A shared chamfered-block MultiMesh would do better still.
- **Import LODs and visibility ranges: apply.**
  - Past about 60 m, each piece could be its silhouette boxes (under 1k).
    That saves about 45k triangles in the yard's wide view, about 0.1 ms.
  - Ledges and shelves could go past 40 m.
- **Sculpt high, bake low: applies to the hero details.** These are the
  riser's colossal faces, the lip's hand-troughs, and the wedge's broken
  ends and cut stair. Today they are a few blocks each. A baked relief would
  cost about 2–4k triangles a face, but it's the look the cards ask for.
- **Silhouette geometry:** used already (chamfers, chips, corbels and teeth).
- **Vertex-colour grime:** used already (the kit's foot occlusion and tone).
- **Parallax depth:** optional, for the rune bands.
- **Rigid parts on bones:** don't apply.

## Limits

- **His chase doesn't follow you up a face** once you're out of his sight
  above (the existing AI). Only his routes and beacons climb.
- **His shoulders are wider than his planner's fit.**
  - Convex corners and jambs beside his lanes stall him, so the wrap needed
    chamfers, a screen and a wider ramp.
  - The riser's and terrace's 8.8 lanes are fine. Other pieces with corners
    next to a lane may stall him the same way.
- **The lip's shelves are on his face.** He climbs through them; they're
  walker-only, so to him they're air. On the shelves you're in his reach
  and in his inhale's line (he caught you there in the hunts). Only the
  undercut is safe.
- **The wrap's crown is climbable** from his second turn, and he takes that
  shortcut. The corbelled crown is on the south face only; on the east and
  north it caught his bulk.
- **Breaks:** the riser's settle tread and the wedge's "unsettled" shift
  aren't built. The cornice and tier breaks weren't driven in a proof. R in
  the yard rebuilds everything.
- **The brazier draws every calm Olmec** in 90 m to the lip again and
  again: once each beacon rest of 40 s. That includes a homing headless
  body, so it's lit only with `--olmec=hunt`.
- **Not placed by the generator**, and `city_kit.gd` isn't registered (see
  the snippet above).
- **The wrap's cell proof** placed you in it directly, rather than you
  being spotted and running in.

## Tests

None were added (prototyping). No existing file was changed except the new
ones (the kit, the yard, the launcher and this doc), so I know of no test
this breaks. The full suite wasn't run.

## Open questions

- The pit lets you sail the gap (9.37 m against 9.07). Keep that as the
  card's "her glide", or widen the gap to 9.6 (still under his 10.08) so the
  cornice is your only way?
- Should his chase climb after you when you vanish over a lip? Today he
  scopes and then gives up at the foot.
- Should the lit brazier stay as the lip's lure?
- The pieces need the hero sculpts (the riser faces, the lip's troughs, the
  wedge's broken ends). Is that a Blender round next?

## Decisions (the user, 2026-10-14)

- **Leaper's pit: keep the sail crossing.** The glide may later become a run
  item or ability. With it, the sail across the 9.07 m gap is a shortcut;
  without it, the inner cornice is the only way through. Every piece keeps
  a route for the bare moveset; ability routes are extra.

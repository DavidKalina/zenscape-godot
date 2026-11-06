# The wilderness kit: the master list

Started 2026-11-05 from a recorded flight: seed 1, from the start east along
the river valley to the bay, 57 s flown (route and stills from
`scratch/alive_pick.py` + `scratch/alive_playback.gd`, the flight's moments
m00-m10 below). This is the list of what could go into the wilderness, sorted
by how much of it carries over to the next region. Update the Status column
as things are built, shelved or cut.

## How a region is made

A region is handcrafted, but most of what is crafted should be reusable.
Each item below sits at one of five levels, from most shared to least:

| Level | What it is | Lives in | Exists today |
|---|---|---|---|
| **Engine** | One system every region uses: the plane, streaming, the look, and new systems such as the happenings director | `scripts/endless/` | yes, the base |
| **Kind** | A thing with a shape and a flying verb but no skin of its own: "a curtain you punch through", "a row of uprights to thread", "a herd that runs beside you" | `scripts/endless/kinds/<kind>.gd` (new) | arches, splits, stacks, tunnels are kinds already, but only wilderness skins them |
| **Skin** | A kind dressed for one region: water curtain (wilderness), sand fall (desert), ice curtain (icefield) | the region's folder | rock shape kit, ruin kit |
| **Profile** | The region's generated land and its defaults: land recipe, flora, paint, layers, spawn | `scripts/endless/world/profiles/<id>.gd` | yes: wilderness, amberlands, overgrown |
| **Placed** | The hand-placed sites: which kind, which skin, where, by a stable handle | `scripts/endless/world/<id>/placed.gd` (new) + `layouts/endless_flight.json` moves | no: the next step of the fixed-world plan |

A region also lists its **life**, the creatures and their skins, and its
**happenings**: which moments the director may fire there, and at what hour
and in what weather. These are new tables on the profile, next to `layers`.

The rule of thumb: build the kind, then skin it for the wilderness. Something
that only the wilderness can use is fine, but it is marked **W-only** below so
the cost is plain.

## Engine

| Item | What it does | Size | Depends on | Status |
|---|---|---|---|---|
| Placed sites | A region's hand list: `[handle, kind, skin, x, z, heading, params]`, read by the land the way generated sites are; the layout file's moves win | S | — | **now (step 0)** |
| Happenings director | Fires rare moments keyed to place, hour and weather, one at a time, with a cooldown per area; moments register with it | M | placed sites (to key on a place) | **now** |
| Life reacts | Shared reactions to the plane passing: flush, bolt, look up, follow; a creature declares which it does | M | director | **now (with the director)** |
| Stillness | When the plane has landed and stops, nearby life comes closer (creatures approach, birds land on the wing, sound swells) | S | life reacts | next |
| Weather states | Clear, overcast, rain, storm front, snow; re-colours the look, the water and the sound; wind stays a look and never acts on the plane (shelved 2026-11-03) | L | — | next |
| Lightning | Strikes in a storm count as near misses; feeds the unused lightning input of `cloud_volume.gd` | S | weather | later |
| Seasons | Drive the 28-day year in `world_clock.gd`; grass, ground and trees shift | L | weather | parked (a snow day gets most of the effect) |
| Night moments | Make the night part of the day cycle a stage: lit things, night creatures | S | director | next |
| Flight replay stills | Record a flight (pose, not just position) and render stills or a film along it; the harness tool behind this list | S | — | next (from `scratch/alive_*`) |

## Kinds (with their wilderness skin and later skins)

| Kind | Verb | Wilderness skin | Later skins | Spot on seed 1 | Size | Status |
|---|---|---|---|---|---|---|
| **Curtain** | punch through | Waterfall with a cave behind it, out a mouth below | sand fall, ice curtain, a curtain of hanging moss | river cliff near m08-m10 | M | **now** |
| **Upright row / ring** | thread | Standing stones (ring in a meadow); shipwreck ribs (row on a beach) | bone ribs, crystal spires, broken columns | stones on the fast meadow (m03, ~770,70); wreck on the inlet shore west of the start (m00, ~0,40) | M | **now** |
| **Ground escort** | skim beside | Elk or deer herd running alongside | camels, wild horses, ostrich-like runners | the fast meadow (m03) | L (a body + rig + run cycle) | **now** |
| **Roost** | pass by, flush | Owl or pigeons out of a ruin room's rafters; herons off the shallows; ducks running on water | bats in a desert cave (careful: dark swept birds read as bats), gulls off a sea stack | ruin room (m02, ~538,-24); inlet (m00) | S (bird bodies exist) | next |
| **Burst** | skim over | Butterflies or bees up out of flower patches | sand moths, snow off a ledge, ash | poppy patches (m04-m05, ~1350,90) | S (pollen system exists) | next |
| **Slot** | thread, carve | Slot canyon cut by the river, sky a slit overhead | wind-cut desert slot, ice crevasse | river past the butte (m09, ~1910,30) | L | next |
| **Window** | thread | Hole worn through a sandstone butte | ice window, wall window in a ruin | butte at m09 | S-M | next |
| **Span** | thread under, skim over | Natural rock arch over the river; covered bridge (a fly-through) | rope bridge, ice bridge, aqueduct | river m08-m10 | M | next |
| **Grove** | carve | Giant old trees, canopy roof, slalom between trunks | petrified stumps, giant mushrooms | a wood off the meadow | M | later |
| **Drowned place** | skim | Flooded forest of snags in a lake; drowned village with a church tower out of the water | flooded temple, a sunk city | a lake on seed 1 | L | later |
| **Overhang** | fly under | Cliff lip with a rock roof | ice shelf | butte or Peak walls | M | later |
| **Stepped water** | dive | Terraced river: pools and small falls in a staircase | basalt steps | a river with drop | M | later |
| **Blowhole** | time a pass | Sea caves and blowholes spraying on a rhythm | geysers, steam vents | the coast ring | M | later |
| **Strung line** | thread, under | Prayer flags across a gorge that flutter as you pass | lanterns on wires | a split mountain's gap | S | later |
| **Turning thing** | time a pass | Water wheel at a mill on the river; windmill | wind turbine-like ruin, a great gear | river m08 | M | later |
| **Lit chain** | fly past at dusk | Watchtowers along a ridge that light one by one | beacon fires, lanterns | a ridge | M | later (needs night moments) |
| **Drifter** | circle | Hot-air balloons; icebergs off the icefield | airships, floating seeds | the sky; the icefield shore | M | later |

## Wilderness-only (W-only) pieces

| Item | Verb | Spot | Size | Depends on | Status |
|---|---|---|---|---|---|
| Bear fishing a rapid | pass by | the river at m08 | L (body + clips) | stepped water or a rapid | later |
| Salmon jumping the falls | pass by | the waterfall / rapid | S (fish exist) | curtain or stepped water | next |
| Mountain goats on cliff ledges, knocking pebbles loose | pass by | the butte at m09 | L (body) | life reacts | later |
| Hawk circling, dives when you graze | follow | over the meadows | M | life reacts | later |
| Fox past the landed plane | stillness | landing meadows | M | stillness | later |
| Fallen statue: a head in a meadow, a hand out of a hill | carve, thread | a meadow away from the route | M | placed sites; the ruin look on main (`iter/wilderness-secrets`) | later |
| Cliff-hanging monastery with bells | pass by | butte or Peak walls | L | the ruin look on main (`iter/wilderness-secrets`) | later |
| Tower above the clouds | climb to | where the cloud punch was (m07, ~1640,165) | M | — | later |
| Lighthouse on the coast isles | pass by, night | coast isles south of the start | M | night moments | later |
| Fireflies over ponds at dusk | stillness | ponds | S | night moments | next |
| Rail trestle and a tunnel | thread | a valley | L | — | later |
| Airfield: windsock, grass strip, open hangar | fly through, land | the fast meadow | M | — | later |
| Radio mast with guy-wires | knife edge | a ridge | S | — | later |
| Fire lookout on stilts | thread its legs | a hill | S | — | later |

## Secrets

| Item | Verb | Spot | Size | Depends on | Status |
|---|---|---|---|---|---|
| Flame puzzle: carry a flame to light two braziers, or roll over a flame to snuff it; a sealed door opens on a small room with a find | carry, roll | two spots on seed 1 (`secret-kit-handoff.md` on its branch) | — | placed sites: its spots move onto the list once both land | built in greybox and flown; on `iter/wilderness-secrets`, not merged |

The secret area behind a door is a place of its own and gets its own list.

## Happenings (director moments)

| Moment | Where | When | Size | Status |
|---|---|---|---|---|
| Cloud punch: burst out into sun with a rainbow (`celestial.gd` has rainbows), frost on the canopy | any cloud | day | S | **now (first moment)** |
| Ducks or herons run off the water at takeoff | lakes, the inlet | day | S | **now (first moment)** |
| Something huge glides past inside a cloud (sky whale, giant condor) | clouds | rare | L (body) | later |
| Meteor shower; one falling star lands and becomes a find | open sky | night | M | later |
| UFO at night, pulls away if chased | far from the start | very rare, night | M | later (maybe a later world) |
| Bigfoot glimpsed at a treeline | forest edge | very rare | M (body) | later |
| Storm front rolling in | anywhere | weather | — | with weather states |
| Collapsing ruin you outrun | a ruin | after a surge roll breaks it | M | later |

## Settled (2026-11-05)

1. **People: lived-in, nobody seen.** People's things are here and kept up:
   the airfield, mills and windmills, the lighthouse, the lookout, the mast,
   the trestle, balloons. No one is ever seen; there are no human figures.
   The old traces (stones, wreck, drowned village, statue, ruins) stay
   alongside them.
2. **The ruin look is the aqueduct isle's look**: the 2026-11-04 restyle on
   `iter/wilderness-secrets` (cool charcoal stone, no amber lift, more ivy;
   `ruin-look-handoff.md` on that branch). Built structures use it, and it
   reaches main when that branch merges. Pieces from the rock shape kit
   (standing stones, the window, overhangs) don't use it.
3. **Kinds folder.** Arches, splits, stacks and tunnels are kinds already but
   live as wilderness plans. New kinds start under `scripts/endless/kinds/`;
   the old ones move there when a second region needs them.

## Now

Step 0, then four lanes that don't touch each other's files:

0. **Placed sites** (engine, small): the region's hand list and its reader,
   so the lanes below put their pieces at named spots on seed 1.
1. **Director + life reacts + two first moments** (engine): the scheduler,
   the shared reactions, the cloud punch and the waterfowl takeoff.
2. **Elk herd** (kind: ground escort; a body, a rig and clips via the
   enemy-build skill): runs beside you on the fast meadow, bolts from a
   treeline. One body also serves stillness later.
3. **Waterfall curtain** (kind: curtain; wilderness skin): a fly-through
   waterfall with a cave behind it on the river.
4. **Upright ring and row** (kind: upright row / ring; two skins): standing
   stones on the meadow and shipwreck ribs at the inlet, which proves the
   kind takes more than one skin.

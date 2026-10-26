# Rock shapes: sea stacks and hoodoos (handoff)

The endless land has a shared system for free-standing true-3D rock: one
registry, one builder, one streamer and one set of solid queries for the
flight. Two kinds are on it: **sea stacks** in the surf along the coast and
**hoodoos** in badland pockets on valley floors and sides. Both are off by
default in the wilderness. Flags turn them on so you can fly them and decide
where they belong. This is a prototype round: smoke checks, throwaway drivers
in `scratch/rocks/` and rendered stills. No tests were committed.

## Play it

```
.\run-endless-flight.cmd --rock-start=stacks                      # a stack group ahead, flying in low over the sea
.\run-endless-flight.cmd --rock-start=stacks --at=-1049,-1152     # seed 1: a line of 8 stacks
.\run-endless-flight.cmd --rock-start=hoodoos                     # a hoodoo pocket ahead, down its lane
.\run-endless-flight.cmd --rock-start=hoodoos --hoodoo-shape=squat
.\run-endless-flight.cmd --rock-start=hoodoos --hoodoo-shape=tall
.\run-endless-flight.cmd --rocks=stacks,hoodoos                   # both, everywhere, the normal start
```

`--rock-start=K` skips the menu and starts you behind the nearest group of
kind K to the start (or to `--at=x,z`), flying in on its approach line: for a
stack line, out on the sea side heading along it; for a giant, along the coast
toward the channel inside it; for hoodoos, down the pocket's lane. It turns
that kind on if no other flag did. The console prints the group's name, form,
pillar count and the start. F1's numbers have a rocks line.

| Flag | What it does |
|---|---|
| `--rocks=stacks,hoodoos` | Those kinds at density 1. `kind:X` for density X (`--rocks=stacks:2,hoodoos:0.5`), `all` for every kind. |
| `--stacks=X`, `--hoodoos=X` | One kind's density (1 the stock; 0 none). |
| `--no-rocks` | None, whatever the world says. |
| `--hoodoo-shape=squat\|tall\|mix\|0..1` | Squat (Drumheller: short waisted stems under broad flat caps), tall (Bryce: tall banded spires, a small cap or a point), a number between, or `mix` (the default: each pocket one end or the other, 50/50). |
| `--rock-start=stacks\|hoodoos` | Start by the nearest group of that kind (above). |
| `--no-rock-lod` | No levels of detail, to compare. |

A flag sets a kind for the whole world. Without one, each world profile's
`layers.stacks` / `layers.hoodoos` (density, 0 none) decide, per region in
`--world=regions`. The wilderness has both at 0.

## How it works

### The system (`scripts/endless/rocks/`, `scripts/endless/land_rocks.gd`)

- **`rock_plan.gd`** is the registry. `KINDS` maps each layer name to its
  kind script. `plan(field, cx, cz, densities)` is a pure function of the
  seed and a 480 m cell (the arches' `CELL`, so the trees' planner reads
  both through one cache). For each kind with a density over 0 it asks
  `plan_cell` with an rng seeded from the seed, cell and kind. Then it:
  - keeps a group to its region's layer in a world of regions, unless a flag
    set that kind;
  - keeps it `CLEAR` (60 m) past its reach off slot halls, split mountains
    and tunnel sites, and off the arches (`ArchPlan.plan` of the cells round
    it), except for kinds that say `by_arches: false` (the sea's);
  - keeps groups `APART` (80 m past both reaches) from each other. A group
    yields to an overlapping group of a neighbouring cell with a higher
    `_rank` (a hash of the cell). The neighbours' raw plans are cached, so
    the result is still a pure function. (The first sweep found a giant
    from the next cell standing inside a line: that is what this fixed.)
  - names each `endless/rock/<kind>/<cx>_<cz>/<i>`.
- **`rock_kind.gd`** is the contract. A kind plans groups; a group has `pos`,
  `reach`, `pillars`, `foot` (the trees' keep-outs, in the arches' box format)
  and `approach` (for `--rock-start`). A pillar is a list of control rings
  `[y, rx, rz, ox, oz]` (a section's radii and its centre's lean) plus its
  weathering (`lumps`, `grain`, `ledges`, `flutes`, `lump`, `bed`),
  `square`, `dome`, `segments`, `ring_every` and `bare` (no turf on top).
- **`rock_build.gd`** builds a group on a worker:
  - Each pillar is lofted: even rings between the control rings, `segments`
    points a ring, pushed by world-space noise (lumps, grain, beds standing
    out, vertical joints and rills), and the top closed by a fan.
  - The ring count is a multiple of 4. Level L takes every 2^L-th ring and
    point of the same vertices, so one ArrayMesh carries three LODs. Godot
    picks a level by the screen size of its error (`LOD_ERROR`: about 0.06x
    the typical radius plus 0.25x the ring spacing for level 1, 0.2x plus
    0.6x for level 2). Each group is one mesh, one draw.
  - The material is the land's ground material, as for the rock arches, so
    faces read as the land's rock and flat tops grow its turf. A `bare`
    group (hoodoos) gets a copy with `rock_up` past 1, so every face is
    rock.
  - The collider is a trimesh of level 1 (a quarter of the triangles) on
    layer 1.
  - The flight's solid, per pillar and per ring: the ring's centre and 16
    sector radii (the most any point reaches in that turn, widened to its
    neighbours).
- **`land_rocks.gd`** streams the groups like the arches: built on 2
  WorkerThreadPool tasks within 2.6 km, committed within 1.5 ms a frame, freed
  past 3.1 km, primed within 900 m at the start. The solid is found through a
  32 m world grid. Its queries cover every kind at once:
  - `stretches(p)`: the solid's y-stretches over a point, each pillar grown
    by the plane's wingtip (half a span).
  - `ground(p, h)`: answers SkyGlide's `ground` through `LandHalls.over`. A
    pillar raises the land (a face the glide turns along), and a cap's
    overhang is an underside.
  - `inside(p)`: for the camera, its sight line and the rolling wheels.
  - `top_near(p, r)`: the highest top within r, for the rival's look-ahead.
  - `standing()`.

  Each group is placed through `LayoutOverrides` (`xform`, `deleted`,
  `track`). A move keeps its yaw and place, and the solid follows it.
- **Wired once:** `studies/endless_flight.gd` `plane_ground`, `_blocked`,
  `_solid`, `_sight`, the start, prime, step and the HUD, plus
  `flight_contact.gd` `_what` ("stone"). Near-miss sensing needed no change:
  the wing and roof rays meet the layer-1 colliders and name them stone, and
  the ground clearance reads `plane_ground`. A third kind needs no more
  wiring.
- **Trees** keep out of hoodoo pockets: `tree_plan.gd` `_arches_near` adds
  `RockPlan.tree_keepouts` to its per-cell cache. Each pocket gives strips 30
  m apart across it, as arch boxes with no span, so there is no approach
  lane. The native tree plan reads the same list.
- **The rival** (`rival_line.gd`, two small edits): `_ground_top` raises the
  ground by `rocks.top_near(p, READ_SIDE)`, so in the open and on its
  lead-ins it goes over a rock it would otherwise clip. `_in_solid` counts a
  "rock" clip. It does not thread stacks or hoodoos: that would be a new
  opening kind in `_candidates`, for a later round.

### Adding a kind (spires, buttes, ...)

1. Write `scripts/endless/rocks/<kind>.gd`, extending `rock_kind.gd`.
   `plan_cell(field, cx, cz, density, rng)` returns the cell's groups, each
   with `pos`, `reach` (under 480 m), `pillars`, `foot` and `approach`.
   `sea_stacks.gd` is a template for a coast kind, `hoodoos.gd` for a land
   kind (pockets, tree keep-outs, `bare`).
2. Add it to `RockPlan.KINDS` under its layer name.
3. Add the layer to `world_profile.gd` `layers` and to the wilderness
   profile, at 0.

That's all: the flags (`--rocks=<kind>`, `--<kind>=X`,
`--rock-start=<kind>`), the build, LODs, colliders, streaming, handles, the
flight's solid, near misses, crash and scrape grading, the camera, the
rival's look ahead, the trees' keep-outs and the regions' density all come
with it. A pillar whose section is far from round (a fin, a butte's mesa)
works, because the solid keeps 16 sectors a ring. A shape with a hole
through it does not: that is the arches' column solid (below).

To fly a new kind, `scratch/rocks/fly.gd` (git-ignored, on this PC) takes
`--kind=<kind> --mode=lane|gaps|outer|inner`; `look.gd` makes the stills.

### Arches on the system: not moved

The arches stay on their own system. Their solid is columns along the arch's
own x, up to three stretches each, with depth by 3 m band. That suits a span,
not a ring. Their ruins are RuinKit pieces with their own LODs and box
colliders, and `tree_plan.gd` and `rival_line.gd` read `ArchPlan` and the
columns directly. Moving them would mean a second solid type in the builder
and a change to code the race-polish branch is editing. Neither is cheap or
safe this round. The cheap step, when wanted: give `rock_build` a solid type
per kind (rings or columns), make `ArchPlan` a kind, and have `land_rocks`
answer for both. The flight wiring would then shrink by one name.

### Sea stacks (`sea_stacks.gd`)

A try stands in sea 1.5 to 30 m deep, with land within 220 m on some of the
16 ways round but not more than 10 (a bay is skipped). A headland's tip (land
on 5 ways or fewer) takes one 1.5x as readily. The coast's way comes from
which ways the land lies. Then one of two forms:

- **line** (68%): 4 to 8 stacks strung along the coast. Each is set off the
  shore by an inner gap: the channel between it and the land at the flying
  height (6 m over the sea), toy width 9 to 16 (18 to 32 m). That channel is
  the risky inner line. Every third gap is a tight thread (toy 7 to 10: 14 to
  20 m between surfaces). The rest are wide passages (toy 14 to 24: 28 to 48
  m), and 15% are breaks (toy 28 to 40). The threads are spaced so a hand can
  link them: at cruise the plane turns about 30 to 40 m round, so weaving
  every 40 m gap is no line (the first sweep showed it). The open sea outside
  is the safe line. Stacks are 5 to 11 m in radius and 22 to 58 m over the
  sea.
- **giant** (32%): one stack of radius 13 to 22 m, 55 to 100 m tall. Its
  channel to the shore is toy 12 to 30 (24 to 60 m). 65% have one or two
  satellites (radius 3 to 6.5, 12 to 30 m tall) out to sea or along the
  coast, a thread of toy 7 to 11 (14 to 22 m) from the giant.

Every gap is kept between the rocks' widest: radius x 1.06 (tiers) x 1.3 (the
weathering's most push). A stack has a talus under the water, a wave-cut notch
at the waterline, tiers stepping in and out up its body, a lean, a squared
elliptic section, vertical joints and a flat turf top. Seed 1 over 59 km² at
density 1: 17 lines and 15 giants.

### Hoodoos (`hoodoos.gd`)

A pocket is an ellipse 110 to 210 m half-long and 60 to 105 m half-wide. Its
long way runs down the valley on a floor, or along the contour on a side
(where `mountain` is 0.02 to 0.75, the spot no meadow, inland). Through it:

- **The lane:** winds down its length, toy 12 to 16 clear (24 to 32 m),
  swinging 12 to 32% of the half width. This is the safe line.
- **The stands:** darts (900, at most 55 kept) crowd round 3 to 6 clump spots,
  with glades between. A loner away from them takes 18% of the time. Each
  keeps a gap off its neighbours' widest: toy 5.5 to 10 (11 to 20 m) for
  tall, 7 to 12 (14 to 24 m) for squat. These are the risky lines.
- **Families:** 35% of the darts that land on one neighbour grow into it, so
  two or three hoodoos stand as one rock with no false gap.
- **Size:** they stand tallest in the middle and shrink to the rim.
- **Exclusions:** none on a meadow (over 0.12), in or by a river, or on ground
  steeper than 0.75. Trees are kept out of the pocket.

The shapes:

| | squat (0) | tall (1) |
|---|---|---|
| height | 17 m x 0.5–1.25 | 38 m x 0.5–1.25 |
| stem radius | 4.8 m | 3.6 m |
| cap / stem | 1.7 | 1.25 (35% end in a point instead) |
| bands' swell | 4% | 20% (period 4.5–8 m) |
| waist under the cap | 25% | 10% |
| apron at the foot | 1.7x the stem | 2.1x |

Seed 1 over 59 km² at density 1: 9 pockets of 11 to 38 hoodoos.

## Numbers (seed 1, Windows PC)

### Smoke

Headless import, then `tools/smoke.py studies/endless_flight.tscn` with each
of these flag sets. Every one passed with 0 errors:

- no flags
- `--rocks=stacks,hoodoos`
- `--world=regions`
- `--world=regions --rocks=all`
- `--rock-start=hoodoos --hoodoo-shape=tall`
- `--rocks=stacks:2,hoodoos:2 --at=-1600,2100`
- `--world=overgrown --rocks=all`
- `--rock-start=hoodoos --hoodoo-shape=squat`
- `--rock-start=stacks`
- `--no-rocks --rock-start=stacks` (the same start with none)

The last five were run again on the final code.

### Flying them (`scratch/rocks/fly.gd`, through the real input path)

The driver flies the stick's `move_*` actions like a hand. It reads the
stick every 0.2 to 0.35 s with a little noise, looks 0.9 s ahead, and climbs
before a rise. Its aim swings across its line by ±0 / 6 / 10 m (a 4 s
sine). It measures the least wingtip clearance to any rock's real surface:
the solid's rings, not grown, less half a span. `--tight` reads the stick
every frame and looks 0.6 s ahead, to tell geometry apart from a sloppy
hand. Cruise is about 34 m/s. The lines it flies:

- **outer:** past each stack on the sea side, 12 to 14 m off its widest.
- **inner:** the channel between the stacks and the land.
- **gaps:** a stack line's crossings, one every 80 to 220 m, swinging out to
  the other side between them; or a hoodoo field's gaps, 35 to 120 m apart.
- **lane:** a hoodoo pocket's lane.

Contact with the rocks (scrape / crash on stone), on three stack lines
(`--at=-1049,-1152`, `2015,-783`, `1105,-1683`):

| line | wobble 0 | ±6 m | ±10 m | least clearance |
|---|---|---|---|---|
| outer | clean, 3 of 3 | clean, 3 of 3 | 1 scrape on 1 line; 1 crash on 1 line | 6.8–9.2 m at 0 |
| inner | clean, 3 of 3 | clean, 3 of 3 | clean, 3 of 3 | 13–51 m (wide on beaches) |
| gaps, hand-like | clean on 1 line; 2 crashes on each of 2 | scrapes only on 2; 3 crashes on 1 | 1–2 crashes on each | 0.1–2.7 m |
| gaps, `--tight` | clean on 2 lines (least 1.9 and 2.0 m); 1 crash on the third | | | |

Every run came out the far end. The near-miss scoring saw the stacks: "thread"
and "graze" moments on stone on the outer line and the crossings.

**Reading it:**
- The outer line is the safe line: clean with a 6 m wobble.
- The inner line is safe on beaches. It is only a risky line on a cliff coast
  (13 m least clearance on the third line).
- The crossings are risky as meant. A precise line links them; a sloppy hand
  clips. On `2015,-783`, even the tight controller clips one.
- The first sweep, before crossings were spaced (a tight thread every
  second gap, about 40 m apart), crashed on nearly every crossing run. The
  plane's turn at cruise is about 30 to 40 m round.

Contact with the rocks on four hoodoo pockets: squat and tall, each in two
places (`--at=0,0` and `2600,-200`). The driver treats a hoodoo as its
widest from its flying height up, so a cap over the plane counts. Before
that change, its gates ran under squat caps and it clipped them climbing.

| line | wobble 0 | ±6 m | ±10 m | least clearance |
|---|---|---|---|---|
| lane | clean, 4 of 4 | clean, 4 of 4 | clean, 4 of 4 | 5.6–16.5 m |
| gaps, hand-like | clean on 2 pockets; 1 scrape on the tall `0,0`; scrapes and crashes on the squat `2600,-200` | clean on 2 pockets; crashes on 2 | clean on 2 pockets; crashes on 2 | 0.0–6.9 m |
| gaps, `--tight` | clean on 3 pockets (least 2.3–6.8 m); contact (2 scrapes, 2 crashes, some on the land) on the squat one at `2600,-200` | | | |

All four sets of runs flew in on the same `--rock-start` approach, so all
came out the far end. Some runs crashed into the land: the driver holding 7
m over a valley side. Those are not the rocks'.

**Reading it:**
- The lane is the safe line through every pocket.
- Threading the stands is a risk:
  - clean on the tall field at `2600,-200` at any wobble;
  - clean on the squat field at `0,0`;
  - clipped with a wobble on the other two pockets.
- Squat stands keep wider gaps (toy 7 to 12) than tall ones (5.5 to 10). Their
  caps stand at the plane's height.

### Stills (`scratch/rocks/look.gd`, in `captures/rocks/`, local only)

From the plane's view as it flies in, three a group (`*_play0..2`), plus
`*_three` (from round it), `*_far` (from 600 m to 1 km off) and `*_low`:

- `stacks_line_*`: the 8-stack line at `--at=-1049,-1152`.
- `hoodoos_squat_*`: the squat field at `--at=2600,-200`.
- `hoodoos_tall_*`: the tall field at `--at=0,0`.

Judged by eye:
- Stacks read as jointed, weathered pillars with turf tops, the line strung
  off a headland. The first pass's regular beds looked like stacked tyres,
  so the beds were softened and vertical joints added.
- Squat hoodoos read as capped stone mushrooms up a slope. Their caps were
  first lawn-topped like toadstools, so hoodoos now take the bare-rock
  material.
- Tall hoodoos read as a stand of banded spires.
- Hoodoos are the land's rock colour, a little darker in shade than the
  arches.

### The rival (`scratch/rocks/rival.gd`)

`--race-near-start` with a rock start: the challenge is held and the race
followed for 40 s. Two stack lines and a tall and a squat hoodoo field were
raced:

- 0 rock clips in all four. The rival goes over rocks in its way: its look
  ahead reads `top_near` within 9 m. It came as close as the edge of the
  wingtip-grown solid, never inside it.
- It does not choose rocks as openings to thread.
- The other clips logged were on an arch, on a split mountain's route. That
  is existing behaviour, not this round's.

### Frame time (rendered, `scratch/rocks/perf.gd`, uncapped, flying level in)

The same start was flown with and without `--no-rocks`. GPU and frame are
the mean over 14 s:

| | GPU, with rocks | GPU, without | frame, with | frame, without | triangles drawn |
|---|---|---|---|---|---|
| tall hoodoo field (`--at=0,0`) | 11.16 ms (p95 11.73) | 11.71 ms (p95 12.35) | 11.6 ms | 12.0 ms | 6.2M, without 9.5M |
| stack line (`--at=-1049,-1152`) | 7.51 ms (p95 7.90) | 7.68 ms (p95 8.07) | 8.2 ms | 7.9 ms | +71k |

- The cost is within the noise. The hoodoo field is cheaper with rocks,
  because the pocket clears the spruce that would stand there.
- Commits on the main thread:
  - A group's mesh commits in at most 1.3 ms.
  - Each pillar's collider is added afterwards, one at a time, about 0.17 ms
    each, within half of the 1.5 ms budget. A field's collider was first one
    trimesh, which cost 4 ms in a frame.
  - The start's own builds take 4 to 6 ms.
- Worker builds: 19 to 56 ms a cell, the hoodoo fields the slowest.
- Planning: 3.4 ms a cell with the neighbours' checks.

### Triangles (levels 0 / 1 / 2)

- A stack line of 8: about 10–12k / 2.6–3k / 0.7k.
- A giant with satellites: 2–5k / 0.5–1.4k / 0.15–0.35k.
- A hoodoo field: 6–20k / 1.6–5k / 0.4–1.3k (squat); up to 39k / 10k / 2.5k
  (38 tall).

Standing round the eye at density 1, seed 1: 11 stack groups (38 pillars) is
65k at level 0; 3 hoodoo groups (78 pillars) is 55k.

### Model budget (docs/art/model-budget.md)

- **Silhouette geometry:** applies, and is used. The lumps, beds, joints,
  notch, tiers and caps are real geometry on the outline. The faces get
  their detail from the ground shader's rock (world noise, beds). Nothing to
  save.
- **Import LODs:** applies, and is done. Three levels on shared vertices:
  levels 1 and 2 are a quarter and a sixteenth of the triangles. They are
  picked by screen error, about past 300 m and 1.2 km. That saves about 75%
  of the triangles of a group past 300 m, and about 94% past 1.2 km. Most of
  the 2.6 km of standing groups sit at level 1 or 2, so a full coast of
  stacks draws tens of thousands of triangles, not 65k+ per view.
  `--no-rock-lod` turns it off to compare.
- **Instancing and impostors:** not done. Each group is one unique mesh (one
  draw), because world-space weathering makes every pillar unique. At these
  counts, a group's level 2 (150 to 2.5k triangles) is already
  impostor-cheap. Instancing would save memory, not frames.
- **Vertex-colour grime:** partly. The vertex colour carries a noise shade,
  but the ground shader takes the rock's colour from its own beds. Darkening
  crevices, where the push is negative, would cost no triangles: a look gain
  only, not done.
- **Sculpt high and bake low, parallax depth, rigid parts on bones:** do not
  apply (procedural, no textures, no rig).

### Found along the way

- **Fixed:** a startup crash (an access violation, in about 1 run in 9 under
  4 parallel runs). The rocks' and the trees' workers both lazily filled
  static Dictionaries (`RockPlan._arches`, `TreePlan._rock_flags`) with no
  lock. Both are locked now. There have been no crashes since, in 12 runs
  stressed 4 at a time plus the second sweep of about 70 runs.
- **Existing:** the near-miss HUD logs "Invalid polygon data, triangulation
  failed" (`canvas_item_add_polygon`) on some near-miss moments, 300 to 650
  times a run. This is not from this round's code.

## What to judge by hand

- **Where they belong.** Both are off in the wilderness. Is the coast better
  with stacks everywhere (density 1 puts a group on most stretches of coast),
  a few, or only in a coast region? Are hoodoos a wilderness thing at all, or
  a badlands region's?
- **Stacks:**
  - Does the line read as a slalom you can carve? Does the thread every third
    gap feel like a choice?
  - Is the inner channel tight enough to be the risky line? On a beach it is
    wide (20 to 30 m clear each side), because the land at flying height
    stands far back. On a cliff coast it is about 6 to 8 m.
- **Hoodoos:**
  - Squat or tall? The squat field is shorter than the plane's usual height
    over the land, so it is flown low.
  - Do the pockets read as badland? The ground under them is still the
    land's turf: no bare earth or scree is painted there.
- **Feel at contact.** Clipping a pillar sideways brushes along it. Into it
  nose first is a crash, as with a cliff.

## Tests this breaks

None known. The full suite was not run. The world profiles gained two layer
keys (`stacks`, `hoodoos`) and `regions.gd` takes the densest region's value
for them, as for arches. A test that compares a profile's `layers` table
exactly would see the new keys.

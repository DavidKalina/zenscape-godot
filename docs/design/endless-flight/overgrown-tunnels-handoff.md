# Overgrown: mountain tunnels (handoff)

`--world=overgrown` now has mountain tunnels. A raised massif stands over a
winding bore, 1.4 to 2.1 km along its path. Inside, Sundered hall stretches
alternate with carved rock caverns, lit by torch lines on both walls. You can
fly in one mouth and out the other, or land by a mouth and walk in. The
massif, the bore's solid, the mesh holes, the torches and the hall stretches
all hang off one path (`Tunnels.Site`).

The massif and its trenches are a layer over the land field, like the slot
halls' cut, so the recipe and the native kernels are unchanged. Wilderness
hashes exactly as before.

This was a prototype loop (`ITER(mountain-tunnels)`, spec
`spec-mountain-tunnels.md`, brief `overgrown-tunnels-brief.md`): smoke checks
plus throwaway drivers in `scratch/tunnel/`, with no committed tests.

## Launch

- **Test tunnel:** `--world=overgrown --tunnel-test`. Mouth A is 450 m ahead
  of the start, on its heading. This tunnel is built at setup and never
  dropped. Its path is 1692 m: hall 36 bays, cavern of 2 bends, hall 41 bays,
  cavern of 1 bend (with a shaft to the sky), hall 36 bays.
- **Streamed (seed 1):**
  - `--world=overgrown --at=-1388,-1669 --heading=-76.3 --alt=23` flies
    straight into tunnel `-1_-1` (1393 m).
  - `--world=overgrown --at=-1868,1300 --alt=200` puts tunnel `-1_0`'s crest
    shelf (a landable flat, floor y 102) ahead to the north.
  - `--on-foot --at=-2100,1960` stands you on that shelf.
- **Knobs:**
  - `--tunnels=X` sets the density.
  - `--no-tunnels` turns tunnels off; the land then hashes as the slot halls
    left it.
  - `--tunnel-row=0|1` sets whether the hall stretches keep their centre
    column row (two lanes, or one open nave).
  - `--tunnel-shafts=N` sets the shafts per tunnel.

## Round 2: open naves, slippery walls, basalt, overgrowth

This round answers the first "Found in play" item below: the user couldn't
get through by hand unless exactly on line and still. They asked for more
overgrowth and a basalt interior.

### Flying through

- **Open naves** (`Tunnels.OPEN_NAVE`, `--tunnel-nave=open|shut`). A hall
  stretch is now only its two column rows, their architraves and its
  walls. There are no centre row, ties, roof slabs, roof beams across,
  fallen beams, gables or apse ring. The nave between the rows is clear
  up to the rock vault (18 m): 18.6 m clear across past the wingtips
  (`NAVE_CLEAR`, to the capitals less a flight-grid cell). It was the
  8 m lane under ties every bay. `shut` brings back the slot hall's plan.
  Kit additions, both off by default: a piece's `apse` key and a plan's
  `last_beam`.
- **The guard** (SkyGlide `guide`, LandTunnels `guide`). Within 6 m of the
  clear room's edge, here or 0.5 s ahead, a push off the wall grows to
  14 m/s. If the plane points at that wall, its heading eases along the
  path. Near the roof a climb levels and it is pushed down; near the floor
  a dive levels (not when coming in to land).
- **Slippery walls** (SkyGlide `keep`, LandTunnels `keep`). After each move,
  a point past the clear room is put back on its edge with its way along
  kept. Pressed into a wall, the plane slides along it. Before, the brush
  stopped and turned it every frame: the pin. In an open nave the column
  rows are also one smooth wall to the solid (`_in_nave`), so the plane
  can't slip between two columns into the aisle. That pocket pinned it at
  full speed forever.

### The look

- **Basalt** (`shaders/tunnel_basalt.gdshader`, `_basalt_material`). Upright
  columns about 1.8 m across sit on a jittered hex lattice in world XZ. The
  walls show their facets as bands broken by cross joints; the vault and
  floor show hex ends. Each facet bends the normal. Grit and silt cover
  what faces up, with some iron streaks. A faint cold fill means the dark
  between torches reads as grey stone. The torch light is less orange
  (`TORCH_LIGHT` 1, 0.74, 0.5); that warms the hall stone less too.
- **Basalt columns in the caverns** (`_build_columns`). Three rows of hex
  prisms stand along each wall's foot, stepping down outward like a
  causeway, kept under 5 m by a torch. They are part of the rock mesh, so
  the walker stands on them. The flight solid is still the bore: the tall
  row stands within the wingtip's reach of the wall, and only low steps
  come further out. Vertex alpha 0 tells the shader not to draw the
  lattice over them.
- **Overgrowth** (`_build_growth`, in 120 m chunks drawn within 150 m, torch
  lit):
  - roots and vines from the vault (HangingRoots' strand,
    `shaders/tunnel_strands.gdshader`);
  - leafy vine curtains (`shaders/tunnel_vines.gdshader`: cards cut to
    stems and alternating leaves, swaying) down the cavern walls, off the
    hall architraves and in tufts from the vault;
  - ferns (UndergrowthMesh's fern, `shaders/tunnel_fern.gdshader`) at the
    wall feet, round the column bases and out of the rock up the walls;
  - moss in the basalt: on what faces up, low on the walls and in the
    joints.

  The amount follows the vertex green (`_green`): 0.3 anywhere, more in
  patches, full within 90 m of a mouth and 40 m round a shaft. The knobs
  are `GREEN_*`, `VINE_*`, `CURTAIN*`, `FERN*`, `CARD_WIDE` and `TUFT_GREEN`.

### Proof (Windows PC)

These are throwaway drivers in `scratch/tunnel/` (git-ignored).

**Hand-like flights** (`scratch/tunnel/hand.gd`, new). The aim weaves
across the bore (±swing m over 140 m) and up and down. The stick is read
only every 0.2 to 0.35 s, with noise, looking 22 m ahead, so it runs wide
round bends. All runs were headless at boost unless noted.

| run | before this round | now |
|---|---|---|
| ±6 m, shut lane (the old tunnel) | stuck, 8272 brush frames | (`shut` unchanged) |
| ±6 m | — | through, 0 brush, 37.6 s |
| ±9 m, 2 seeds | open nave without the guard: 4909 brush frames, 122 s | through, 0 brush, 38 s |
| ±11 m | open nave without the guard: 349 brush frames | through, 0 brush, 39 s |
| ±14 m, 2 seeds | pinned between two columns at s 89 | through, 0 brush, 40 to 42 s |
| ±18 m | — | through, 0 brush, 41 s |
| ±25 m (aims well past the walls) | — | through, 0 brush, 43.6 s, never under 44 m/s |
| ±9 m at cruise | — | through, 0 brush, 59 s |

Boost holds 45 to 46 m/s throughout. The line autopilot (`bore.gd
--boost`) also went through with 0 brush frames and 0 rock frames.

**On foot** (`walk.gd`): all five legs THROUGH with 0 rescues: feet 0 to
1.1 m over the floor, camera 4.4 to 5.9 m.

**Frame time** (`bore.gd --boost --rendered`, inside): GPU 7.45 / 9.30 ms
(mean / p95), frame 8.37 / 11.28. That is about the first round's
6.75 to 7.26 / 8.85 to 9.58, so the growth and basalt cost little.

**Smoke**: passed with 0 errors for `--world=overgrown` (with and without
`--on-foot`), `--tunnel-test` (with and without `--on-foot`),
`--tunnel-nave=shut`, and the default world.

**Stills**: `captures/tunnel/basalt/` (`*_4.png`: bend, cave_in,
shaft_cave, cave_up, curve; `spill_2.png`, `nave_2.png` near the mouth).

**Exit noise**: a rendered run can end with "N shaders of type
SceneForwardClusteredShaderRD were never freed". The first round's build
logs it on the same `cave_in` view, so it predates this round.

### Not done, next

- The hand driver once dove into the trench floor 29 m outside mouth A and
  landed there, with a 0.3 s reaction and the old pitch gain. Nothing
  funnels the plane into a mouth from outside; the guard starts at the
  portal.
- The gate frame is still not in the flight solid (it stands proud of the
  face, outside the opening).
- `shut` naves have no guard for their columns and ties, so they still
  pin.
- Whether the curtains read as cards up close hasn't been judged in play.
- The lighting bugs, tree flicker and artifacts below are still not
  described.

## What's there

- **`scripts/endless/tunnel_sites.gd`** (new, `Tunnels`) holds the sites and
  the land layer.
  - **The path.** Hall stretches come in whole bays. The caverns are arcs
    (r 130 to 220 m, turns of 22 to 34 deg, alternating), with straight rock
    runs between. The path is sampled every 4 m, and `local(t, x, z)` gives
    distance along and offset across in O(1).
  - **The massif.**
    - A crest runs along the path: 34 m over the floor at a mouth, rising
      over 650 m to at least 150 m over the land on the path (+280 to +380 m).
    - Flanks fall at 0.62, varied ±30%, with ridged gullies.
    - It is blended into the land by a smooth max, so past it the land is
      unchanged.
    - Each mouth gets a trench.
    - The crest gets shelves: landable flats planed into it (`SHELF_*`).
    - A shaft to the sky opens over a cavern's bend (`SHAFT_*`).
  - **Placement.** At most one tunnel per 4096 m square (`CELL`), from the
    seed and the square alone, cached, and safe on a worker. A site is kept
    only if:
    - its mouths are on dry land;
    - its two mouths' land differs by less than `MOUTH_SPREAD`;
    - its box fits the square;
    - rivers are scored against it;
    - each mouth has a flat within `FLAT_REACH`.

    Seed 1 had 10 tunnels in its 16 squares round the start when
    streaming went in (8619d733), before the shelves.
  - **The bore's solid:** `bore_at`, `section`, `profile` and `roof_over`.
    The vault is a superellipse, wider on a bend's inside.
  - **The far-LOD trench:** `trench_under`.
  - **`LandField`** applies the layer after the ponds and before the slot
    halls' cut. A slot hall that meets a tunnel's box is dropped.
- **`scripts/endless/land_tunnels.gd`** (new, node `Tunnels` in
  endless_flight) builds what each tunnel stands.
  - **What it builds:**
    - the carved rock tube (mesh and walker trimesh);
    - the portal fronts: a carved rock mass with a pale gate and fire bowls,
      30 m skirts, and a dark far door seen past 1.2 km;
    - the hall stretches, through its own `LandHalls` with fixed pieces;
    - the torches, the shafts and the daylight spills at each mouth.
  - **Streaming.** Tunnels are built off the main thread when they come
    within 2.5 km, and dropped when far. The collider stands in 4000-triangle
    pieces within 3 ms a frame.
  - **The flight's solid:** `ground` and `inside` for SkyGlide, the camera,
    the sight line and the wheels.
  - **Torches.** 152 torches on the test tunnel, on the hall walls and on
    iron sconces in the caverns. They come in three tiers:
    - the 16 nearest real `flame.gd` flames get 16 OmniLights with no
      shadows, pooled along the way ahead;
    - the rest are flame cards (MultiMesh);
    - far ones are dots.

    Braziers in the portal bowls burn within 450 m. The daylight spots
    within 600 m.
  - **The inside.** The rock and the hall stone (`shaders/tunnel_stone.gdshader`)
    take no sky ambient, so the torches carry the light.
- **Other files:**
  - `land_stream.gd`: the portal holes in the mesh at every LOD, and the
    coarse chunks keeping the trench open.
  - `endless_walker.gd`: the walker's floor inside the bore.
  - `glide_camera.gd` and `studies/endless_flight.gd`: the chase camera's
    `_solid` in rock, and priming and stepping the tunnels.
  - `flame.gd`: the flames switch on and off.
  - `tree_plan.gd`: no trees in the bore or the trenches.
  - `endless_clouds.gd`: `fog_hush`, the valley fog thinned inside a
    tunnel.

## Handles

- `overgrown/tunnel/<cx>_<cz>` (and `overgrown/tunnel/test`) places the
  whole tunnel. Its origin is mouth A on the floor, turned to the path's
  first heading. A move in the layout file moves the massif, the bore, the
  trenches and the stretches together.
- `overgrown/tunnel/<id>/stretch_<n>` names each hall stretch.
- **mouth_a / mouth_b were not added.** The tunnel's own handle already
  stands on mouth A. A mouth moved alone would leave its hole, trench and
  bore behind, so a separate handle would need the path rebuilt to end
  there. That's your call if you want it.

## Proof (this round, Windows PC)

### Flights through the real input path

`scratch/tunnel/bore.gd` works the stick to hold the lane, from the game's
own start 450 m out. All runs were headless unless marked rendered.

| run | result | time inside | brush frames | frames in rock |
|---|---|---|---|---|
| boost | through, mean 46.2 m/s | 36.7 s | 0 | 0 |
| cruise | through, 29.4 m/s | 57.6 s | 0 | 0 |
| boost, roof clip (climbs into the hall roof at s 150 for 3 s) | brushes the ties at 17 m, then on and out | 37.1 s | 15 | 0 |
| boost, roof clip in a cavern (`--cave`, s 474) | brushes the vault at 21.9 m, then out | 39.2 s | 140 | 0 |
| boost, wall clip (holds heading into the first bend's outside wall 4 s) | turned along the wall, out | 37.2 s | 32 | 0 |
| streamed `-1_-1`, boost | through | 30.1 s | 0 | 0 |

### On foot

`scratch/tunnel/walk.gd --on-foot` walks through the stick, with a jump in
each leg. All five legs got THROUGH with 0 rescues:

- trench into hall A: feet 0 to 1.0 m over the floor;
- hall stretch off the line: 0 to 0.4 m;
- cavern bend: 0 to 0.7 m;
- cavern near the wall: 0 to 0.8 m;
- out through mouth B: -0.4 to 1.1 m (the trench's floor is 0.4 m under the
  bore's).

The camera stayed 4.4 to 5.9 m over the floor.

### Frame time and lights

These are rendered `bore.gd` runs on the test tunnel: drive.py's window, the
frame loop unthrottled. "Approaching" is the 420 to 30 m before mouth A, low
over the land. Each cell is mean / p95.

| | GPU ms | render CPU ms | frame ms | lights |
|---|---|---|---|---|
| boost, inside | 7.26 / 9.58 | 1.47 / 1.97 | 9.26 / 13.78 | 16 |
| boost, approaching | 15.39 / 18.43 | 1.59 / 2.24 | 15.70 / 18.61 | 16 |
| cruise, inside | 7.85 / 10.55 | 1.42 / 2.02 | 9.44 / 13.96 | 16 |
| cruise, approaching | 15.15 / 17.85 | 1.53 / 2.22 | 15.37 / 18.09 | 16 |

Another copy of the game was running on this PC through all these runs. It
was a window on the main checkout, using 37 to 74% of the GPU. Read these
numbers as high.

The torch round measured inside with the PC otherwise idle: GPU 6.75 / 8.85,
frame 8.69 / 13.69. The 16 real flames cost about 0.1 ms over cards alone.
The lights stay at the 16 torch lights, plus 4 bowl lights near a portal,
2 mouth spills and the shaft spots.

The first rendered boost attempt this round lost its boost about 20 s in,
because another session's capture window took focus. It was discarded.

### Stills

Contact sheets are in `captures/tunnel/proof/`, built by
`scratch/tunnel/views.gd` and `scratch/tunnel/sheet.py`.

- **`sheet_a.png`, outside the test tunnel:**
  - the massif from 2 km at fov 40, with mouth A a dark gate at its foot
    (`a2000_p.png`);
  - 2 km at the normal fov;
  - mouth A from 1.2 km;
  - the approach from 300 m;
  - the mountain from above, whole;
  - mouth B from 1.5 km.
- **`sheet_b.png`, inside:**
  - hall A's end into the first cavern;
  - the bend (the torch lines curving to the next gate);
  - a hall stretch under rock;
  - a cavern;
  - the shaft's beam over a bend;
  - the last hall toward mouth B.
- **`sheet_c.png` and `exit_lane_zoom.png`:** the cavern bend's torch lines,
  and the last hall on its lane with mouth B's daylight at its end (the exit
  glow).
- **`sheet_d.png`, streamed tunnel `-1_0`:** from 2 km, the approach, from
  above, and its crest shelf from the side and standing on it.

### Smoke

`tools/smoke.py studies/endless_flight.tscn`, headless, passed with 0 errors
in all six runs:

- `--world=overgrown`
- `--world=overgrown --on-foot`
- `--world=overgrown --tunnel-test`
- `--world=overgrown --tunnel-test --on-foot`
- the default world
- the default world `--on-foot`

### Land hashes

From `tools/land_hash.py`:

- wilderness seed 1: exact `c515311f…`, unchanged;
- wilderness seed 7: exact `cd244951…`, unchanged;
- overgrown seed 1: exact `9385c033…`, mm `53611f29…`.

Wilderness has no `tunnels` key, so it reads density 0 and builds no tunnel.
Its frame time was not re-measured this round.

### Flats

`scratch/overgrown/flats.gd`, 6 km square. Each cell is ">400 m / >600 m /
worst m":

| seed | streamed tunnels, first cut (8619d733) | now | `--no-tunnels` |
|---|---|---|---|
| 1 | 33 / 11 / 1205 | 21 / 9 / 1205 | 19 / 9 / 1205 |
| 3 | 7 / 0 / 540 | 7 / 0 / 540 | 7 / 0 / 540 |
| 7 | 34 / 17 / 1364 | 11 / 3 / 818 | 8 / 3 / 818 |
| 42 | 42 / 24 / 1168 | 18 / 12 / 1168 | 17 / 11 / 1168 |

Seed 3 has no tunnel in its square.

The shelves did this. `scratch/shelf/land_on.gd` lands by hand on `-1_0`'s
shelf through the stick and gets out on foot, 6/6 OK.

### LOD from afar

`scratch/tunnel/lod.gd` measures seed 1's 18 mouths at chunk levels 1 to 6.
Before the fix, coarse land stood up to 27 m in front of a gate. Now it is
5.8 m at most through level 5 (2.9 m on all but one mouth). The portal
skirts sink 30 m. Each gate has a dark far door past 1.2 km.

### Known failing tests

These were rechecked headless and all six still fail, each with the same
message as on the slot halls' base:

- test_threaded_recipe
- test_landform_forest
- test_aqueduct_isle_plane
- test_isle_loop_played: "the next piece rises behind it"
- test_rune_serpent: the tube is blocked at 186 m
- test_isle_hall_chain: the no-hitch budget, 5.40 ms, with another Godot
  window loading the PC

## Found in play (the user, by hand, after the loop)

The checks above passed, but the user flew it by hand and found it rough.
Start the next round here, not from the proof.

- **Can't get through by hand.** Every flight proof was an autopilot
  holding one line within 1.8 m. The hall stretches use the kit's threading
  lane (`Hall.LANE`, about 7 m wide, 2.2 m past each wingtip), with the
  roof ties over it, so a person at boost round bends brushes and gets
  pinned. The gate's frame pieces stand up to 3 m proud of the face and
  are not in the flight solid. Next: wide clear lanes in the tunnel's
  hall stretches only (a tunnel width knob that doesn't touch the slot or
  sky halls; `--opening-ratio=` already widens everything for a quick
  try, untested), the gate frame in the solid, and a proof flown with a
  human-like wobble, not one line.
- **Lighting bugs.** Not yet described in detail; ask the user.
- **Trees flickering.** Seen while playing `--world=overgrown`; where and
  how not yet pinned down. Check whether it is tunnel-side (light pools,
  brazier lights, the under-layer cull mask on the DirectionalLight3Ds,
  tree keep-outs) or from the merged base.
- **Artifacts.** Not yet described; ask the user for stills.

Wanted later: a bigger tunnel (cavern size is `CAVE_*`; hall size needs
the width knob above, and a roof-height knob), lighting tuning (`TORCH_*`,
`tunnel_stone.gdshader`), and overgrowth inside (new: a scatter along the
path, on the under layer, drawn only near the eye as the torches are).

## Open

- **The glide over the ceiling: fixed** (7c10fa16,
  `ceiling-stone-sink-fix.md`). Flying up a slope over the ceiling fade no
  longer puts the plane inside the rock.
- **The shaft.**
  - Its cut edge is jagged.
  - From afar, its hole is not cut past 4 m quads, and its curb sits on the
    pit's floor.
  - A walker can step over the curb and fall about 28 m into the cave.
- **The coarse land** pokes 3.5 to 6.4 m through the portal's skin at its
  front corners at 8 to 16 m quads. It wasn't seen in stills.
- **The shelf's turf** reads orange.
- **Not done yet:**
  - the wheels inside (`floor_at`) haven't been driven;
  - the ruins don't know about tunnels;
  - `shaders/tunnel_stone.gdshader` has no `.uid` yet.
- **The layout is yours to tune.** The centre row is a knob
  (`CENTRE_ROW`, `--tunnel-row`). So are the stretch and cavern lengths,
  `TORCH_*` and `SHELF_*`. The flight proof holds with the row on or off.

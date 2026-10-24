# Overgrown: mountain tunnels (brief, after the slot halls)

The overgrown world gets tunnels through mountains raised for them. A
massif stands over each site, and a winding bore runs through it for
30 to 45 seconds of flight at boost. The bore alternates straight stretches
of Sundered hall with curving caverns of bare rock, and torches light the
whole of it. You fly into a mouth on one flank, follow the torch lines
through the bends, and come out on the far side.

It builds on the slot halls round (`world/overgrown-slot-halls`,
`overgrown-halls-handoff.md`): hall sites picked from the land, a layer over
the field, hall sections standing in it, and the plane's ground giving way
to the hall's own solid. Read that handoff first.

Run it as Opus rounds through the `iterate` skill, in a fresh worktree set up
with `python tools/worktree.py setup <path>` (without it the native kernels
are missing). Cut the worktree from `world/overgrown-slot-halls` and merge
`main` into it first. That branch is not on main yet, and main has moved
since (the water rounds). Prove one tunnel end to end first, then stream
many.

## Size

- **Length along the path:** 1.4 to 2.1 km, rolled per tunnel. That's 30 to
  45 s at boost (46.2 m/s) and about 50 to 70 s at cruise (29.4 m/s).
- **Bends:** gentle S-curves, 3 to 5 over the run, never a hairpin. SkyGlide
  turns at `TURN` 1.7 rad/s on full stick, which at boost is a 27 m radius.
  Keep the centreline radius at 120 m or more, about a third of the stick at
  boost. Prove the number by hand-feel later; start there.
- **Floor and roof:** level through the bends in the first round, so a bend
  is steered sideways only. The floor may step or slope gently on the
  straights later.
- **Openings:** sized from their toy widths with `WorldScale.opening()`, as
  the slot halls' are. Rock caverns are at least as wide and tall as the
  hall stretches either side of them, plus room on the inside of the bend.
- **Ways out:** `sundered_hall.gd`'s `MAX_SHUT` rule still applies. A long
  shut stretch needs a way out, so a bend or two opens on a shaft or a side
  breach to the sky. That also gives a glimpse of daylight partway through.

## The raised mountain

- **A layer over the field,** as the ponds and the slot cuts are, so the
  recipe and the native kernels don't change and wilderness hashes as before.
  The massif is applied before the bore's cut. `sample`, `shape`, `height`,
  `build_chunk` and `grid` all see it, as they see the cut.
- **Shape:** a peak or short range big enough to hold the whole winding bore
  with rock over the vault (30 m or more at the thinnest). The bore's mouths
  sit on its lower flanks, with an approach in front of each that reads from
  1 to 2 km. The massif blends into the land around it, with no plinth edge,
  and stands tall enough to be a landmark (about 250 to 400 m over the land
  around it; judge by eye).
- **Placement:** at most one tunnel per large square (start at 4096 m), from
  the seed and the square alone, safe on a worker. The site, its massif and
  its bore all stay inside the square, so a point asks only its own square,
  as the slot halls do. The slot halls stay as they are. A square that has a
  tunnel keeps its slot halls out of the massif's footprint.
- **Meadows and flats** (AGENTS.md): the massif must not eat the flats. Check
  with `scratch/overgrown/flats.gd` (6 km square; seeds 1, 3, 7, 42) against
  the slot halls' numbers. Prefer raising it over land that is already
  ridge or hill, and keep a landable flat within reach of each mouth so the
  walker can land and walk in.

## The heightmap's problem

The land is one height per (x, z). The mountain's surface stays whole over
the bore, so everything that treats "under the height" as rock needs an
exception inside the bore's footprint:

- **The land mesh.** At each mouth the slope needs a hole where the portal
  meets it. The chunk builds (`scripts/endless/land_stream.gd` and the
  native build, or a post-pass in `apply_chunk` as the slot handoff
  suggests) skip triangles inside a portal's outline, with every LOD
  agreeing so no seam or flap shows from afar. The same goes for any shaft
  opening to the sky.
- **The land collider.** Inside the bore's footprint and under its roof, the
  land must not collide. Check how the chunk colliders are built and whether
  they can skip the footprint. Don't assume a NaN-hole trick works; prove it.
- **The flight's solid** (`plane_ground`, `floor_at`, SkyGlide `ground`,
  `inside`). The slot halls' 1 m grid in the hall's frame already answers a
  roof as `Vector2(top, underside)`. The bore adds the rock: walls on both
  sides, a floor, and a rock roof the plane can hit. A winding bore needs its
  solid in the path's frame (distance along, offset across), not one straight
  hall frame.
- **Things that sample the height.** Grass, flowers, trees, ponds, rivers and
  the ground paint sample the surface. They're fine on top, but none may
  spill into a mouth, and no river runs into one.

## Inside

- **Hall stretches:** straight pieces from `SunderedHall.slot_piece` and
  the near/far builds the slot halls use, now under rock. Rock walls and
  vault meet the hall's own walls and roof. Where the hall is broken, rock
  shows through.
- **Rock caverns:** the bends. Carved rock that curves from one hall stretch
  to the next, with a floor you can land and walk on. Its mesh, collision and
  flight solid come from the path, so they agree.
- **Portals:** a carved gate or the hall's west front set into the flank,
  framed so the mouth reads from 1 to 2 km. It shouldn't be a black hole in
  a hillside. Torches or braziers at the mouth help it read in low light.
- **Camera:** the chase camera's `_solid` check (`studies/endless_flight.gd`)
  knows the rock walls and roof, so it doesn't clip into rock or pop out
  above the mountain in a bend.
- **Others:** birds and traffic stay out. On foot, the walker can land near
  a mouth and walk in; prove its floor works inside, in a hall stretch and
  in a cavern.

## Torches

- **The tunnel's main light.** Darken the inside (the sky's ambient and the
  sun alone light a tunnel far too brightly), and let the torches carry it.
  The far mouth glows, and any shafts stay bright.
- **Use `scripts/flame.gd`** (`kind = "torch"`): raymarched flame volumes,
  sparks, smoke and a flickering warm OmniLight3D. `in_lantern` and the
  braziers are there too, and `scripts/city_fire.gd` shows fires set on kit
  pieces.
- **Lines that show the way.** Torches run along both walls, about every 20
  to 30 m, so a bend ahead shows as a curve of lights before you're in it.
  Through a bend, the outside wall is lit brighter or closer. In hall
  stretches they sit on the hall's walls or columns, and in caverns on iron
  sconces or niches in the rock.
- **Cost.** A tunnel holds roughly 100 to 150 torches. Only the nearest
  handful (start at 16, no shadows) get a real light and the full flame;
  the rest are a cheap glowing flame with no light, and torches far down the
  bore are a dot of glow. Pool and recycle them along the path as the plane
  moves. Report the light count and frame time inside.

## Handles

Each tunnel, its portals and its stretches get stable names through
`scripts/layout_overrides.gd` (`overgrown/tunnel/<cx>_<cz>`,
`.../mouth_a`, `.../stretch_<n>`). A move in the layout file moves the
massif, the bore and its cut together.

## Opt-in

It's an `overgrown` profile layer (`tunnels`, 1.0 in `overgrown/look.gd`).
Wilderness has no key, so it reads 0 and its hashes, stills and frame time
stay unchanged. `--no-tunnels` turns them off, and the land then hashes as
the slot halls round left it. `--tunnels=X` sets the density.

## Suggested order

1. **One tunnel, by flag** (`--tunnel-test`, a few hundred metres ahead of the
   start): the raised massif, a winding bore of 2 or 3 hall stretches and the
   caverns between them, holes in the mesh at both mouths, the collider
   exception, the flight's solid with walls and a roof, a greybox inside,
   and a greybox torch line. Prove a flight through on the real input path
   at cruise and boost, a crash on the roof, a crash on a wall in a bend,
   and on foot inside.
2. **Dress it:** rock materials, the hall acts inside, portal fronts, real
   torches with their pooling, the dark inside, the far mouth's glow, a
   shaft or breach to the sky, the camera.
3. **Place many:** sites from the seed, massifs that blend, streaming, LOD
   and seams from afar, handles, cost, flats.

## Proof the user will want

- Stills: the massif from 2 km with a mouth showing, the approach, a torch
  line curving round a bend, a hall stretch under rock, the exit glow, and
  the mountain from above looking whole.
- A flight through on the real input path at cruise and boost, with its time
  inside, plus a deliberate roof clip and a wall clip in a bend.
- Frame time at cruise and boost, approaching and inside, with the live
  light count.
- Smoke headless for `--world=overgrown` flying and `--on-foot`, and the
  default world. Wilderness hashes unchanged (`tools/land_hash.py`).
- Known failing tests: test_threaded_recipe, test_landform_forest,
  test_aqueduct_isle_plane. On the slot halls' base, test_isle_loop_played,
  test_rune_serpent and test_isle_hall_chain failed too; recheck those.

## Notes

- **Mac:** the dylib needs rebuilding for any native change (commands in
  `world-profiles-handoff.md`). Keeping the massif and the bore as GDScript
  layers, as the slot cut is, avoids that.
- **If the hole mask goes native:** keep the native and GDScript chunk builds
  bit for bit (a parity driver, as in the native rounds).
- **Low ties** stay refused in hall stretches (see the slot handoff); the
  glide has no under-slide for stone ceilings yet.

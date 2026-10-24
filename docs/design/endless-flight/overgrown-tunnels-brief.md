# Overgrown: tunnel halls (brief, after the slot halls)

This is the long-term form of the overgrown world's halls: a Sundered hall
that bores through a mountain. You fly into a mouth on one slope, through the
nave inside the rock, and out the far side. It follows the slot halls round
(`overgrown-halls-brief.md`) and builds on what that round leaves:
hall sites picked from the land, the cut layer over the field, hall sections
standing in a cut, and the plane's ground giving way to the hall's own solid.
Read that round's handoff first. If it hasn't run, run it first.

Run it as one or more Opus rounds from `main`, in a fresh worktree with
`python tools/worktree.py setup <path>` (without it the native kernels are
missing). The scope is big enough for the `iterate` skill: one tunnel
proved end to end first, then streaming many.

## The problem a heightmap gives

The land is one height per (x, z) (`LandField`, GDScript and native, bit
for bit). A tunnel is space under that surface, so everything that assumes
"above the height is air, below it is rock" has to make an exception inside
the tunnel's footprint:

- **The land mesh.** The mountain's surface stays as it is over the tunnel, so
  from outside the mountain looks whole. At each mouth the surface needs a
  hole where the portal meets the slope, or the slope covers the entrance. The
  chunk mesh builders (`scripts/endless/land_stream.gd`, the native chunk
  build) need a hole mask, meaning triangles skipped inside a portal's
  outline, with every LOD level agreeing so no seam or flap shows at a
  distance.
- **The land collider.** The chunk colliders treat everything under the
  surface as solid, so a plane or walker inside the tunnel is underground and
  gets pushed out or crashes. Inside the tunnel's footprint, and below the
  roof, the land must not collide. Check how the chunk colliders are built
  (concave faces or a heightmap shape) and whether they can skip the
  footprint. Don't assume a NaN-hole trick works; prove it.
- **The flight's ground and crash checks** (`plane_ground`, `floor_at`,
  SkyGlide `ground`, the rolling plane's `inside`). Inside the tunnel they
  follow the hall's solid query, with a floor and now a ceiling: the
  roof is a lid the plane can hit. Arches already answer `ground` and
  `inside` for their legs. Copy that, and add the ceiling.
- **Things that sample the height.** Grass, flowers, trees, ponds, rivers and the
  ground shader's paint all sample the surface. That's fine on top of the
  mountain, but none of them may spill into the portals. A river or valley
  shouldn't run into a mouth unless that's meant.

## The tunnel itself

- **Interior:** hall sections from the existing pieces (`scripts/sundered_hall.gd`
  acts, `scripts/sundered_build.gd`, `scripts/ruin_kit_hall.gd`), now
  enclosed. Rock walls and the vault meet the hall's own walls and roof.
  Where the hall is "broken", the rock shows through, and shafts of light
  come down through openings to the slope above. The `shafts` act is the
  natural place for those, and it means a few small holes in the surface
  over the tunnel too.
- **Portals:** a carved gate or the hall's west front set into the slope,
  framed so the mouth reads from 1 to 2 km away. It shouldn't be a black
  hole in a hillside.
- **Light inside:** the sky's ambient light and the sun's shadow alone
  will light a tunnel far too bright, or wrongly. Darken inside the footprint
  (a fog volume, a darkening term in the hall and rock materials keyed to
  depth under the surface, or Godot's occlusion and probes), keep the light
  shafts bright, and let the far mouth glow. Judge it by eye.
- **Size:** openings from their toy widths with `WorldScale.opening()`.
  A tunnel is flown blind around bends, so keep the nave mostly straight or
  gently curved, with the exit seen early. Keep `sundered_hall.gd`'s
  `MAX_SHUT` exit rule in mind: a long shut stretch needs a way out, such as a
  shaft or a side breach to the open air.
- **Camera:** the chase camera's solid check (`_solid` in
  `studies/endless_flight.gd`) has to know the tunnel walls and roof, so it
  doesn't clip into rock or pop out above the mountain.
- **Others:** birds and traffic stay out of tunnels unless meant. On foot, the
  walker can enter from a landing near a mouth. Prove that its floor works
  inside.

## Placement and the rules

- Sites come from the seed and the cell, safe on a worker, through a
  ridge or mesa that's thick enough for a nave with rock over it. Use the slot
  round's site finder, plus a check for rock over the vault. Each site, portal
  and section gets a stable handle name through `scripts/layout_overrides.gd`.
- It's opt-in per world (`overgrown` profile layers), so wilderness hashes,
  stills and frame time stay unchanged.
- Keep meadows and flats in reach (AGENTS.md). It's a prototype: smoke checks plus
  throwaway play-loop checks, with no committed tests.
- Streaming and cost: plan on workers and stand within a per-frame budget,
  as trees and grass do. Hole-masked chunks must not rebuild more often
  than before. Report frame time at cruise (29 m/s) and boost (46 m/s),
  including inside a tunnel.

## Suggested order

1. **One tunnel, by flag** (`--tunnel-test` near the start): a straight
   bore through one ridge, with a hole-masked chunk mesh, a collider
   exception, `ground`/`inside` with a ceiling, a greybox interior and
   portals. Prove a flight through it using the real input path, a crash
   on the roof, a crash on a wall, and on foot inside.
2. **Dress it:** hall acts inside, portal fronts, light (dark interior,
   shafts, glowing far mouth), the camera.
3. **Place many:** sites from the land, streaming, LOD and seams from afar,
   handles, cost.

## Proof the user will want

- Stills: a mouth from 1 to 2 km, the approach, inside the nave (dark with shafts),
  the exit glow, and the mountain from above looking whole.
- A flight through using the real input path at cruise and at boost, plus a deliberate
  roof clip.
- Smoke headless for `--world=overgrown` flying and `--on-foot`, plus the default
  world. Wilderness unchanged.
- Known failing tests: test_threaded_recipe, test_landform_forest,
  test_aqueduct_isle_plane.

## Notes

- **Mac:** the dylib needs rebuilding for any native change (commands in
  `world-profiles-handoff.md`).
- **If the hole mask goes native:** keep the native and GDScript chunk builds
  bit for bit (parity driver as in the native rounds).

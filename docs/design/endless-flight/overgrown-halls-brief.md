# Overgrown: slot halls (brief for the next round)

The next round puts Sundered hall sections into the overgrown world's
ridges: a clean cut through a ridge, the hall standing in the slot, its roof
spanning the rock walls, and the plane flying in one end and out the other.
The longer-term goal is a true tunnel through a mountain, so build the slot
so it can grow into one: a rock roof over the slot, and a hole in the ground
mesh where the mouth meets the slope.

Run it as one Opus round on `main`. Make a fresh worktree from main's tip and run
`python tools/worktree.py setup <path>` first, or the native kernels are
missing and the land runs in slow GDScript. An agent `isolation: "worktree"`
is cut from main, which is right this time.

## Where things stand

- The engine is shared, and worlds are profiles
  (`world-profiles-handoff.md`). Overgrown is `--world=overgrown`:
  `scripts/endless/world/profiles/overgrown.gd`, with its land recipe in
  `scripts/endless/world/overgrown/land.gd` and its paint, flora and layers
  in `world/overgrown/look.gd`. Wilderness is the default and must not change.
  Wilderness as it stood is tagged `world-wilderness-v1`.
- Overgrown's land (`overgrown-land-handoff.md`, including its Tuning section) has long
  low ridges with crisp crests: in `shape()` a ridge is where `mountain` >
  0.7, about 150 to 250 m wide and 70 to 150 m tall, with crests 2 to 4 km
  long. It also has rare notches (flat floors 40 to 90 m wide, now shallow
  saddles), terraced hills and tiered mesas. The field doesn't expose notches
  or ridge lines yet. `scratch/overgrown/finder.gd` (git-ignored, in the
  game-visual-polish worktree) finds them by diffing.
- The land is a heightmap, kept bit for bit identical in GDScript
  (`scripts/endless/land_field.gd`) and native
  (`native/terrain_kernels/land_field.h`). Ponds show how to cut a layer
  into the land without touching the recipe: `scripts/endless/land_ponds.gd`
  is applied in `LandField.sample` over either field, and the native tree
  kernel takes the ponds GDScript passes it.
- Arches show how a placed structure and the flight meet:
  `scripts/endless/land_arches.gd` stands the meshes and colliders, and the
  plane's `ground` and the rolling plane's `inside` treat its legs as solid.

## The hall side

- `scripts/sundered_hall.gd` plans a hall as a sequence of acts (gate, nave,
  shafts, cloister, slit, apse), each a stretch of bays. It is plain data,
  safe on a worker, and also answers the solid query.
- `scripts/sundered_build.gd` builds it with near and far detail and
  streams the near detail. `scripts/ruin_kit_hall.gd` holds the RuinKit
  colossus hall pieces.
- `studies/hall_chain.gd` and `studies/hall_rise.gd` raise halls out of the
  cloud sea one at a time; reuse their pieces, not their sky framing.

## What the round should build

1. **Placement.** Pick hall sites from the land: a straight stretch of
   ridge, or a notch, that a hall of N bays fits through. It must come
   from the seed and the cell alone, so the same land gives the same halls,
   and be safe on a worker. Give each site a stable handle name
   (`overgrown/hall-<cell>` or similar) through `scripts/layout_overrides.gd`,
   so the user can move one in the world editor and the saved layout wins.
   Expose the site to the field, as with `last_notch`/`last_mesa`, if that helps.
2. **The cut.** A layer over the field, like ponds, that lowers the land
   along the hall's footprint to its floor and gives the slot sheer, clean walls
   (the "sundered" cut). Keep it out of the recipe so the native land
   stays untouched. If the cut must be native for chunks or trees, mirror
   it bit for bit. Grass, trees and ponds stay out of the slot.
3. **The hall.** Hall sections from the existing pieces stand in the slot,
   with the roof spanning wall to wall in places and open in others, using
   the hall's own act sequence. Size the openings from their toy widths with
   `WorldScale.opening()`.
4. **Flight.** Inside the footprint, the plane's ground and crash checks
   follow the hall's own solid query, not the raised land (as with arches),
   so you can fly the nave. Keep exits within reach, as `sundered_hall.gd`'s
   `MAX_SHUT` rule does.
5. **Streaming and cost.** Halls stream with the land, with near and far detail,
   and are planned on workers and stood within a per-frame budget, as trees
   do. Report frame time at cruise (29 m/s) and boost (46 m/s).
6. **Rules** (AGENTS.md): meadows and flats in reach (rerun the flats check
   from `scratch/overgrown/flats.gd` or promote it to `tools/`), stable handle
   names, WorldScale as the only size source. It's a prototype, so a smoke
   check plus throwaway checks through the real play loop, with no new
   committed tests.

## Proof the user will want

- Rendered stills: a hall seen from 1 to 2 km so the cut reads from afar,
  the approach to its gate, inside the nave, and the exit.
- A flight through a hall using the real input path at cruise, without
  crashing, plus a flight that misses it.
- Smoke headless for `--world=overgrown` flying and `--on-foot`, plus the default
  world. Wilderness hashes and stills must be unchanged.
- Known failing tests: test_threaded_recipe, test_landform_forest,
  test_aqueduct_isle_plane.

## Notes for later rounds

- **Aqueducts:** along overgrown's flat valley floors and across the gaps where
  a valley cuts a ridge or a mesa. The aqueduct isle's pieces are in
  `studies/aqueduct_isle.gd` and `scripts/kit_isle/`.
- **Trees:** overgrown keeps wilderness's spruces for now. The user wants
  a different tree type for this world, because green spruce clashes with
  the warm palette and the mesas.
- **Olmec heads:** they can stand as big landmarks (scenery, not the enemy).
- **Overgrowth:** moss and vines on the ruins.
- **Mac:** the dylib needs rebuilding for both targets
  (`world-profiles-handoff.md`). Until then the Mac runs the grass, trees
  and overgrown's land in GDScript.
- **Walking:** in the land round's driver, walking after landing in
  overgrown barely moved. It is probably the driver, but it hasn't been checked.

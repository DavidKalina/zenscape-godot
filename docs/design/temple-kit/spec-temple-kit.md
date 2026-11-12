# Spec: the temple kit (loop `temple-kit`)

Asked 2026-11-12. A new ruins kit, modelled in Blender: the remains of a
classical temple (columns, fallen drums, lintels, a stepped platform, a
broken wall). The old code-built kit (`scripts/ruin_kit*.gd`) stays as it
is and keeps every place it stands in. Nothing from it has to be reused.

Why a new one: the old pieces are flat planes with a tiled stone texture,
and up close they read as textured boxes. The tower on the wooded island
north of the pirate ships (`way/isle`, `scripts/endless/way_towers.gd`) is
the one the user pointed at: a flat box, an olive moss wash, white chips,
black ivy blobs. Stills of it: `captures/shots/coast_waytower*.png` (not
committed; shoot again with the command under Checks).

## Done looks like

1. `studies/temple_kit_gallery.tscn` shows every piece on grass under the
   game's own sky and light, and a still of it reads as worn cut stone at
   three distances: 400 m, 60 m and 6 m.
2. In the main scene (`studies/endless_flight.tscn`, seed 1, wilderness) a
   temple ruin built from the kit stands on the island at `way/isle` in the
   belfry's place. The plane can fly between its columns and under a lintel
   by hand. The other two way towers are untouched.
3. `--temple=0` puts the old tower back, for an A/B.

## The kit's contract

Iteration 1 (the base) settles these and writes the numbers it chose back
into this section (`ITER(temple-kit): spec change: the kit's numbers`).

- **Source:** `art/blender/temple_kit/`. One shared module,
  `temple_lib.py` (cut blocks with worn and chipped edges, block courses
  with open joints, drums, the weathering colours, the export), and one
  build script per lane (`<lane>_build.py`) that imports it. Run with
  `python tools/blender.py run ...` (AGENTS.md, Running on Windows).
- **Models:** `assets/models/temple_kit/<piece>.glb`, one per piece. The
  shapes carry the look: real courses and joints, broken silhouettes,
  chipped arrises, missing blocks. Colour is per vertex (stone tone,
  crevice dark, weather stain, moss on up-faces). No per-piece textures.
  Budgets from `docs/art/model-budget.md`; each piece has a far LOD.
- **Stone:** one shader, `shaders/temple_stone.gdshader`, for the whole
  kit. Vertex colour for tone, at most one shared tiling detail map baked
  in Blender if the base finds the shapes alone look bare at 6 m. It must
  sit in the world's light the way the land does at noon and at dusk (read
  how `shaders/ruin_stone.gdshader` and the lighthouse's material in
  `scripts/endless/coast_sites.gd` take the sun, fill and haze before
  writing it). Pale, warm, weathered stone. Not black in shade.
- **Loader:** `scripts/temple_kit.gd`. `PIECES` (ids), `piece(id) -> Node3D`
  with a `Mesh` child, and `boxes(id) -> Array[AABB]`, the piece's solids in
  its own frame (few and coarse: the flight's solid is boxes, see
  `way_towers.gd` `_commit` and `box_solid.gd`). The boxes are written by
  the Blender export beside the model, not typed by hand.
- **Module:** the fly-through sets it. Clear gap between two standing
  columns at least 13 m (the colosseum's hand-flown arch is 12.8 m; check
  it against `scripts/world_scale.gd` `opening`), clear height under a
  lintel at least twice the gap. Column diameter, height, the bay (centre
  to centre), the step height and the wall thickness follow from that with
  classical proportions, and every piece snaps to the bay.
- **Gallery:** `studies/temple_kit_gallery.tscn` with its script and a
  `run-temple-kit.command` and `.cmd` launcher beside the existing ones.
  It lays out `PIECES` by itself, so a lane adds its ids to the list and
  the gallery shows them.

## The pieces

| Built by | Piece ids | What |
|---|---|---|
| base | `column` | a standing column: base, fluted drums with open joints, capital |
| lane `columns` | `column_broken`, `column_drums` | a stump broken a third of the way up; fallen drums and a capital lying in the grass |
| lane `entablature` | `lintel`, `lintel_broken` | the beam across two columns (architrave, frieze, cornice); a broken end still on its column, with the fallen half as part of the piece or a second mesh |
| lane `podium` | `podium`, `podium_stair` | a bay of the stepped platform, with a corner; a wide flight of steps up it, part collapsed |
| lane `wall` | `wall_door`, `wall_broken` | a bay of the inner wall with a tall doorway the plane fits through; a wall end stepping down to rubble |

About nine pieces. A lane may add one more if a piece needs a partner to
read right, and says so in its notes.

## Order

1. **Base** (trunk, one iteration, before the lanes): the contract above,
   `temple_lib.py`, the shader, the loader, the gallery and `column`.
2. **Lanes** (four agents at once, each in its own worktree cut from this
   branch after the base): `columns`, `entablature`, `podium`, `wall`.
   Each keeps its code in its own `<lane>_build.py` and its models, adds
   only its ids to `PIECES`, and does not edit `temple_lib.py` or the
   shader. If the library lacks something, the lane writes the helper in
   its own file and names it in **Notes for merge**.
3. **Trunk** (after the merge, in order):
   - **Site:** the temple at `way/isle`. A new file
     (`scripts/endless/temple_site.gd`) builds it from the kit; `way_towers.gd`
     skips its belfry there unless `--temple=0`. It keeps the handle
     `way/isle` (`at()`, LayoutOverrides, the trees' keep-out sized to the
     new footprint) and its solids reach the flight the way the tower's do
     (`game.arches.loose`). The find `isle-tower`
     (`scripts/endless/finds_table.gd`) still works: move its ring to a
     spot the temple makes worth flying (between columns, under the
     lintel) and fix its title. Repeated columns draw as one MultiMesh.
     It is a ruin: a standing run of columns with a lintel or two left,
     the rest fallen, grass through the floor.
   - **Look and flight:** stills of the site from the bay tower's foot
     (it must still show as a landmark from there), from the approach and
     from inside, at noon and at dusk; fix what reads wrong. A throwaway
     driven flight through a column gap and under the lintel at medium
     weight, with the line offset sideways and in height by a wing's
     width each way, so the gap is proved with margin and not on one
     exact line. The site's triangles and draw calls against the belfry
     it replaced, in the commit's Checks.

## Checks

- Smoke: `python tools/smoke.py studies/temple_kit_gallery.tscn` and, from
  the Site task on, `python tools/smoke.py studies/endless_flight.tscn`.
- Stills: `python tools/shot.py studies/temple_kit_gallery.tscn ...` for
  pieces; for the island,
  `python tools/shot.py studies/endless_flight.tscn --at 1090,70,2800 --look 990,25,2700 --settle 400 --timeout 240 --out captures/shots/<name> -- --no-title --at=1000,2760`.
  Look at every still before committing.
- Prototyping rules (AGENTS.md): no committed tests, no full suite. A
  commit lists any existing test its change breaks.

## Not in this loop

- The cracked chamber on Long Isle (`cracked/long-isle`) and the
  lighthouse. Both were shown to the user with the tower; the tower goes
  first. Dressing the chamber in the kit is a later round.
- Breaking the new pieces, ivy, and swapping the old kit's other places.
- The cap and the budget are the skill's defaults.

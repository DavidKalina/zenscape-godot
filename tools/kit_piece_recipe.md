# Building a RuinKit piece

Printed by `python tools/kit_piece.py recipe`. Symbols are named by file and
func/const; grep for them rather than reading the files whole. Sizes come
from `python tools/kit_piece.py numbers`, never copied by hand.

## The contract
- `RuinKit.piece(id, seed, weathered)` (scripts/ruin_kit.gd) returns a
  Node3D with a "Mesh" (MeshInstance3D) and a "Body" (StaticBody3D), foot on
  y 0 round the origin, front toward +Z. Same seed, same faces
  (tests/test_ruin_kit.gd checks every id in `ALL_PIECES`, both weathered
  ends, and a size bound).
- A family file (`scripts/ruin_kit_<family>.gd`) has `const RuinKit =
  preload(...)`, `const Build = RuinKit.Build`, a `PIECES` list, a static
  `piece(id, seed, weathered)` match and one static builder per piece with
  card knobs as defaulted args. Models: scripts/ruin_kit_cloister.gd
  `pent_hood`, scripts/ruin_kit_relic.gd `relic_nimbus`,
  scripts/ruin_kit_torana.gd `torana`, scripts/ruin_kit_keel.gd
  `keel_hung_stair`.
- Registration in scripts/ruin_kit.gd: the family's `*_PIECES` const,
  `FAMILIES` (the editor palette groups by it), `ALL_PIECES`, `NAMES`
  (palette label) and the `if id in X_PIECES: return load(...).piece(...)`
  line in `piece`. `kit_piece.py new` does all of this plus the connector
  stub. Keep ids stable: saved motifs name them.

## Stone (scripts/ruin_kit.gd)
- `var b := Build.new(seed, weathered, "Label")`; `b.rng` is the only
  randomness (draw in a fixed order). End with `var node := b.finish()`,
  then `node.set_meta(...)`, then return.
- Blocks: `b.solid(planes, pose, colour, collide := true, wear := true,
  extra := [], open := -1, rough := 1.0, growable := true)`. Planes from
  `RuinKit._box(b, half, chamfer)`, `_prism`, `_axial_prism(_y)`, cuts from
  `_break`; pose jittered by `RuinKit._jiggle(b, pose, loose)` or
  `_settle`; colour `RuinKit._stone(b, tone)` (tone ~0.85-1.05 per course).
- Ready-made parts: `_courses` (coursed walls with `_worn_top`/`_ruin_line`
  tops), `_pier`, `_buttress`, `_flight` (a stair), `_arch_ring`,
  `_ring_order`, `_circle_ring`, `_jambs`, `_rake`, `_gablet`, `_spire`.
- Build knobs: `b.settle` (how far stones move out of true), `b.cull`
  (drop hidden joint faces: cheaper), `b.ground` (cut what is sunk under
  y), `b.lean` (cheap stone), `b.frame` (lay a sub-part in another frame,
  restore it after), `b.clear` (AABBs growth keeps out of: a flown lane).

## Wear, grime, shelter
- Wear is automatic in `solid` from `weathered` (`Build._wear`: chips,
  chunks, AGE..1); turn it off per block with `wear := false`; `rough`
  scales it. Ragged breaks are explicit cut planes (`extra`).
- Shelter: `b.shelter = func(mid: Vector3, n: Vector3) -> float` (0 open
  air .. 1 deep under a roof) feeds the vertex alpha the stone shader
  bounces on (shaders/ruin_stone.gdshader). See `pent_hood`, `relic_nimbus`,
  `torana`.
- Soot / vertex grime: before `finish`, walk `b.pending` (faces: [corners,
  normal, colour, ...]) and darken `face[2]` (`pent_hood`'s HOOD_SOOT loop,
  `torana`'s SOOT).

## Growth
- Ivy: `b.hang(at, length, free := true, from := -1.0)` (strands off an
  underside); `finish` grows ivy (`_ivy`), fringes (`RuinGrowth.fringes`)
  and moss cushions (`_cushions`) on growable up-faces by `weathered`.
- `b.tuft(at, height, count)`: grass on a ledge or the ground.
- `RuinKit._drift(b, at, reach, count)` (fallen stones heaped, often a
  first step) and `RuinKit._rubble(b, reach, count)`; scale counts by
  `weathered`. `RuinKit.set_detail` thins all small growth for far/cheap.

## Collision and ledges
- Drawn worn blocks make poor floors (Jolt rounds hull edges; worn tops
  pit). Draw with `collide := false` and walk on clean hulls:
  `RuinKit._walk_box(b, pose, half_x, bottom, top, z_front, z_back)` or
  `RuinKit._walk_hull(b, pose, planes)` (true, unworn). A hull thinner than
  `HULL_THIN` is dropped.
- A ledge he can climb onto is a hull whose top is at least `STAND` deep
  past its lip: the motor's `_stand_on` (scripts/pilot_motor.gd) only
  catches a lip with a standing place `CLIMB_IN` in. A top to walk along is
  `TOP_ROOM` across; head room over a floor is `HEAD` (+0.2).
- Heights: one jump `GRAB_TOP`, a pump `CHAIN_TOP`, a climbing stair of
  standing places `SET_OFF` apart (each tread `STAND` deep); slopes under
  `SLOPE_SLOW` walk freely, `SLIDE_FROM`..`SLIDE_AUTO` slide when crouched,
  over `SLIDE_AUTO` can't be stood on (a surf). Wall-kick shafts are
  `KICK_GAP` wide. A flown opening is `WorldScale.opening(TOY_WIDTH)`.
- Moving parts: a Body marked `moving_ground` (meta) is carried by the
  motor (keel_hung_stair's "Flight").

## Meta, live parts, hosts
- Meta is the piece's own table for routes and hosts: lines, tops, gaps,
  `thread`, ropes. Return it from the builder via `node.set_meta`.
- Ropes: meta `ropes` = [{anchor, length, dry, tag, bell}] in the piece
  frame. `MotifAuthored.hang_ropes(specs, frame, hang)`
  (scripts/kit_isle/motif_authored.gd) hangs them through a rope Callable;
  `MotifAuthored.ropes_of` caches them per piece and `MotifAuthored.live`
  hangs them in authored places (motif_greybox's hook). The editor
  (studies/motif_editor.gd `hang_ropes`, `rope_host`) does it on place,
  turn, reload and play. Get FootPieces at run time with
  `load("res://scripts/roguelike/layer_greybox.gd").FootPieces`; a const
  preload of layer_greybox.gd / foot_pieces.gd in the editor or a tool
  leaks the script graph at exit ("Pages in use" fails the smoke).
- A live rig with no host (keel_hung_stair's "Rig",
  scripts/keel_hung_stair.gd): a child Node that steps itself in
  `_process`, joins its trigger group itself (slam) and finds the pilot as
  the scene's `motor`; built on the trap contract (scripts/traps/trap.gd:
  knobs, reset). Then editor, authored places and yards need no host code.

## Connectors (scripts/ruin_kit_fit.gd)
- `RuinKitFit.connectors(id, node)` match arm: a list of
  `_c(name, at, facing, kind, mode)` in the piece frame, read off the
  family's constants (or `top_of.call(h)` for a seed-dependent top).
  Modes: "end" (ends meet, facings opposite), "post" (axis on the ground),
  "top" (something's foot stands on it). `MATES` says which kinds mate
  (wall_end, column, channel, aq_pier, flight_top/foot, hinge); add a kind
  there only when two pieces really join. A piece whose size changes gets
  its arm updated. Add `const X = preload("res://scripts/ruin_kit_x.gd")`
  near the top when the arm reads the family's constants.

## LOD and budget
- The stone is merged by its host (motif isles); RuinLod
  (scripts/kit_isle/motif_isle.gd) builds far levels of stone and growth.
  Nodes a piece adds itself (ropes, tags, rigs) can take a
  `visibility_range_end`. List docs/art/model-budget.md's tricks in the
  handoff with triangle counts (weathered 0 / 0.6 / 1).

## Proving it
- `python tools/kit_piece.py yard <id>`: stills and drive lines on
  studies/kit_piece_yard.tscn; copy tools/harness/examples/kit_piece_drive.gd.
- `python tools/kit_piece.py check <id> [--shots]`: palette, editor
  place/turn/save/reload, tests/test_ruin_kit.gd, the three smokes.

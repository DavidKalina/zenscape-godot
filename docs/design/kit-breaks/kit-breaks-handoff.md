# Kit breaks: handoff

Spec: `spec-kit-breaks.md`. The loop's trail: `git log --grep='^ITER(kit-breaks)'`.

## The break contract

Breaking belongs to the hub (`scripts/kit_isle/breakables.gd`) and the
kit breakable (`scripts/kit_isle/kit_breaks.gd` on `break_pieces.gd`):
source toggles, `hit()`, the fall, the 24-body cap, rubble and the
enemies' re-plan. A kit makes its pieces breakable in one of three ways,
cheapest first.

1. **Tag a kind.** Set meta `break_kind` on the piece's root node to a
   kind in `break_kinds.gd` `SHAPES` (`pier`, `lintel`, `arch`, `wall`,
   `slab`, `post`...). A RuinKit piece needs no tag: `KIND_OF` names its
   kind from its id, so a new RuinKit piece gets a line there. Optional
   meta `toughness` (default the kind's; a breaker's strength must reach
   it). A built-in kind cuts along the stone's joints by rebuilding the
   piece with `RuinKit Build.keep_only`, so it needs the piece's
   `kit_piece` recipe or a `rebuild` Callable (`kit_breaks.gd add`).
2. **Register a cut.** For a new shape only (a bell, a hanging bridge, a
   statue): `Kinds.register("<kind>", cut)` once, then tag pieces with that
   kind. `cut` is `Callable(t) -> {stands, parts}`: `stands` a Node3D left
   in the piece's place (or null), `parts` the falling pieces, each
   `{mesh, shape, at, kg, kind, size}` in the piece's frame, `kind` one of
   the fall's: `slab`, `drum`, `column`, `chunk`. Meshes may be anything;
   only RuinKit stone merges into the rubble mesh.
3. **Answer the hub.** For a set piece with its own choreography, as the
   city kit does (`scripts/city_breaks/stone_break.gd`): join the group
   `breakable` (`Breakables.BREAKABLE`) and implement
   `take_hit(hub, at, radius, strength, source) -> bool`. The hub has already applied the source toggle.

The worked example of 2 is the bell that proved the contract (commit
11e92260; its driver was a scratch file, so the recipe is kept here): a bell on a yoke of primitive meshes, tagged
`break_kind "bell"`, `toughness 0.8`. Its cut keeps the two posts as
`stands` and drops the beam as a `slab` and the bell as a `drum`:

```gdscript
Kinds.register("bell", func(_t: Dictionary) -> Dictionary:
	return {"stands": posts, "parts": [
		{"mesh": beam_mi, "shape": beam.create_convex_shape(), "at": Vector3(0,3.55,0),
			"kg": 500.0, "kind": "slab", "size": Vector3(3.4,0.35,0.45)},
		{"mesh": bell_mi, "shape": bell.create_convex_shape(), "at": Vector3(0,2.6,0),
			"kg": 900.0, "kind": "drum", "size": Vector3(1.7,1.3,1.7)}]})
kit_breaks.adopt(bell)                 # finds it by its tag
hub.hit(at, 1.5, -1.0, &"olmec")       # breaks; &"plane" (off) leaves it
```

A place adopts its pieces with `kit_breaks.adopt(root)` (the motif yard
does it for every isle). Nothing about a piece's build changes until it is
hit.

## Toggles

- Sources: `olmec` on; `plane`, `dragon`, `slam` off (`--breakers=+slam`,
  `hub.set_breaker`).
- Per piece and per motif: meta `breakable` false on a node keeps it and
  everything under it out of `adopt`. The motif editor writes it: select a
  piece and press B (the piece's `"breakable": false`), or the panel's
  Breakable button (the motif's `"breakable": false`). Absent means
  breakable, so saved motifs build as before.

## Checks

`hit(at, radius, strength, source)` in `tools/harness/drive.gd` hits
through every hub in the scene and returns how many things broke; step
frames after it for the parts to settle.

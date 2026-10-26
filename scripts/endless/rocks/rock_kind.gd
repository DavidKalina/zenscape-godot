extends RefCounted
## The contract of a rock-shape kind (scripts/endless/rocks/rock_plan.gd
## KINDS). A kind is a script of static functions extending this one; it
## plans and shapes, and the shared system does the rest: the off-thread
## build (rock_build.gd: mesh with levels of detail, collider, the flight's
## solid), the streaming, the handles and every flight query (land_rocks.gd).
##
## `plan_cell(field, cx, cz, density, rng) -> Array` the cell's groups, a pure
##     function of the field's seed, the cell and `rng` (seeded from both).
##     `density` is the layer's value (1 the stock). Each group is a spec:
##       pos       Vector3 world, its anchor (the handle's place)
##       reach     m round pos that holds every pillar (under RockPlan.CELL)
##       pillars   [pillar...] (below), local to pos
##       foot      the trees' keep-outs, tree_plan.gd's arch boxes
##                 [centre XZ, cos, sin, half x, half z] ([] for none)
##       approach  {at: Vector2, heading: deg clockwise from -z, alt: m over
##                 the ground or sea}: where --rock-start=<kind> starts
##       by_arches false to skip the keep-off from arches (the sea's kinds)
##       bare      true: no turf on its tops (the ground material with every
##                 face rock)
##     plus anything of its own.
## A pillar: a stack of rings lofted round a vertical line, from its
##     buried foot up to a capped top:
##       at        Vector3 local base (the ground under it)
##       profile   [[y, rx, rz, ox, oz], ...] control rings, y up from `at`
##                 (the first under 0: buried), rx/rz the section's radii,
##                 ox/oz its centre's offset (a lean); rock_build.gd rings
##                 it evenly every `ring_every` m between them
##       yaw       the section's turn (rad)
##       dome      how far the top's middle stands over its last ring (m;
##                 negative dishes it)
##       square    the section's squareness (1 round, under 1 squarer)
##       lumps, grain, ledges, flutes   the weathering's push (shares of
##                 the radius): rock lumps about `lump` m, a finer grain,
##                 beds `bed` m tall standing out and in, joints and rills
##                 drawn out up the height
##       seed
##   rock_build.gd SEGMENTS and the kind's `ring_every` set its detail.

static func plan_cell(_field: RefCounted, _cx: int, _cz: int, _density: float, _rng: RandomNumberGenerator) -> Array:
	return []

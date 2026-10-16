extends RefCounted
## Break kinds: the public contract by which any kit's pieces break (spec:
## docs/design/kit-breaks/spec-kit-breaks.md). A kind owns how a piece of
## it splits; the fall, the body cap, the rubble and the re-plan are the
## breakable's (scripts/kit_isle/kit_breaks.gd on scripts/kit_isle/
## break_pieces.gd), never a kit's.
##
## A kit makes its pieces breakable by one of:
##   - tagging them with a kind: meta "break_kind" on the piece node (a
##     RuinKit piece needs none: KIND_OF names its kind from its id);
##   - registering a cut for a genuinely new shape: `register(kind, cut)`,
##     `cut` a Callable(t: Dictionary) -> {stands: Node3D or null, parts:
##     [part]}; every piece tagged with that kind then breaks by it;
##   - answering the hub itself (scripts/kit_isle/breakables.gd), with its
##     own choreography (the city kit's set pieces).
##
## A cut's result may say "topple": true (its parts' ids "<along>_<up>":
## each stack of one `along` goes over as one body, bursting into its parts
## where it lands); else every part falls on its own.
##
## `t` (a target, kit_breaks.gd `add`): node (the piece, still whole),
## box (its stone's bounds, its frame), at (the hit, its frame), dir (the
## way the hit goes, its frame), seed, rebuild (a Callable() -> Node3D that
## builds the piece again honouring RuinKit `Build.keep_only`, or invalid),
## keep (optional: a Callable(block middle, its frame) -> bool, the blocks
## left of it by earlier cuts; a built-in cut builds only those). A built-in
## cut's result has "keep" too: its stands' kept set, so what stands of a
## broken piece breaks again as what is left.
## A part: masonry_cuts.gd `_part`'s {mesh, shape, at, kg, kind, size}, in
## the piece's frame; `kind` one of the fall's: "slab" (laid flat), "drum"
## or "column" (laid on its side), "chunk". A registered cut's parts and
## stands may be any meshes (a primitive with its own material): only RuinKit
## stone merges into the rubble's one mesh; the rest lies there as itself.
##
## The built-in kinds cut along the stone's own joints: the piece built
## again once per part, each time keeping only the blocks whose middles
## fall in it (`by_joints`), so it breaks between stones, never through
## one. A kind's shape is a few numbers (SHAPES): how high its stump stands
## (a share of the hit's height; < 0 none stands), how far each way of the
## hit the break reaches along its length (m; 0 the whole piece), the
## chunks' size (m along, m up), the fall's kind, and its toughness (the
## least hit strength that breaks it: 1 the Olmec's).
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Cuts = preload("res://scripts/kit_isle/masonry_cuts.gd")
const Build = RuinKit.Build

## At most this many parts a break (each part a build of the piece).
const MOST_PARTS := 6

## kind: {stump (share of the hit's height; < 0 none), reach (m each way
## along; 0 all), chunk (Vector2: m along, m up), fall, tough, topple (the
## parts one over the other go over as one body about their foot, like the
## colonnade's column, and burst into their parts where they hit)}.
const SHAPES := {
	"pier":{"stump":0.6,"reach":0.0,"chunk":Vector2(9.0,1.6),"fall":"chunk","tough":0.5,"topple":true},
	"post":{"stump":0.5,"reach":0.0,"chunk":Vector2(9.0,2.4),"fall":"chunk","tough":0.4,"topple":true},
	"wall":{"stump":0.5,"reach":3.0,"chunk":Vector2(2.4,2.2),"fall":"slab","tough":0.6,"topple":true},
	"arch":{"stump":0.45,"reach":3.5,"chunk":Vector2(2.6,2.6),"fall":"chunk","tough":0.6,"topple":true},
	"lintel":{"stump":-1.0,"reach":0.0,"chunk":Vector2(2.2,9.0),"fall":"slab","tough":0.4},
	"stair":{"stump":0.5,"reach":2.5,"chunk":Vector2(2.0,1.5),"fall":"chunk","tough":0.9},
	"slab":{"stump":-1.0,"reach":2.0,"chunk":Vector2(1.6,9.0),"fall":"slab","tough":1.6},
}

## A RuinKit piece's kind, by its id (RuinKit ALL_PIECES).
const KIND_OF := {
	"pier":"pier","buttress":"pier","turret":"pier","hall_column":"pier","aqueduct_stump":"pier",
	"wind_horn":"post",
	"lancet_wall":"wall","wall":"wall","rose_gable":"wall","hall_bay":"wall","tower_shell":"wall",
	"arch":"arch","vault":"arch","aqueduct_span":"arch","aqueduct_two_tier":"arch",
	"aqueduct_broken":"arch","aqueduct_end":"arch",
	"hall_beam":"lintel",
	"stairs":"stair","grand_stair":"stair",
	"floor":"slab","hall_slab":"slab","tomb_chest":"slab","fallen_pier":"slab","stone_circle":"slab",
}

static var _cuts := {}

## A cut for `kind` (a new shape), or one of the built-ins replaced.
static func register(kind: String, cut: Callable) -> void:
	_cuts[kind] = cut

static func has(kind: String) -> bool:
	return _cuts.has(kind) or SHAPES.has(kind)

## A piece node's kind: its "break_kind" meta, else its RuinKit id's, else "".
static func kind_of(node: Node) -> String:
	if node.has_meta("break_kind"): return str(node.get_meta("break_kind"))
	if node.has_meta("kit_piece"): return str(KIND_OF.get(str((node.get_meta("kit_piece") as Array)[0]),""))
	return ""

## The least strength that breaks a piece: its "toughness" meta, else its kind's.
static func toughness(node: Node, kind: String) -> float:
	if node.has_meta("toughness"): return float(node.get_meta("toughness"))
	return float((SHAPES.get(kind,{}) as Dictionary).get("tough",1.0))

## Target `t` cut as its kind: {stands, parts} ({} if it can't be).
static func cut(kind: String, t: Dictionary) -> Dictionary:
	var j := job(kind,t)
	while not step(j): pass
	return result(j)

## A cut done a build at a time (`step` each frame), so a big piece's cut
## spreads over frames before the hit instead of one long frame at it. {}
## if `kind` can't cut `t`.
static func job(kind: String, t: Dictionary) -> Dictionary:
	if _cuts.has(kind): return {"t":t,"call":_cuts[kind],"todo":["all"],"i":0,"out":{}}
	if not SHAPES.has(kind) or not (t.get("rebuild",Callable()) as Callable).is_valid(): return {}
	var shape: Dictionary = SHAPES[kind]
	var frame := frame_of(t,shape)
	var todo: Array = [""]
	for a in range(int(frame.along)):
		for u in range(int(frame.up)): todo.append("%d_%d" % [a,u])
	return {"t":t,"shape":shape,"frame":frame,"todo":todo,"i":0,
		"out":{"stands":null,"parts":[],"topple":bool(shape.get("topple",false))}}

## One build of `j` done; true when it's all done (or `j` is {}).
static func step(j: Dictionary) -> bool:
	if j.is_empty(): return true
	if int(j.i) >= (j.todo as Array).size(): return true
	var want: String = j.todo[j.i]
	j.i = int(j.i)+1
	if j.has("call"):
		j.out = (j.call as Callable).call(j.t)
		return true
	var t: Dictionary = j.t
	var shape: Dictionary = j.shape
	var frame: Dictionary = j.frame
	var kept: Callable = t.get("keep",Callable())
	Build.keep_only = func(c: Vector3) -> bool: return (not kept.is_valid() or bool(kept.call(c))) and part_of(c,t,shape,frame) == want
	var was := Build.detail
	if want != "": Build.detail = 0.0
	var built: Node3D = (t.rebuild as Callable).call()
	Build.keep_only = Callable()
	Build.detail = was
	if want == "":
		if built != null:
			built.name = "Stands"
			# Nothing of it stands: none left to keep.
			var mi := built.get_node_or_null("Mesh") as MeshInstance3D
			if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
				built.free()
				built = null
		j.out.stands = built
		# What stands keeps: what the piece kept before and this cut's
		# stump, so a later cut of it builds only what is left.
		var seed_only := {"seed":t.seed}
		j.out.keep = func(c: Vector3) -> bool: return (not kept.is_valid() or bool(kept.call(c))) and part_of(c,seed_only,shape,frame) == ""
	elif built != null:
		var part := Cuts._part(built,str(shape.fall))
		built.free()
		if not part.is_empty():
			part.id = want
			(j.out.parts as Array).append(part)
	return int(j.i) >= (j.todo as Array).size()

## Whether job `j` makes the cut a hit at `at` (the piece's frame) would:
## the stump's height and, for a kind that breaks only near the hit, the
## point along its length within `tol` (m). A registered cut: `at` within `tol`.
static func serves(j: Dictionary, at: Vector3, tol: float) -> bool:
	if j.is_empty(): return false
	var was: Vector3 = j.t.at
	if not j.has("frame"): return was.distance_to(at) <= tol
	var shape: Dictionary = j.shape
	var box: AABB = j.t.box
	var dy := absf(clampf(at.y-box.position.y,0.0,box.size.y)-clampf(was.y-box.position.y,0.0,box.size.y))
	if float(shape.stump) >= 0.0 and dy*float(shape.stump) > 0.4: return false
	if float(shape.reach) > 0.0 and absf(at[int(j.frame.long)]-was[int(j.frame.long)]) > tol: return false
	return true

static func done(j: Dictionary) -> bool:
	return j.is_empty() or int(j.i) >= (j.todo as Array).size()

## A finished job's {stands, parts[, topple]} ({} for an empty job).
static func result(j: Dictionary) -> Dictionary:
	return {} if j.is_empty() else j.out

## A job's builds not yet made, freed (a pre-cut never used).
static func drop(j: Dictionary) -> void:
	if j.is_empty(): return
	var st: Variant = (j.out as Dictionary).get("stands")
	if st is Node3D and is_instance_valid(st) and not (st as Node3D).is_inside_tree(): (st as Node3D).free()

# --- The built-in kinds: along the joints -----------------------------------------------------

## The part a block whose middle is `c` (the piece's frame) falls in for a
## kind of `shape` hit at `at`: "" stands, else "<along>_<up>".
static func part_of(c: Vector3, t: Dictionary, shape: Dictionary, frame: Dictionary) -> String:
	var seed_value := int(t.seed)
	var stump: float = frame.stump
	var line := stump+0.35*sin(c.x*1.7+seed_value)+0.25*sin(c.z*2.3+seed_value)
	if c.y < line: return ""
	var long: int = frame.long
	var d := c[long]-float(frame.from)
	var span: float = frame.span
	if d < 0.0 or d > span: return ""
	var chunk: Vector2 = frame.chunk
	var i := clampi(int(floor((d+0.3*sin(c.y*1.3+seed_value))/chunk.x)),0,int(frame.along)-1)
	var j := clampi(int(floor((c.y-maxf(stump,float(frame.floor)))/chunk.y)),0,int(frame.up)-1)
	return "%d_%d" % [i,j]

## How a kind of `shape` splits target `t` hit at `t.at`: the stump line,
## the long axis, the span the break reaches and its parts' grid (at most
## MOST_PARTS: the chunks grow to fit).
static func frame_of(t: Dictionary, shape: Dictionary) -> Dictionary:
	var box: AABB = t.box
	var at: Vector3 = t.at
	var long := 0 if box.size.x >= box.size.z else 2
	var h := clampf(at.y-box.position.y,0.0,box.size.y)
	var stump := box.position.y+h*float(shape.stump) if float(shape.stump) >= 0.0 else -INF
	var reach := float(shape.reach)
	var from := box.position[long]
	var span := box.size[long]
	if reach > 0.0:
		from = maxf(box.position[long],at[long]-reach)
		span = minf(box.end[long],at[long]+reach)-from
	var floor_y := box.position.y if stump == -INF else stump
	var tall := box.end.y-floor_y
	var chunk: Vector2 = shape.chunk
	var along := maxi(1,ceili(span/chunk.x))
	var up := maxi(1,ceili(tall/chunk.y))
	while along*up > MOST_PARTS:
		if along >= up: along -= 1
		else: up -= 1
	return {"stump":stump,"long":long,"from":from,"span":span,"floor":floor_y,
		"chunk":Vector2(span/along+0.001,tall/up+0.001),"along":along,"up":up}

## A kind of `shape` cut along the joints at once: the piece built once as
## what stands and once per part.
static func by_joints(t: Dictionary, shape: Dictionary) -> Dictionary:
	var j := {"t":t,"shape":shape,"frame":frame_of(t,shape),"todo":[""],"i":0,
		"out":{"stands":null,"parts":[],"topple":bool(shape.get("topple",false))}}
	for a in range(int(j.frame.along)):
		for u in range(int(j.frame.up)): (j.todo as Array).append("%d_%d" % [a,u])
	while not step(j): pass
	return j.out

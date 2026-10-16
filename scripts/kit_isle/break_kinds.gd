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
## builds the piece again honouring RuinKit `Build.keep_only`, or invalid).
## A part: masonry_cuts.gd `_part`'s {mesh, shape, at, kg, kind, size}, in
## the piece's frame; `kind` one of the fall's: "slab" (laid flat), "drum"
## or "column" (laid on its side), "chunk".
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
	if _cuts.has(kind): return (_cuts[kind] as Callable).call(t)
	if not SHAPES.has(kind) or not (t.get("rebuild",Callable()) as Callable).is_valid(): return {}
	return by_joints(t,SHAPES[kind])

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

## A kind of `shape` cut along the joints: the piece built once as what
## stands and once per part (at most MOST_PARTS: the chunks grow to fit).
static func by_joints(t: Dictionary, shape: Dictionary) -> Dictionary:
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
	var frame := {"stump":stump,"long":long,"from":from,"span":span,"floor":floor_y,
		"chunk":Vector2(span/along+0.001,tall/up+0.001),"along":along,"up":up}
	var rebuild: Callable = t.rebuild
	var keep := func(want: String) -> Callable:
		return func(c: Vector3) -> bool: return part_of(c,t,shape,frame) == want
	Build.keep_only = keep.call("")
	var stands: Node3D = rebuild.call()
	var was := Build.detail
	Build.detail = 0.0
	var parts: Array = []
	for i in range(along):
		for j in range(up):
			var id := "%d_%d" % [i,j]
			Build.keep_only = keep.call(id)
			var built: Node3D = rebuild.call()
			if built == null: continue
			var part := Cuts._part(built,str(shape.fall))
			built.free()
			if not part.is_empty():
				part.id = id
				parts.append(part)
	Build.keep_only = Callable()
	Build.detail = was
	if stands != null:
		stands.name = "Stands"
		# Nothing of it stands: none left to keep.
		var mi := stands.get_node_or_null("Mesh") as MeshInstance3D
		if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
			stands.free()
			stands = null
	return {"stands":stands,"parts":parts,"topple":bool(shape.get("topple",false))}

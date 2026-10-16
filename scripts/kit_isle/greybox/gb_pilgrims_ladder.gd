extends "res://scripts/kit_isle/motif_greybox.gd"
## The Pilgrim's Ladder (card m1, docs/design/motifs/brainstorm/round3-new-
## kit-isles/motif-m1-pilgrims-ladder.md; plan docs/design/motifs/plans/
## pilgrims-ladder/plan.md, the spec): four sky isles stepped up and east,
## one new piece at each station. Threshold (0) holds the landing strip and
## the torana's jamb on its east lip; the Halo (7) the nimbus; the Crown
## (20) the pent hood on its north rim and, off its south lip, the keel-hung
## stair's plinth down to the Cellar (10), tucked under the Crown's south
## half. Played alone: studies/motif_yard.tscn -- --motif=pilgrims_ladder.
##
## Built on the real terrain from the start: each isle a KitLand island
## (turf, hanging rock, a keel), its flora and life. The layout is the one
## table LAYOUT below; the occupancy is computed from it (`_solids`).
## Plan frame: x east, z south (+Z), y up.

const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const Torana = preload("res://scripts/ruin_kit_torana.gd")

const TURF_SEED := 5300
## How far a keel's spurs can hang under top-depth (KitLand ring_sides),
## for the occupancy (as gb_sunken_giant's).
const KEEL_REACH := 1.4

## The layout (the plan's Layout, its numbers): each isle an ellipse at
## `at` (x, z) with radii `r`, flat turf at `top`, its keel `depth` under it,
## `wobble` its outline's ripple (share of the radius). `strip` the landing
## band kept clear (x, z: the plan's strip x -38..-8, z -5..5, and its clear
## band x -45..-3, z -8..8). `paths` the worn ways (flora thins on them).
const LAYOUT := {
	"isles":[
		{"name":"Threshold","at":Vector2(-10.0,0.0),"r":Vector2(40.0,22.0),"top":0.0,"depth":14.0,"wobble":0.06,"seed":0},
		{"name":"Halo","at":Vector2(62.0,0.0),"r":Vector2(12.0,12.0),"top":7.0,"depth":12.0,"wobble":0.08,"seed":1},
		{"name":"Crown","at":Vector2(91.0,0.0),"r":Vector2(16.0,14.0),"top":20.0,"depth":8.0,"wobble":0.07,"seed":2},
		{"name":"Cellar","at":Vector2(84.0,11.0),"r":Vector2(8.0,8.0),"top":10.0,"depth":7.0,"wobble":0.08,"seed":3},
	],
	## The stations' pieces: id, seed, weathered, `at` (its foot, world),
	## `rot` (deg about Y), `box` its bounds (piece frame, the occupancy). The torana's jamb stands on Threshold's east
	## lip with its lintel out east toward the Halo; rope 1 (x +3.2 off the
	## jamb, z +1.58) hangs over turf (the lip is at about x 30), the
	## snapped end (x +21.2) about 4 m short of the Halo's west lip, its
	## top 10.5 over the Halo's 7. `dry` the dry rope's index (rope 3).
	"pieces":[
		{"id":"relic_torana","seed":5320,"weathered":0.5,"at":Vector3(25.0,0.0,0.0),"rot":0.0,"ropes":4,"dry":2,
			"box":AABB(Vector3(-3.2,-0.2,-2.4),Vector3(24.4,11.8,4.8))},
		## The nimbus on the Halo, its ring in XY (the plane threads it along
		## Z), set 3 m north of the isle's centre line so the torana's hop
		## lands at about (52..56, 7, 0) in front (+Z) of the ring's lower
		## outer face (x 55.7 at head height), where its trough is stepped
		## into. Box: its mesh AABB.
		{"id":"relic_nimbus","seed":5330,"weathered":0.5,"at":Vector3(62.0,7.0,-3.0),"rot":0.0,
			"box":AABB(Vector3(-10.4,0.0,-2.2),Vector3(19.8,17.3,8.3))},
	],
	## Bands kept clear of tall flora round the pieces' feet (x, z).
	"clear":[Rect2(20.0,-4.0,11.0,8.0),Rect2(52.0,-6.0,20.0,10.0)],
	"strip":Rect2(-38.0,-5.0,30.0,10.0),
	"strip_clear":Rect2(-45.0,-8.0,42.0,16.0),
	"paths":[
		[Vector2(-8.0,0.0),Vector2(10.0,1.5),Vector2(26.0,0.0)],
		[Vector2(52.0,1.0),Vector2(60.0,2.0)],
		[Vector2(77.0,2.0),Vector2(86.0,-4.0),Vector2(94.0,-8.5)],
		[Vector2(86.0,4.0),Vector2(86.0,12.0)],
		[Vector2(79.0,12.0),Vector2(84.0,15.0)],
	],
}

func slug() -> String:
	return "pilgrims_ladder"

## The landmark of its neighbourhood.
func role() -> String:
	return "hero"

func isle_name() -> String:
	return "The Pilgrim's Ladder"

func epithet() -> String:
	return "Four stations up into the wind."

func brief() -> String:
	return "Ride the gate's ropes, climb the broken halo to its horns, sail to the Crown.\nKeep under the hood from the bird; slam the hung stair and run it down to the cellar."

## On the strip's east end, facing the torana (the plane parks behind).
func start() -> Vector3:
	return Vector3(-6.0,0.0,0.0)

## Threshold carries a 30 m strip on flat turf.
func landing_run() -> bool:
	return true

## In off Threshold's west lip (the strip's approach), out off its south
## side, where you come home.
func rims() -> Array:
	return [
		{"name":"threshold_west","at":Vector3(-48.0,0.0,0.0),"face":Vector3(-1.0,0.0,0.0),"run_up":30.0,"lip":1.5},
		{"name":"threshold_south","at":Vector3(4.0,0.0,19.0),"face":Vector3(0.0,0.0,1.0),"run_up":12.0,"lip":1.5},
	]

func spots() -> Array:
	return [
		{"kind":"arena","name":"threshold_lawn","at":Vector3(10.0,0.0,0.0),"room":8.0},
		{"kind":"perch","name":"halo","at":Vector3(56.0,7.0,6.0),"room":3.0},
		{"kind":"perch","name":"crown","at":Vector3(91.0,20.0,2.0),"room":5.0},
		{"kind":"perch","name":"cellar","at":Vector3(80.0,10.0,13.0),"room":3.0},
	]

# --- The land ----------------------------------------------------------------------------

static func isle(name: String) -> Dictionary:
	for i: Dictionary in LAYOUT.isles:
		if i.name == name: return i
	return {}

## An isle's outline: its ellipse, rippled by two low waves (seeded by its
## index), 64 points.
static func outline_of(i: Dictionary) -> Array:
	var out: Array = []
	var c: Vector2 = i.at
	var r: Vector2 = i.r
	var w := float(i.wobble)
	var s := float(i.seed)*1.7
	for k in 64:
		var a := TAU*k/64.0
		var ripple := 1.0+w*(0.6*sin(3.0*a+s)+0.4*sin(5.0*a+s*2.3))
		out.append(c+Vector2(cos(a)*r.x,sin(a)*r.y)*ripple)
	return out

## The worn ways, plus the strip lightly worn so nothing tall grows on it.
static func wear(p: Vector2) -> float:
	var w: float = KitLand.wear_of(LAYOUT.paths).call(p)
	if (LAYOUT.strip_clear as Rect2).has_point(p): w = maxf(w,0.12)
	for r: Rect2 in LAYOUT.clear:
		if r.has_point(p): w = maxf(w,0.12)
	return w

## Turf tone wear: the paths only (the strip stays green, read as a lawn).
static func tone_wear(p: Vector2) -> float:
	return KitLand.wear_of(LAYOUT.paths).call(p)

func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(top(),func(p: Vector2) -> float: return wear(p))
	site.ray = Vector2(20.0+60.0,-8.0)
	return site

func flora_seed() -> int:
	return TURF_SEED+9

func life_script() -> Script:
	return KitLife

func summit() -> Vector3:
	return Vector3(91.0,20.0,0.0)

func warm() -> void:
	super.warm()
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	RuinKit.materials()

## Each isle's box from its keel's reach to its top.
func _solids() -> Array:
	var out: Array = []
	for i: Dictionary in LAYOUT.isles:
		var ring := outline_of(i)
		var box := Rect2(ring[0],Vector2.ZERO)
		for p: Vector2 in ring: box = box.expand(p)
		out.append([box.grow(-1.0),float(i.top)-float(i.depth)*KEEL_REACH,float(i.top),null])
	for p: Dictionary in LAYOUT.pieces:
		var b: AABB = pose(p)*(p.box as AABB)
		out.append([Rect2(b.position.x,b.position.z,b.size.x,b.size.z),b.position.y,b.end.y,null])
	return out

## A guess until measured headless.
func build_cost() -> int:
	return 700

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "PilgrimsLadder"
	into.add_child(root)
	var tone := KitLook.turf(TURF_SEED,func(p: Vector2) -> float: return tone_wear(p))
	for i: Dictionary in LAYOUT.isles:
		var y := float(i.top)
		var land := KitLand.island({"outline":outline_of(i),"seed":TURF_SEED+int(i.seed),
			"ground":func(_x: float, _z: float) -> float: return y,
			"top":y,"depth":float(i.depth),"hang":true,"resample":[60.0,200,64],"tone":tone})
		land.name = str(i.name)
		_collide_sides(land)
		root.add_child(land)
		turf(land)
	_pieces(root)
	built_ms = Time.get_ticks_msec()-began

## The stations' pieces (LAYOUT.pieces), each at its foot and turn.
func _pieces(root: Node3D) -> void:
	for p: Dictionary in LAYOUT.pieces:
		var node := piece_of(p)
		if node == null: continue
		node.name = str(p.id)
		node.transform = pose(p)
		_specs["%s/%d" % [str(p.id),int(p.seed)]] = node.get_meta("ropes",[])
		root.add_child(node)

## A piece of LAYOUT.pieces built (the torana with its rope count and dry
## rope; the others by RuinKit.piece).
static func piece_of(p: Dictionary) -> Node3D:
	if p.id == "relic_torana":
		return Torana.torana(int(p.seed),float(p.weathered),int(p.get("ropes",4)),Torana.TILT,int(p.get("dry",-1)))
	return RuinKit.piece(str(p.id),int(p.seed),float(p.weathered))

static func pose(p: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,deg_to_rad(float(p.rot))),p.at)

## The torana's prayer ropes, hung live where it stands (its "ropes" meta
## through the host's `rope`; the dry one dried, a tag beside each).
func live(g: Node) -> void:
	var Authored: Script = load("res://scripts/kit_isle/motif_authored.gd")
	for p: Dictionary in LAYOUT.pieces:
		var specs := _rope_specs(p)
		if specs.is_empty(): continue
		var frame := pose(p)
		frame.origin = g.w(frame.origin)
		Authored.hang_ropes(specs,frame,Callable(g,"rope"))

## A piece's "ropes" meta (built once per id and kept).
static var _specs := {}
static func _rope_specs(p: Dictionary) -> Array:
	var key := "%s/%d" % [str(p.id),int(p.seed)]
	if not _specs.has(key):
		var node := piece_of(p)
		_specs[key] = node.get_meta("ropes",[]) if node != null else []
		if node != null: node.free()
	return _specs[key]

## An island's hanging sides collided as drawn (as gb_sunken_giant's): a
## fall past a flank meets it.
static func _collide_sides(land: Node3D) -> void:
	var sides := land.get_node_or_null("Mesh") as MeshInstance3D
	if sides == null or sides.mesh == null: return
	var body := StaticBody3D.new()
	body.name = "Sides"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(sides.mesh.get_faces())
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	land.add_child(body)

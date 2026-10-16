extends "res://scripts/kit_isle/motif_authored.gd"
## An authored motif on a base (spec-editor-traps item 11): a coded kit
## motif of LayerPlan POOL (colonnade_spine, bell_spires, ...) stood as it
## is, read-only, with the user's traps, pieces and markers from the editor
## on it. The file: {"format", "slug", "name", "base": "<pool id>", "seed"
## (the base's seed; a family base is configured with it), "pieces",
## "markers", "traps"} (MotifAuthored's land keys are not written).
##
## The base answers the motif contract (footprint, height span, sockets,
## build, frame, flora, ...); this adds the pieces to its build and the
## traps to `live`. Its id is the base's (LayerPieces occupancy and the
## generator's per-id rules hold); LayerGreybox makes it live by `based_on`.
##
## The ground: a height field baked from the stood base's collision (`bake`,
## the editor's, main thread), so lips, seats and markers read the real
## land and ruins. Unbaked (the yard's build, maybe on a worker) every
## piece, trap and marker keeps the y the editor saved.
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")

## The height field's cell (m) and how far past the footprint it reaches.
const FIELD_CELL := 0.5
const FIELD_PAD := 4.0

var inner: RefCounted = null
## The node the base was built into (its collision: what `bake` reads).
var base_root: Node3D = null
var _field := {}

## The pool's ids a base may be.
static func bases() -> PackedStringArray:
	var out := PackedStringArray()
	for p: Array in LayerPlan.POOL: out.append(str(p[0]))
	return out

static func base_script(id_name: String) -> Script:
	for p: Array in LayerPlan.POOL:
		if str(p[0]) == id_name: return p[1]
	return null

## A based motif over `d` (the editor's).
static func over(d: Dictionary) -> RefCounted:
	var m: RefCounted = load("res://scripts/kit_isle/motif_based.gd").new()
	m.data = d
	return m

## A fresh based file for pool motif `id_name`: its default seed, the
## markers at its spawn and rims.
static func blank_on(slug_name: String, id_name: String) -> Dictionary:
	var d := {"format":FORMAT,"slug":slug_name,"name":slug_name.capitalize(),"base":id_name,"seed":-1,
		"pieces":[],"markers":{}}
	var m: RefCounted = over(d)
	var b: RefCounted = m.base()
	if b != null and b.family(): d.seed = int(b.default_seed())
	var rims: Array = (b.sockets() as Array).filter(func(s: Dictionary) -> bool: return s.kind == "rim") if b != null else []
	var at := func(v: Vector3) -> Array: return [snappedf(v.x,0.001),snappedf(v.y,0.001),snappedf(v.z,0.001)]
	var first: Vector3 = rims[0].at if not rims.is_empty() else Vector3.ZERO
	var face: Vector3 = rims[0].face if not rims.is_empty() else Vector3.BACK
	d.markers = {"spawn":at.call(first-face*2.0),"rim_in":at.call(first),
		"rim_out":at.call((rims[1].at if rims.size() > 1 else first) as Vector3)}
	return normalise(d)

## The base motif, configured with the file's seed.
func base() -> RefCounted:
	if inner == null:
		var s := base_script(str(data.get("base","")))
		if s == null:
			push_error("motif based: no pool motif '%s'" % data.get("base",""))
			return null
		inner = s.new()
		if inner.family() and int(data.get("seed",-1)) > 0: inner.configure(int(data.seed))
		knobs = inner.knobs
	return inner

func based_on() -> String:
	return str(data.get("base",""))

# --- The ground: the baked height field ------------------------------------------------

## The base's top under every cell of its footprint (rays down through its
## collision, anything not under `base_root` passed through), in `space`.
func bake(space: PhysicsDirectSpaceState3D) -> void:
	_field = {}
	if base_root == null or space == null or base() == null: return
	var r: Rect2 = inner.footprint().grow(FIELD_PAD)
	var span: Vector2 = inner.height_span()
	var cols := int(ceil(r.size.x/FIELD_CELL))+1
	var rows := int(ceil(r.size.y/FIELD_CELL))+1
	var ys := PackedFloat32Array()
	ys.resize(cols*rows)
	var low := span.x-30.0
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = 0xFFFFFFFF
	q.hit_back_faces = false
	for row in range(rows):
		for col in range(cols):
			var x := r.position.x+col*FIELD_CELL
			var z := r.position.y+row*FIELD_CELL
			q.from = Vector3(x,span.y+8.0,z)
			q.to = Vector3(x,low,z)
			q.exclude = []
			var y := low
			for _t in range(6):
				var hit := space.intersect_ray(q)
				if hit.is_empty(): break
				var co: Object = hit.collider
				if co is Node and base_root.is_ancestor_of(co):
					y = float(hit.position.y)
					break
				var ex: Array[RID] = q.exclude
				ex.append(hit.rid)
				q.exclude = ex
			ys[row*cols+col] = y
	_field = {"origin":r.position,"cols":cols,"rows":rows,"ys":ys,"low":low}
	_ground = Callable()

func baked() -> bool:
	return not _field.is_empty()

func ground_fn() -> Callable:
	if not _ground.is_valid(): _ground = Callable(self,"_field_y")
	return _ground

## The field's height at (x, z): bilinear inside, the void outside.
func _field_y(x: float, z: float) -> float:
	if _field.is_empty(): return float(base().height_span().y) if base() != null else 0.0
	var o: Vector2 = _field.origin
	var fx := (x-o.x)/FIELD_CELL
	var fz := (z-o.y)/FIELD_CELL
	var cols: int = _field.cols
	var rows: int = _field.rows
	if fx < 0.0 or fz < 0.0 or fx > cols-1 or fz > rows-1: return float(_field.low)
	var c := mini(int(fx),cols-2)
	var r := mini(int(fz),rows-2)
	var tx := fx-c
	var tz := fz-r
	var ys: PackedFloat32Array = _field.ys
	var a := lerpf(ys[r*cols+c],ys[r*cols+c+1],tx)
	var b := lerpf(ys[(r+1)*cols+c],ys[(r+1)*cols+c+1],tx)
	return lerpf(a,b,tz)

func ground(x: float, z: float) -> float:
	return _field_y(x,z)

func outline() -> Array:
	var r: Rect2 = base().footprint().grow(2.0) if base() != null else Rect2(-10,-10,20,20)
	return [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]

## Unbaked, a piece keeps its saved y.
func _seat_y(p: Dictionary, x: float, z: float, turn: float) -> float:
	if not baked(): return float((p.at as Array)[1])
	return super._seat_y(p,x,z,turn)

func _marker(key: String) -> Vector3:
	var a: Array = (data.get("markers",{}) as Dictionary).get(key,[0.0,0.0,0.0])
	var y := ground(float(a[0]),float(a[2])) if baked() else float(a[1])
	return Vector3(float(a[0]),y,float(a[2]))

## A ground trap ("on" absent) unbaked keeps its saved y too.
func trap_of(t: Dictionary) -> Node3D:
	if baked() or t.has("on"): return super.trap_of(t)
	var u := t.duplicate()
	u.on = "lip"
	return super.trap_of(u)

# --- The editor's land questions ------------------------------------------------------

func sliders() -> Dictionary:
	var r: Rect2 = base().footprint() if base() != null else Rect2(0,0,40,40)
	return {"length":r.size.x,"width":r.size.y}

func crest_top() -> float:
	return float(base().top()) if base() != null else 10.0

func keel_top() -> float:
	return float(base().height_span().x) if base() != null else 0.0

func depth() -> float:
	return 0.0

func ponds() -> Array:
	return []

func build_water(_into: Node3D) -> void:
	pass

func ravine_box() -> Rect2:
	return Rect2()

func build_land(_fast := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Base_"+based_on()
	if base() == null: return root
	inner.build(root)
	lands = inner.lands
	base_root = root
	return root

# --- The motif contract: the base's ---------------------------------------------------

func id() -> String:
	return str(base().id()) if base() != null else "based"

func isle_name() -> String:
	return str(data.get("name",slug().capitalize()))

func isle_card() -> Dictionary:
	return base().isle_card()

func epithet() -> String:
	return "Built in the motif editor on %s." % based_on()

func role() -> String:
	return base().role()

func family() -> bool:
	return false

func top() -> float:
	return base().top()

func summit() -> Vector3:
	return base().summit()

func footprint() -> Rect2:
	return base().footprint()

func height_span() -> Vector2:
	return base().height_span()

## Asked only when the base has no occupancy of its own (LayerPieces).
func occupancy() -> Dictionary:
	if base().has_method("occupancy"): return base().occupancy()
	return LayerPlan._box_occ(footprint(),height_span())

func sockets() -> Array:
	return base().sockets()

func rims() -> Array:
	return (base().sockets() as Array).filter(func(s: Dictionary) -> bool: return s.kind == "rim")

func pools() -> Array:
	return base().pools()

func plane_tokens() -> Array:
	return base().plane_tokens()

func token_source() -> String:
	return base().token_source()

func flora_site() -> KitFlora.Site:
	return base().flora_site()

func flora_seed() -> int:
	return base().flora_seed()

func life_script() -> Script:
	return base().life_script()

func rest_decks() -> bool:
	return base().rest_decks()

func warm() -> void:
	base().warm()
	RuinKit.materials()
	for p: Dictionary in data.get("pieces",[]):
		if TREES.has(str(p.id)): _tree_parts(str(p.id))

func build_cost() -> int:
	return int(base().build_cost())+100

func frame(delta: float, host: Node) -> void:
	if inner != null: inner.frame(delta,host)

func landed(feet: Vector3) -> void:
	if inner != null: inner.landed(feet)

func plane_near(at: Vector3) -> void:
	if inner != null: inner.plane_near(at)

## The base built, then the pieces over it (a worker may run it).
func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	into.add_child(build_land())
	var holder := Node3D.new()
	holder.name = "Pieces"
	into.add_child(holder)
	build_pieces(holder)
	built_ms = Time.get_ticks_msec()-began

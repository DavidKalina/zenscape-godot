extends "res://scripts/kit_isle/kit_motif.gd"
## One of the aqueduct isle's islands alone, as a base the motif editor
## opens (docs/design/world-editor/spec-world-editor.md, the island view):
## `island/near`, `island/far`, `island/west_islet`, `island/east_islet`.
## Its land is the isle's own island type (studies/aqueduct_isle_art.gd
## `Art.island`, the same call, outline, seed and ground), and what stands
## on it is the isle's own build (studies/aqueduct_isle_base.gd): the whole
## art built, then only what stands over this island's outline kept. The
## links (the aqueduct, its channel, the stumps), the other islands and
## anything over the sky are dropped. So the island looks in the editor as
## it does in the game. It stands at its coded world spot (the motif's
## frame is the world's), read-only, as motif_based.gd stands a pool base.
##
## Collision: the land's own trimesh and the pieces' own bodies; the
## isle's analytic boxes (its station parts, the castellum's blocks) that
## stand over this island and under no dropped link, as clean boxes.
const Art = preload("res://studies/aqueduct_isle_art.gd")
const BaseArt = preload("res://studies/aqueduct_isle_base.gd")

const NAMES := ["island/near","island/far","island/west_islet","island/east_islet"]
## The isle's nodes that span islands (links) or are islands: never kept.
const LINKS := ["Aqueduct","Channel","Stumps"]
## How far over the turf what stands on it reaches (m), and the keel under.
const OVER := 25.0

var island := "island/near"
## Kept / dropped counts from the last build (for the editor's line).
var kept := 0
var dropped := 0

func _init(name_: String = "island/near") -> void:
	island = name_ if name_ in NAMES else "island/near"

static func is_island(id_name: String) -> bool:
	return id_name in NAMES

## The scene's script (its seeds), loaded as the base build loads it.
static func _isle() -> GDScript:
	return load("res://studies/aqueduct_isle.gd")

## The island's coded outline (x, z, world).
func outline() -> Array:
	match island:
		"island/far": return Art.FAR
		"island/west_islet": return Art.blob(Vector2(Art.WEST_ISLET.x,Art.WEST_ISLET.y),Art.WEST_ISLET.z,_isle().SEED+11)
		"island/east_islet": return Art.blob(Vector2(Art.EAST_ISLET.x,Art.EAST_ISLET.y),Art.EAST_ISLET.z,_isle().SEED+12)
	return Art.NEAR

func id() -> String:
	return "isle_"+island.get_slice("/",1)

func isle_name() -> String:
	return island.get_slice("/",1).capitalize()

func top() -> float:
	match island:
		"island/west_islet": return Art.WEST_TOP
		"island/east_islet": return Art.EAST_TOP
	return Art.TOP

func _rect() -> Rect2:
	var o := outline()
	var r := Rect2(o[0],Vector2.ZERO)
	for p: Vector2 in o: r = r.expand(p)
	return r

func footprint() -> Rect2:
	return _rect().grow(2.0)

func height_span() -> Vector2:
	var depth := {"island/near":30.0,"island/far":20.0}.get(island,7.0) as float
	return Vector2(top()-depth-2.0,top()+OVER)

func summit() -> Vector3:
	var c := _rect().get_center()
	return Vector3(c.x,top(),c.y)

## Where he starts on it: the isle's start on the near island, else its
## outline's middle (the editor seats it on the land once baked).
func own_start() -> Vector3:
	if island == "island/near": return Art.START
	return summit()

## The isle's own grass and flowers (studies/aqueduct_isle_flora.gd), its seed.
func flora_site() -> KitFlora.Site:
	return preload("res://studies/aqueduct_isle_flora.gd").site()

func flora_seed() -> int:
	return int(_isle().SEED)+4

func build_cost() -> int:
	return 1500

func warm() -> void:
	super.warm()
	KitLook.ground_material()

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var base: RefCounted = BaseArt.new()
	var whole := Node3D.new()
	base.build(whole)
	var land: Node3D = {"island/near":base.near,"island/far":base.far}.get(island,null)
	if land == null: land = base.islets[0 if island == "island/west_islet" else 1]
	var others: Array = [base.near,base.far]+base.islets
	var poly := PackedVector2Array(land.get_meta("outline",PackedVector2Array(outline())))
	var dropped_rects: Array = []
	kept = 0
	dropped = 0
	for c: Node in whole.get_children():
		if c == land: continue
		var b := _box(c as Node3D) if c is Node3D else AABB()
		var on := false
		if not c in others and not str(c.name) in LINKS and b.size != Vector3.ZERO:
			var mid := b.get_center()
			on = Geometry2D.is_point_in_polygon(Vector2(mid.x,mid.z),poly) and b.position.y > top()-30.0
		if on:
			c.owner = null
			whole.remove_child(c)
			into.add_child(c)
			kept += 1
		else:
			if b.size != Vector3.ZERO and str(c.name) in LINKS: dropped_rects.append(Rect2(b.position.x,b.position.z,b.size.x,b.size.z))
			dropped += 1
	whole.remove_child(land)
	into.add_child(land)
	lands = []
	turf(land,poly)
	# The isle's analytic collision standing on this island.
	for part: Array in Art.station_parts()+(base.parts as Array):
		if str(part[0]) != "box": continue
		var r: Rect2 = part[1]
		var mid := r.get_center()
		if not Geometry2D.is_point_in_polygon(mid,poly): continue
		var under_link := false
		for dr: Rect2 in dropped_rects:
			if dr.has_point(mid): under_link = true
		if under_link: continue
		solid_box(r,float(part[2]),float(part[3]))
	whole.free()
	built_ms = Time.get_ticks_msec()-began
	print("isle island %s: %d kept, %d dropped, built in %d ms" % [island,kept,dropped,built_ms])

## `n`'s drawn bounds in its parent's frame, built outside the tree (each
## visual's transform walked up to `n`'s parent); its collision if it draws
## nothing.
static func _box(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var vis: Array = n.find_children("*","VisualInstance3D",true,false)
	if n is VisualInstance3D: vis.append(n)
	for v: VisualInstance3D in vis:
		var b := _up_to(v,n)*v.get_aabb()
		if b.size == Vector3.ZERO: continue
		box = b if first else box.merge(b)
		first = false
	if not first: return box
	for s: CollisionShape3D in n.find_children("*","CollisionShape3D",true,false):
		if s.shape == null or s.shape.get_debug_mesh() == null: continue
		var b := _up_to(s,n)*s.shape.get_debug_mesh().get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

static func _up_to(v: Node3D, top_node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var at: Node = v
	while at != null and at is Node3D:
		xf = (at as Node3D).transform*xf
		if at == top_node: break
		at = at.get_parent()
	return xf

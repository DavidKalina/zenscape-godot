extends Sprite3D
## A kit cache's tell (scripts/kit_isle/kit_caches.gd; docs/design/
## kit-breaks/kit-caches-handoff.md): one small point on the piece's outer
## surface, like light caught on a gem lodged in a joint. Mostly a faint
## point; every EVERY s (seeded per piece, so caches don't keep time) it
## catches, a short star and a mote or two (shaders/kit_cache_glint.gdshader).
## `flare()` is a weak hit's: the same, brighter and bigger.
##
## The spot (`spot`): meta "holds_at" (a Vector3 in the piece's frame) if
## the piece has one; else a seeded point on one of the piece's own mesh
## faces, a side face (not top or underside) at BAND (the wanderer's hand to
## head, over the piece's foot) where it has one, with nothing of the piece
## in front of it. It sits PROUD m off the face, its +Z the face's normal.
##
## A Sprite3D, not a MeshInstance3D, so what measures a piece by its meshes
## (kit_breaks' box, the authored seat) doesn't see it.
const WorldScale = preload("res://scripts/world_scale.gd")
const SHADER = preload("res://shaders/kit_cache_glint.gdshader")

const NODE_NAME := "CacheGlint"
const AT_META := "holds_at"
## Seconds between catches (least, most).
const EVERY := Vector2(2.5, 7.0)
## A catch's rise and its fall (s).
const GLINT_IN := 0.05
const GLINT_OUT := 0.3
## A weak hit's flare fades over this (s).
const FLARE_TIME := 0.8
## How far off the face it sits (m).
const PROUD := 0.03
## The height band it prefers, times the wanderer's height, over the piece's foot.
const BAND := Vector2(0.45, 1.0)
## The quad it is drawn on (m across: the star, the flare and the motes fit).
const QUAD := 2.0
## Points tried for one in the open before settling for less.
const TRIES := 48
## A face this upright or more is a side (|normal.y| under it).
const SIDE := 0.4
## How far out of the spot the world must be clear (m), where it's asked.
const CLEAR := 2.5

var rng := RandomNumberGenerator.new()
var age := 99.0
var wait := 1.0
var flaring := 0.0
var spin := 0.0
static var _material: ShaderMaterial = null
static var _texture: ImageTexture = null

## The glint on `node` (its old one replaced) in `tint`. Returns it. With
## `clear_of` (`world_clear`'s), a spot whose way out the world blocks
## (the slope, a wall it stands against) is passed over while there's another.
static func place(node: Node3D, tint: Color, clear_of := Callable()) -> Node3D:
	clear(node)
	var g: Sprite3D = (load("res://scripts/kit_isle/kit_cache_glint.gd") as GDScript).new()
	g.name = NODE_NAME
	g.transform = spot(node,clear_of)
	g.set_instance_shader_parameter("tint",tint)
	g.rng.seed = seed_of(node)*31+hash(str(node.get_meta("holds_name",node.name)))
	g.wait = g.rng.randf_range(0.3,EVERY.y)
	node.add_child(g)
	return g

## `node`'s glint taken away.
static func clear(node: Node3D) -> void:
	var old := node.get_node_or_null(NODE_NAME)
	if old != null:
		node.remove_child(old)
		old.queue_free()

## `node`'s glint, or null.
static func of(node: Node3D) -> Node3D:
	return node.get_node_or_null(NODE_NAME) as Node3D

static func seed_of(node: Node3D) -> int:
	var recipe: Array = node.get_meta("kit_piece",[]) as Array
	return int(recipe[1]) if recipe.size() >= 2 else hash(str(node.name))

func _init() -> void:
	if _texture == null:
		var img := Image.create(1,1,false,Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_texture = ImageTexture.create_from_image(img)
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	texture = _texture
	pixel_size = QUAD
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 0.5

func _process(delta: float) -> void:
	age += delta
	wait -= delta
	if wait <= 0.0: _catch()
	var g := 0.0
	if age < GLINT_IN: g = age/GLINT_IN
	elif age < GLINT_IN+GLINT_OUT*3.0: g = exp(-(age-GLINT_IN)/GLINT_OUT*2.2)
	if flaring > 0.0: flaring = maxf(flaring-delta/FLARE_TIME,0.0)
	set_instance_shader_parameter("glint",g)
	set_instance_shader_parameter("age",age)
	set_instance_shader_parameter("flare",flaring*flaring)
	set_instance_shader_parameter("spin",spin)

func _catch() -> void:
	age = 0.0
	spin = rng.randf_range(-0.35,0.35)
	wait = rng.randf_range(EVERY.x,EVERY.y)

## A weak hit: the spot flares.
func flare() -> void:
	flaring = 1.0
	_catch()

## Where it sits in it now (world).
func at() -> Vector3:
	return global_position if is_inside_tree() else position

# --- The spot -------------------------------------------------------------------------------

## A `clear_of` for `place`: nothing in the world but `node` itself within
## CLEAR m out of a point (its frame) along its normal. Plain true out of
## the tree.
static func world_clear(node: Node3D) -> Callable:
	if not node.is_inside_tree(): return Callable()
	var ex: Array[RID] = []
	for b: Node in node.find_children("*","CollisionObject3D",true,false): ex.append((b as CollisionObject3D).get_rid())
	if node is CollisionObject3D: ex.append((node as CollisionObject3D).get_rid())
	var space := node.get_world_3d().direct_space_state
	return func(p: Vector3, n: Vector3) -> bool:
		var xf := node.global_transform
		var w := xf*p
		var wn := (xf.basis*n).normalized()
		var q := PhysicsRayQueryParameters3D.create(w+wn*0.02,w+wn*CLEAR)
		q.exclude = ex
		return space.intersect_ray(q).is_empty()

## Its place on `node`, in `node`'s frame: +Z out of the face.
static func spot(node: Node3D, clear_of := Callable()) -> Transform3D:
	var tris := _faces(node)
	if node.has_meta(AT_META):
		var want: Vector3 = node.get_meta(AT_META)
		return _seat(want,_nearest_normal(tris,want))
	if tris.is_empty(): return _seat(Vector3.UP*0.5,Vector3.BACK)
	var lo := INF
	for t: Array in tris: lo = minf(lo,minf((t[0] as Vector3).y,minf((t[1] as Vector3).y,(t[2] as Vector3).y)))
	var band := Vector2(lo,lo)+BAND*WorldScale.wanderer_tall
	var rng := RandomNumberGenerator.new()
	# Sides in the band; then sides at any height; then anything but
	# undersides. The world's say first; then without it.
	for k in range(6 if clear_of.is_valid() else 3):
		var pass_i := k%3
		var world := k < 3 and clear_of.is_valid()
		rng.seed = seed_of(node)+k
		var pool: Array = []
		var weights := PackedFloat32Array()
		var total := 0.0
		for t: Array in tris:
			var n: Vector3 = t[3]
			if pass_i < 2 and absf(n.y) >= SIDE: continue
			if pass_i == 2 and n.y < -SIDE: continue
			if pass_i == 0:
				var y0 := minf((t[0] as Vector3).y,minf((t[1] as Vector3).y,(t[2] as Vector3).y))
				var y1 := maxf((t[0] as Vector3).y,maxf((t[1] as Vector3).y,(t[2] as Vector3).y))
				if y1 < band.x or y0 > band.y: continue
			total += float(t[4])
			pool.append(t)
			weights.append(total)
		if pool.is_empty(): continue
		for i in range(TRIES):
			var pick := weights.bsearch(rng.randf()*total)
			var t: Array = pool[mini(pick,pool.size()-1)]
			var p := _inside(t,rng)
			if pass_i == 0 and (p.y < band.x or p.y > band.y): continue
			if not _open(tris,p,t[3] as Vector3,t): continue
			if world and not bool(clear_of.call(p,t[3] as Vector3)): continue
			return _seat(p,t[3] as Vector3)
	return _seat(Vector3.UP*0.5,Vector3.BACK)

static func _seat(p: Vector3, n: Vector3) -> Transform3D:
	var z := n.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.1: x = Vector3.RIGHT
	x = x.normalized()
	return Transform3D(Basis(x,z.cross(x),z),p+z*PROUD)

## A point well inside triangle `t` (not on its very edge).
static func _inside(t: Array, rng: RandomNumberGenerator) -> Vector3:
	var u := rng.randf()
	var v := rng.randf()
	if u+v > 1.0:
		u = 1.0-u
		v = 1.0-v
	var a: Vector3 = t[0]
	var p := a+((t[1] as Vector3)-a)*u+((t[2] as Vector3)-a)*v
	var mid := (a+(t[1] as Vector3)+(t[2] as Vector3))/3.0
	return mid.lerp(p,0.85)

## Nothing of the piece in front of `p` along `n` (another block, an overhang).
static func _open(tris: Array, p: Vector3, n: Vector3, own: Array) -> bool:
	var from := p+n*0.01
	var to := p+n*1.6
	for t: Array in tris:
		if t == own: continue
		if Geometry3D.segment_intersects_triangle(from,to,t[0],t[1],t[2]) != null: return false
	return true

static func _nearest_normal(tris: Array, p: Vector3) -> Vector3:
	var best := INF
	var out := Vector3.BACK
	for t: Array in tris:
		var c := ((t[0] as Vector3)+(t[1] as Vector3)+(t[2] as Vector3))/3.0
		var d := c.distance_squared_to(p)
		if d < best:
			best = d
			out = t[3]
	return out

## Every face of every mesh at or under `node` in `node`'s frame: [a, b, c,
## normal, area].
static func _faces(node: Node3D) -> Array:
	var out: Array = []
	var all: Array[Node] = [node]
	all.append_array(node.find_children("*","MeshInstance3D",true,false))
	for m: Node in all:
		if not m is MeshInstance3D: continue
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.visible: continue
		var xf := _local_of(node,mi)
		var f := mi.mesh.get_faces()
		for i in range(0,f.size()-2,3):
			var a := xf*f[i]
			var b := xf*f[i+1]
			var c := xf*f[i+2]
			var cr := (b-a).cross(c-a)
			var area := cr.length()*0.5
			if area < 1e-4: continue
			# get_faces winds clockwise seen from the front (Godot's front faces).
			var n := -cr.normalized()
			out.append([a,b,c,n,area])
	return out

static func _local_of(node: Node3D, under: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var up: Node = under
	while up != node and up is Node3D:
		xf = (up as Node3D).transform*xf
		up = up.get_parent()
	return xf

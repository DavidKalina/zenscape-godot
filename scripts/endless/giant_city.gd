extends Node3D
## The giants' city on the real Amberlands (docs/design/endless-flight/
## spec-giant-city.md): one node, drawn through RenderingServer with shared
## meshes, solid to the flight through `ground` and `inside` as giant_ruins.gd
## is. Plain grey shapes, so its lines can be flown and judged before anything
## is spent on looks.
##
## THE PIECE CONTRACT. A piece is one file in scripts/endless/city/, and adding
## one touches the shared files in one line: its row in PLACED below. The file:
##
##   extends RefCounted
##   const Shapes = preload("res://scripts/endless/city/city_shapes.gd")
##   ## How far from its origin the piece reaches (m): keeps the stomper off.
##   const REACH := 420.0
##   static func build(s: Shapes) -> void:
##       s.box(...); s.slope(...); s.cyl(...); s.stamp(block,at,yaw)
##
## - The frame: the origin on the ground, at the middle of the piece, +z the way
##   the line flies out of it, +x across, m at true size. Nothing is a node, a
##   mesh or a body: `build` only describes (city_shapes.gd), once a piece, and
##   a second placing of it shares its meshes.
## - The ground: the origin stands at the land's mean under the piece, and the
##   land's shape stays. Take anything that meets the land down to y = -DEEP (or
##   lower where the land falls away), so no foot hangs in the air: a shape that
##   starts under y = 0 draws no underside.
## - Repeats: a thing used many times (a column, a pier) is its own CityShapes,
##   built once in `build` and `stamp`ed: one shared mesh, many instances.
## - Far: set `s.layer`. BOTH by default: near, far and solid. NEAR: detail
##   left out of the far mesh, still solid. FAR: a stand-in only the far mesh
##   has, never solid, so a far version can be one mass for many near ones. Past
##   NEAR_TO m only the far mesh draws. Fill it by hand: a piece whose far is as
##   heavy as its near has no far version.
## - Solid: every shape, exactly as drawn (a round's solid is its true circle,
##   its mesh that circle's polygon). The solid is the shapes, so no piece writes
##   its own collision. Nothing here moves.
## - A line: name each opening's toy width and size it with WorldScale `opening`,
##   as gate.gd does. Every piece has a wide line and a tight one.
## - Its name in PLACED is its handle (`city/<piece>`; layouts/endless_flight.json
##   can move or delete it, yaw and place only). `along`, `across` and `turn` set
##   it in the mouth's frame (`frame`): +z out of the hall's mouth on the
##   Amberlands, +x across, `turn` radians off straight out.
## - Budgets, triangles: a wall section 2,000, a pier 500, a gate 5,000, a hall
##   section 3,000, the pyramid 10,000 (`setup` prints what the city came to).
##
## Hooks: the study's plane_ground, _blocked, _solid, _sight (`ground`, `inside`);
## a physics body on layer 1 per stamp for the wing rays (NearMiss), from the near
## mesh; stomper.gd's `_open` (`clear_of`). The city exists on the Amberlands' side
## only: it stands there and the door is the way to it.

const GiantSwells = preload("res://scripts/endless/giant_swells.gd")
const LandHalls = preload("res://scripts/endless/land_halls.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Shapes = preload("res://scripts/endless/city/city_shapes.gd")

## The placed pieces, each one row (the contract, above).
const PLACED := [
	{"name":"city/gate","piece":preload("res://scripts/endless/city/gate.gd"),"along":350.0,"across":71.0,"turn":0.2},
	{"name":"city/pyramid","piece":preload("res://scripts/endless/city/pyramid.gd"),"along":0.0,"across":800.0,"turn":0.0},
]

## How far under the origin a piece's feet go (m): the land's rise and fall
## under a piece on the flats by the mouth.
const DEEP := 60.0
## Past this the far mesh takes over (m), give or take MARGIN.
const NEAR_TO := 3000.0
const MARGIN := 100.0
const LAYER := 1
const GREY := Color(0.58,0.57,0.55)
## What the stone gives off itself: the Amberlands' low sun leaves a shaded face
## black, and a wall the plane can't see has no line to fly.
const GLOW := 0.2
## The solid's lookup: cells (m), and what a shape's cover is grown by in them:
## the most any caller pads.
const CELL := 96.0
const GROW := 4.0
## Floats a solid keeps: where it stands (x, y, z, cos, sin), then its row.
const STRIDE := 16
const HEAD := 5

var _views: Array[RID] = []
var _bodies: Array[RID] = []
var _keep: Array[Resource] = []
var _grey: StandardMaterial3D
## What each block draws and collides with, by the block.
var _made := {}
## Solids in a row of STRIDE floats, the cell -> solid numbers, their bounds.
var _s := PackedFloat64Array()
var _cells := {}
var _low := Vector2(INF,INF)
var _high := Vector2(-INF,-INF)
var _tris := Vector2i.ZERO
static var _rings: Array = []
static var _rings_for := 0

static func wanted(world: Variant) -> bool:
	return GiantSwells.home(world).is_finite()

## The hall's mouth on the Amberlands, seen from outside: the origin the mouth's
## place on the land, +z out, +x across (hall_doors.gd lays it out from the same
## point, and giant_swells.gd the head it looks at).
static func frame(world: RefCounted) -> Transform3D:
	var at: Vector2 = GiantSwells.home(world)+GiantSwells.DOOR_AT
	var out := -GiantSwells.DOOR_AT.normalized()
	return Transform3D(Basis(Vector3.UP,atan2(out.x,out.y)),Vector3(at.x,0.0,at.y))

## A row's coded place (its y worked out later, from the land).
static func _coded(world: RefCounted, e: Dictionary) -> Transform3D:
	var f := frame(world)
	return Transform3D(f.basis*Basis(Vector3.UP,float(e.turn)),f*Vector3(float(e.across),0.0,float(e.along)))

## Whether (x, z) is `room` m or more off every piece (the stomper's route).
static func clear_of(world: RefCounted, x: float, z: float, room: float) -> bool:
	if not wanted(world): return true
	if _rings_for != world.get_instance_id():
		_rings_for = world.get_instance_id()
		_rings.clear()
		for e: Dictionary in PLACED:
			if LayoutOverrides.deleted(str(e.name)): continue
			var at := LayoutOverrides.xform(str(e.name),_coded(world,e)).origin
			_rings.append(Vector3(at.x,at.z,float(e.piece.REACH)))
	for r: Vector3 in _rings:
		var d := r.z+room
		if (x-r.x)*(x-r.x)+(z-r.y)*(z-r.y) < d*d: return false
	return true

func setup(host: Node3D) -> void:
	_grey = StandardMaterial3D.new()
	_grey.albedo_color = GREY
	_grey.roughness = 0.9
	_grey.emission_enabled = true
	_grey.emission = GREY
	_grey.emission_energy_multiplier = GLOW
	_keep.append(_grey)
	var built := {}
	for e: Dictionary in PLACED:
		var name_of := str(e.name)
		if LayoutOverrides.deleted(name_of): continue
		var piece: GDScript = e.piece
		if not built.has(piece):
			var shapes := Shapes.new()
			piece.call("build",shapes)
			built[piece] = shapes
		var block: RefCounted = built[piece]
		var place := LayoutOverrides.xform(name_of,_seated(_coded(host.world,e),block,host))
		_walk(block,Transform3D(Basis(Vector3.UP,atan2(place.basis.z.x,place.basis.x.x)),place.origin))
	print("giant city: %d solids, %d near triangles and %d far, %d instances, %d bodies" % [_s.size()/STRIDE,_tris.x,_tris.y,_views.size(),_bodies.size()])

## `place` at the land's mean under the block.
func _seated(place: Transform3D, block: RefCounted, host: Node3D) -> Transform3D:
	var r: Rect2 = block.bounds()
	var total := 0.0
	const N := 5
	for i in N:
		for j in N:
			var q := place*Vector3(r.position.x+r.size.x*i/(N-1.0),0.0,r.position.y+r.size.y*j/(N-1.0))
			total += float(host.field.height(q.x,q.z))
	place.origin.y = total/float(N*N)
	return place

## A block at `xf`: drawn, solid, and what it stamps.
func _walk(block: RefCounted, xf: Transform3D) -> void:
	if not block.parts.is_empty():
		_draw(block,xf)
		for p: Dictionary in block.parts:
			if int(p.layer) & Shapes.NEAR: _add_solid(p,xf)
	for s: Dictionary in block.stamps:
		_walk(s.block,xf*(s.at as Transform3D))

func _draw(block: RefCounted, xf: Transform3D) -> void:
	if not _made.has(block): _made[block] = _make(block)
	var m: Dictionary = _made[block]
	var near: ArrayMesh = m.near
	var far: ArrayMesh = m.far
	if near != null:
		_tris.x += near.surface_get_array_len(0)/3
		_view(near,xf,0.0,NEAR_TO)
		var body := PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body,PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_collision_layer(body,LAYER)
		PhysicsServer3D.body_set_collision_mask(body,0)
		PhysicsServer3D.body_add_shape(body,(m.shape as Shape3D).get_rid())
		PhysicsServer3D.body_attach_object_instance_id(body,get_instance_id())
		PhysicsServer3D.body_set_state(body,PhysicsServer3D.BODY_STATE_TRANSFORM,xf)
		PhysicsServer3D.body_set_space(body,get_world_3d().space)
		_bodies.append(body)
	if far != null:
		_tris.y += far.surface_get_array_len(0)/3
		_view(far,xf,NEAR_TO,0.0)

func _make(block: RefCounted) -> Dictionary:
	var near: ArrayMesh = block.mesh(Shapes.NEAR)
	var far: ArrayMesh = block.mesh(Shapes.FAR)
	var shape: Shape3D = null
	if near != null:
		near.surface_set_material(0,_grey)
		shape = near.create_trimesh_shape()
		_keep.append(near)
		_keep.append(shape)
	if far != null:
		far.surface_set_material(0,_grey)
		_keep.append(far)
	return {"near":near,"far":far,"shape":shape}

func _view(mesh: ArrayMesh, xf: Transform3D, from: float, to: float) -> void:
	var view := RenderingServer.instance_create2(mesh.get_rid(),get_world_3d().scenario)
	RenderingServer.instance_set_transform(view,xf)
	RenderingServer.instance_geometry_set_visibility_range(view,from,to,MARGIN if from > 0.0 else 0.0,MARGIN if to > 0.0 else 0.0,RenderingServer.VISIBILITY_RANGE_FADE_DISABLED)
	_views.append(view)

func _exit_tree() -> void:
	for view: RID in _views: RenderingServer.free_rid(view)
	for body: RID in _bodies: PhysicsServer3D.free_rid(body)
	_views.clear()
	_bodies.clear()

## One shape into the solid and every cell its cover touches.
func _add_solid(p: Dictionary, xf: Transform3D) -> void:
	var i := _s.size()/STRIDE
	var c := xf.basis.x.x
	var s := xf.basis.z.x
	var o := xf.origin
	_s.append_array(PackedFloat64Array([o.x,o.y,o.z,c,s]))
	_s.append_array(Shapes.solid_row(p))
	var r := Shapes._flat(p).grow(GROW)
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for q: Vector2 in [r.position,r.position+Vector2(r.size.x,0.0),r.position+Vector2(0.0,r.size.y),r.end]:
		var w := Vector2(o.x+q.x*c+q.y*s,o.z-q.x*s+q.y*c)
		low = low.min(w)
		high = high.max(w)
	_low = _low.min(low)
	_high = _high.max(high)
	for x in range(floori(low.x/CELL),floori(high.x/CELL)+1):
		for z in range(floori(low.y/CELL),floori(high.y/CELL)+1):
			var key := Vector2i(x,z)
			if not _cells.has(key): _cells[key] = PackedInt32Array()
			_cells[key].append(i)

## The numbers of the solids that may cover (x, z), or none.
func _near(x: float, z: float) -> PackedInt32Array:
	if x < _low.x or x > _high.x or z < _low.y or z > _high.y: return PackedInt32Array()
	return _cells.get(Vector2i(floori(x/CELL),floori(z/CELL)),PackedInt32Array())

## The stretch of world height solid `i`, grown by `pad`, covers over (x, z):
## Vector2(low, high), low over high for none. Each edge is a line in the share
## of the way up, so the cover is where all of them hold.
func _stretch(i: int, x: float, z: float, pad: float) -> Vector2:
	var b := i*STRIDE
	var dx := x-_s[b]
	var dz := z-_s[b+2]
	var c := _s[b+3]
	var s := _s[b+4]
	var lx := dx*c-dz*s
	var lz := dx*s+dz*c
	var r := b+HEAD
	var t0 := 0.0
	var t1 := 1.0
	var f0: float
	var f1: float
	if _s[r+10] == Shapes.ROUND:
		var d := Vector2(lx-_s[r+2],lz-_s[r+3]).length()-pad
		f0 = d-_s[r+4]
		f1 = d-_s[r+5]
		if f0 > 0.0 and f1 > 0.0: return Vector2.RIGHT
		if f0 > 0.0: t0 = f0/(f0-f1)
		elif f1 > 0.0: t1 = f0/(f0-f1)
	else:
		for e in 4:
			var at := r+2+e*2
			var v: float = (lx if e < 2 else lz)
			# A low edge holds under the point, a high one over it.
			if e%2 == 0:
				f0 = _s[at]-v-pad
				f1 = _s[at+1]-v-pad
			else:
				f0 = v-pad-_s[at]
				f1 = v-pad-_s[at+1]
			if f0 > 0.0 and f1 > 0.0: return Vector2.RIGHT
			if f0 > 0.0: t0 = maxf(t0,f0/(f0-f1))
			elif f1 > 0.0: t1 = minf(t1,f0/(f0-f1))
		if t0 > t1: return Vector2.RIGHT
	var y0 := _s[b+1]+_s[r]
	var y1 := _s[b+1]+_s[r+1]
	return Vector2(y0+(y1-y0)*t0-(pad if t0 == 0.0 else 0.0),y0+(y1-y0)*t1+(pad if t1 == 1.0 else 0.0))

## SkyGlide's `ground` at `p` over the land `h` (LandHalls `over`), the stone
## grown by `pad` (the wingtip's reach when not given).
func ground(p: Vector3, h: Variant, pad := -1.0) -> Variant:
	if not h is float: return h
	var near := _near(p.x,p.z)
	if near.is_empty(): return h
	if pad < 0.0: pad = WorldScale.span*0.5
	var list: Array[Vector2] = []
	for i: int in near:
		var s := _stretch(i,p.x,p.z,pad)
		if s.x < s.y: list.append(s)
	if list.is_empty(): return h
	if list.size() == 1: return LandHalls.over(p,h,list)
	list.sort_custom(func(l: Vector2, r: Vector2) -> bool: return l.x < r.x)
	# One stretch where shapes stack, so `over` reads what is really open.
	var whole: Array[Vector2] = [list[0]]
	for s: Vector2 in list:
		var last := whole[whole.size()-1]
		if s.x <= last.y: whole[whole.size()-1] = Vector2(last.x,maxf(last.y,s.y))
		else: whole.append(s)
	return LandHalls.over(p,h,whole)

## True in the stone, grown by `pad` (the wingtip's reach when not given).
func inside(p: Vector3, pad := -1.0) -> bool:
	var near := _near(p.x,p.z)
	if near.is_empty(): return false
	if pad < 0.0: pad = WorldScale.span*0.5
	for i: int in near:
		var s := _stretch(i,p.x,p.z,pad)
		if p.y >= s.x and p.y <= s.y: return true
	return false

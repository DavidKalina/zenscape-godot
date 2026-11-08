extends RefCounted
## The pirate ship's guns' look and the marks their shots leave (pirate_ship.gd;
## docs/design/endless-flight/ship-guns-handoff.md): the muzzle blast, the powder
## smoke a ball leaves hanging along its line, the splash where it comes down on
## the water (or the burst of dirt on land), and the guns' meshes cut out of the
## glb. All of it look only: what a ball hits is pirate_ship.gd's.
##
## Cheap by build. A blast and a splash are one shared mesh each (both ships',
## `shared`), every bit's throw baked into it and played in its shaders by the
## node's `age` (an instance uniform), so a shot makes no mesh and no material.
## Each ship pools BLASTS blasts and SPLASHES splashes, and draws its trail as one
## MultiMesh of TRAIL puffs whose buffer is written whole, once, in a frame
## something was added (never one instance in place).

const SOLID := preload("res://assets/models/pirate_ship/gun_burst_solid.gdshader")
const SOFT := preload("res://assets/models/pirate_ship/gun_burst_soft.gdshader")
const TRAIL_SHADER := preload("res://assets/models/pirate_ship/gun_trail.gdshader")

## A bit's role in its shader (gun_fx.gdshaderinc).
enum {BLOB, FLASH, DROP, RING, PATCH}

## The most of each a ship keeps at once, and how long each lasts at most (s).
const BLASTS := 8
const BLAST_LIFE := 8.5
const SPLASHES := 10
const SPLASH_LIFE := 5.5
## A splash: its column's height at the tallest (m), and the fall its water is
## thrown against (m/s²): more than the world's, so it snaps up and down.
const SPLASH_HIGH := 26.0
const SPLASH_FALL := 26.0
## How a splash stands by how steeply the ball came in (the sine of its dive):
## its column's share of SPLASH_HIGH and its slant (m/s along per m/s up), from
## a skim (x) to a plunge (y). Off land, the clods fly this share as high.
const SPLASH_TALL := Vector2(0.36,1.0)
const SPLASH_LEAN := Vector2(0.8,0.06)
const SPLASH_STEEP := Vector2(0.1,0.45)
const DIRT_TALL := 0.45
## The trail: puffs a ship keeps; how far apart they're let go along a hull shot
## and a lob (m); their first radius (m); the longest a puff lasts (gun_trail
## `life`'s most, s).
const TRAIL := 1024
const TRAIL_EVERY := Vector2(2.6,2.2)
const TRAIL_R := Vector2(1.3,1.7)
const TRAIL_LAST := 4.0

const WATER := Color(0.94,0.97,1.0)
const SMOKE := Color(0.8,0.8,0.81)
const SMOKE_DARK := Color(0.62,0.61,0.6)

## Meshes both ships draw: {blast, splash, quad}, and the cut guns by name.
var shared: Dictionary
var root: Node3D
var _blasts: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []
var _trail: MultiMeshInstance3D
var _trail_mat: ShaderMaterial
var _buf := PackedFloat32Array()
var _next_puff := 0
var _dirty := false
var _now := 0.0
var _box := AABB()
var _box_until := -1.0
## Counts, for the handoff's checks.
var blasts := 0
var splashes := 0
var puffs := 0

## The meshes both ships share, made ahead on a worker (PirateShip `warm`) for
## the next ship with no twin.
static var warm_shared := {}

static func make_shared() -> Dictionary:
	return {"blast":_blast_mesh(),"splash":_splash_mesh(),"quad":_quad(),"cuts":{}}

## Its nodes go under `parent` (the world's frame); `twin` is the other ship's,
## whose meshes it shares.
func _init(parent: Node, twin: RefCounted) -> void:
	root = Node3D.new()
	root.name = "ShipGunFx"
	parent.add_child(root)
	if twin != null:
		shared = twin.shared
	elif not warm_shared.is_empty():
		shared = warm_shared
		warm_shared = {}
	else:
		shared = make_shared()
	_trail_mat = ShaderMaterial.new()
	_trail_mat.shader = TRAIL_SHADER
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = shared.quad
	mm.instance_count = TRAIL
	_buf.resize(TRAIL*16)
	for i in TRAIL:
		var o := i*16
		_buf[o] = 1.0
		_buf[o+5] = 1.0
		_buf[o+10] = 1.0
		_buf[o+12] = -1.0e4
	mm.buffer = _buf
	_trail = MultiMeshInstance3D.new()
	_trail.name = "Trail"
	_trail.multimesh = mm
	_trail.material_override = _trail_mat
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.visible = false
	root.add_child(_trail)

## A gun fired at `at` (world), its bore out along `out`. Its pool entry.
func blast(at: Vector3, out: Vector3) -> Dictionary:
	var b := _take(_blasts,BLASTS,shared.blast,"Blast")
	var up := Vector3.UP if absf(out.normalized().y) < 0.98 else Vector3.RIGHT
	(b.node as Node3D).global_transform = Transform3D(Basis.looking_at(out.normalized(),up),at)
	_start(b,BLAST_LIFE)
	blasts += 1
	return b

## A ball came down at `at` (on the water, or on land if not `wet`) going `v`.
## Its pool entry.
func splash(at: Vector3, v: Vector3, wet: bool) -> Dictionary:
	var s := _take(_splashes,SPLASHES,shared.splash,"Splash")
	var steep := clampf(-v.y/maxf(v.length(),1.0),0.0,1.0)
	var k := smoothstep(SPLASH_STEEP.x,SPLASH_STEEP.y,steep)
	var flat := Vector3(v.x,0.0,v.z)
	flat = flat.normalized() if flat.length() > 0.1 else Vector3.ZERO
	var n: MeshInstance3D = s.node
	n.global_transform = Transform3D(Basis.IDENTITY,at)
	n.set_instance_shader_parameter("tall",lerpf(SPLASH_TALL.x,SPLASH_TALL.y,k)*(1.0 if wet else DIRT_TALL))
	n.set_instance_shader_parameter("lean",flat*lerpf(SPLASH_LEAN.x,SPLASH_LEAN.y,k))
	n.set_instance_shader_parameter("dirt",0.0 if wet else 1.0)
	_start(s,SPLASH_LIFE)
	splashes += 1
	return s

## Ball `b` flew from `a` to `n` this frame: puffs let go along it, every
## TRAIL_EVERY m (its `trail` the metres to the next).
func trail(b: Dictionary, a: Vector3, n: Vector3) -> void:
	var lob := bool(b.get("lob",false))
	var every := TRAIL_EVERY.y if lob else TRAIL_EVERY.x
	var d := a.distance_to(n)
	var s := float(b.get("trail",0.0))
	# A jump (a ball just reused, a bad frame) leaves no line of puffs.
	if not d < every*12.0:
		b["trail"] = 0.0
		return
	while s <= d:
		_puff(a.lerp(n,s/maxf(d,0.001)),lob)
		s += every
	b["trail"] = s-d

## One frame: the blasts and splashes age, the trail's clock and buffer.
func step(delta: float) -> void:
	_now += delta
	_trail_mat.set_shader_parameter("now",_now)
	for pool: Array in [_blasts,_splashes]:
		for p: Dictionary in pool:
			var n: MeshInstance3D = p.node
			if not n.visible: continue
			p.age = float(p.age)+delta
			if float(p.age) > float(p.life):
				n.visible = false
				continue
			n.set_instance_shader_parameter("age",float(p.age))
	if _dirty:
		_dirty = false
		_trail.multimesh.buffer = _buf
		_trail.multimesh.custom_aabb = _box
		_trail.visible = true
	elif _trail.visible and _now > _box_until:
		_trail.visible = false
		_box = AABB()

## How many blasts, splashes and puffs are showing now.
func live() -> Dictionary:
	var out := {"blasts":0,"splashes":0,"puffs":0}
	for p: Dictionary in _blasts: if (p.node as Node3D).visible: out.blasts += 1
	for p: Dictionary in _splashes: if (p.node as Node3D).visible: out.splashes += 1
	for i in TRAIL:
		var t := _now-_buf[i*16+12]
		if t >= 0.0 and t < TRAIL_LAST: out.puffs += 1
	return out

func _puff(at: Vector3, lob: bool) -> void:
	var o := _next_puff*16
	_next_puff = (_next_puff+1)%TRAIL
	_buf[o+3] = at.x
	_buf[o+7] = at.y
	_buf[o+11] = at.z
	_buf[o+12] = _now
	_buf[o+13] = randf()
	_buf[o+14] = TRAIL_R.y if lob else TRAIL_R.x
	_buf[o+15] = 1.0 if lob else 0.0
	# The box the shader may draw them in: the spot, the swell, the drift.
	var room := AABB(at-Vector3.ONE*14.0,Vector3.ONE*28.0)
	_box = room if _box.size == Vector3.ZERO else _box.merge(room)
	_box_until = _now+TRAIL_LAST
	_dirty = true
	puffs += 1

## A free one of `pool` (else a new one, while under `most`; else the oldest).
func _take(pool: Array[Dictionary], most: int, mesh: Mesh, label: String) -> Dictionary:
	var oldest: Dictionary = {}
	for p: Dictionary in pool:
		if not (p.node as Node3D).visible: return p
		if oldest.is_empty() or float(p.age) > float(oldest.age): oldest = p
	if pool.size() >= most: return oldest
	var n := MeshInstance3D.new()
	n.name = label+str(pool.size())
	n.mesh = mesh
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	root.add_child(n)
	var p := {"node":n,"age":0.0,"life":1.0}
	pool.append(p)
	return p

func _start(p: Dictionary, life: float) -> void:
	p.age = 0.0
	p.life = life
	var n: MeshInstance3D = p.node
	n.set_instance_shader_parameter("age",0.0)
	n.visible = true

# --- The meshes -----------------------------------------------------------------

## Bits of a burst, every one a disc of four corners at its start, its throw and
## look in the custom channels (gun_fx.gdshaderinc reads them).
class Burst:
	var rng := RandomNumberGenerator.new()
	var at := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var c2 := PackedFloat32Array()
	var c3 := PackedFloat32Array()
	var index := PackedInt32Array()

	func _init(salt: int) -> void:
		rng.seed = salt

	## A bit set off from `p` at `v` (m/s) after `delay` (s), lasting `life`,
	## slowed by `drag` (1/s), falling at `fall` (m/s²), radius `r0` to `r1`.
	func bit(p: Vector3, v: Vector3, delay: float, life: float, drag: float, fall: float, r0: float, r1: float, opacity: float, role: int, tint: Color, hard := 0.4, glow := 0.3, wind := 0.0) -> void:
		var first := at.size()
		var salt := rng.randf()
		for corner: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
			at.append(p)
			uv.append(corner)
			col.append(tint)
			c0.append_array([v.x,v.y,v.z,delay])
			c1.append_array([life,drag,fall,salt])
			c2.append_array([r0,r1,opacity,float(role)])
			c3.append_array([hard,glow,wind,0.0])
		index.append_array([first,first+1,first+2,first,first+2,first+3])

	## A way within `spread` rad of `dir`.
	func near(dir: Vector3, spread: float) -> Vector3:
		var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(dir).normalized()
		var a := rng.randf()*TAU
		var r := spread*sqrt(rng.randf())
		return (dir+(side*cos(a)+up*sin(a))*tan(r)).normalized()

	## The bits so far as a surface of `mesh`, drawn with `shader`; then empty.
	func surface(mesh: ArrayMesh, shader: Shader) -> void:
		if at.is_empty(): return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = at
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_CUSTOM0] = c0
		arrays[Mesh.ARRAY_CUSTOM1] = c1
		arrays[Mesh.ARRAY_CUSTOM2] = c2
		arrays[Mesh.ARRAY_CUSTOM3] = c3
		arrays[Mesh.ARRAY_INDEX] = index
		var f := Mesh.ARRAY_CUSTOM_RGBA_FLOAT
		var flags := (f << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (f << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | (f << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) | (f << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mesh.surface_set_material(mesh.get_surface_count()-1,mat)
		at = PackedVector3Array()
		uv = PackedVector2Array()
		col = PackedColorArray()
		c0 = PackedFloat32Array()
		c1 = PackedFloat32Array()
		c2 = PackedFloat32Array()
		c3 = PackedFloat32Array()
		index = PackedInt32Array()

## The blast, in the bore's frame (-z out of the muzzle): the flash and its
## tongue of fire, a ring of smoke thrown round the muzzle that stops a few
## metres off, the cloud blown on down the bore that slows, swells and hangs on
## the wind, a breath of smoke back at the gun, and sparks.
static func _blast_mesh() -> ArrayMesh:
	var b := Burst.new(7)
	var mesh := ArrayMesh.new()
	var out := Vector3.FORWARD
	# Smoke first, the flash last: in one surface, the later bits draw over.
	for i in 18:
		var dir := b.near(out,0.26)
		b.bit(Vector3.ZERO,dir*b.rng.randf_range(18.0,62.0)+Vector3.UP*b.rng.randf_range(0.0,3.0),b.rng.randf_range(0.0,0.05),b.rng.randf_range(6.0,8.0),1.7,-0.8,2.4,b.rng.randf_range(8.0,12.0),0.55,BLOB,SMOKE if i%3 else SMOKE_DARK,0.3,0.35,1.0)
	for i in 6:
		var dir := b.near(Vector3(0.0,0.3,0.6).normalized(),0.6)
		b.bit(Vector3.ZERO,dir*b.rng.randf_range(2.0,6.0),0.04,b.rng.randf_range(4.5,6.0),1.2,-0.5,2.0,b.rng.randf_range(5.0,6.5),0.5,BLOB,SMOKE,0.3,0.3,0.8)
	for i in 20:
		var a := TAU*float(i)/20.0+b.rng.randf_range(-0.1,0.1)
		var radial := Vector3(cos(a),sin(a),0.0)
		b.bit(radial*1.2,radial*b.rng.randf_range(20.0,26.0)+out*b.rng.randf_range(14.0,20.0),0.01,b.rng.randf_range(2.6,3.4),3.0,-0.4,1.5,4.0,0.75,BLOB,SMOKE,0.55,0.3,0.4)
	for i in 10:
		var dir := b.near(out,0.35)
		b.bit(Vector3.ZERO,dir*b.rng.randf_range(45.0,85.0),0.0,b.rng.randf_range(0.45,0.85),1.0,9.8,0.4,0.22,1.0,DROP,Color(1.0,0.62,0.25),1.0,0.0,0.0)
	for i in 3:
		b.bit(out*0.8,out*b.rng.randf_range(60.0,90.0)+b.near(out,0.3)*6.0,0.0,0.22,13.0,0.0,2.6,4.2,0.9,FLASH,Color(1.0,0.55,0.2),0.4)
	for i in 5:
		b.bit(out*(0.8+1.8*i),out*6.0,0.0,0.12+0.03*i,4.0,0.0,5.2-0.4*i,7.0-0.5*i,1.0,FLASH,Color(1.0,0.86,0.55).lerp(Color(1.0,0.6,0.25),i/5.0),0.3)
	b.surface(mesh,SOFT)
	mesh.custom_aabb = AABB(Vector3(-40.0,-25.0,-80.0),Vector3(80.0,60.0,95.0))
	return mesh

## The splash, at the water with y up: a column of water thrown straight up,
## streaks at its foot and blobs at its top, a boil of fat blobs low round it, a
## crown of sheets thrown up and out, drops; then soft: a skirt of spray running
## out over the water, mist that lifts and drifts, a foam ring spreading and the
## patch left in it. `tall`, `lean` and `dirt` (per splash) shape it.
static func _splash_mesh() -> ArrayMesh:
	var b := Burst.new(11)
	var mesh := ArrayMesh.new()
	var fall := SPLASH_FALL
	var top := sqrt(2.0*fall*SPLASH_HIGH)
	for i in 40:
		var u := b.rng.randf()
		var vy := top*(0.35+0.65*sqrt(u))
		var a := b.rng.randf()*TAU
		var p := Vector3(cos(a),0.0,sin(a))*b.rng.randf_range(0.0,1.2)
		var r := lerpf(2.5,1.3,u)
		b.bit(p,Vector3(p.x*0.9,vy,p.z*0.9),b.rng.randf_range(0.0,0.08),2.0*vy/fall,0.05,fall,r*0.5,r,1.0,DROP,WATER,1.0,0.7)
	for i in 9:
		var a := TAU*float(i)/9.0
		var p := Vector3(cos(a),0.0,sin(a))*b.rng.randf_range(1.0,2.2)
		var vy := top*b.rng.randf_range(0.18,0.3)
		b.bit(p,Vector3(p.x*1.6,vy,p.z*1.6),b.rng.randf_range(0.0,0.1),2.0*vy/fall+0.2,0.3,fall,1.5,b.rng.randf_range(2.6,3.4),1.0,BLOB,WATER,1.0,0.7)
	for i in 20:
		var a := TAU*float(i)/20.0+b.rng.randf_range(-0.12,0.12)
		var out := Vector3(cos(a),0.0,sin(a))
		var vy := top*b.rng.randf_range(0.42,0.58)
		b.bit(out*2.2,out*top*b.rng.randf_range(0.3,0.42)+Vector3.UP*vy,0.02,2.0*vy/fall,0.3,fall,0.8,1.3,1.0,DROP,WATER,1.0,0.7)
	for i in 30:
		var a := b.rng.randf()*TAU
		var lift := b.rng.randf_range(0.6,1.4)
		var dir := Vector3(cos(a)*cos(lift),sin(lift),sin(a)*cos(lift))
		var speed := top*b.rng.randf_range(0.45,0.9)
		b.bit(dir*1.5,dir*speed,b.rng.randf_range(0.0,0.15),2.0*speed*dir.y/fall+0.3,0.15,fall,0.3,b.rng.randf_range(0.45,0.75),1.0,DROP,WATER,1.0,0.7)
	b.surface(mesh,SOLID)
	b.bit(Vector3(0.0,0.12,0.0),Vector3.ZERO,0.0,4.2,1.0,0.0,3.0,18.0,0.45,RING,WATER)
	b.bit(Vector3(0.0,0.14,0.0),Vector3.ZERO,0.7,3.4,1.0,0.0,2.0,11.0,0.35,RING,WATER)
	b.bit(Vector3(0.0,0.1,0.0),Vector3.ZERO,0.15,5.3,1.0,0.0,4.5,8.5,0.6,PATCH,WATER)
	for i in 12:
		var a := TAU*float(i)/12.0+b.rng.randf_range(-0.2,0.2)
		var out := Vector3(cos(a),0.0,sin(a))
		b.bit(out*2.0+Vector3.UP*1.2,out*b.rng.randf_range(10.0,17.0)+Vector3.UP*2.5,0.0,b.rng.randf_range(1.5,2.2),2.0,1.5,1.8,4.4,0.6,BLOB,WATER,0.4,0.7,0.3)
	for i in 7:
		var a := b.rng.randf()*TAU
		var p := Vector3(cos(a)*b.rng.randf_range(0.0,2.5),SPLASH_HIGH*b.rng.randf_range(0.12,0.65),sin(a)*b.rng.randf_range(0.0,2.5))
		b.bit(p,Vector3(cos(a)*1.5,b.rng.randf_range(0.6,2.0),sin(a)*1.5),b.rng.randf_range(0.35,1.0),b.rng.randf_range(2.6,3.8),0.6,-0.3,2.5,b.rng.randf_range(4.5,7.0),0.22,BLOB,WATER,0.0,0.8,1.0)
	b.surface(mesh,SOFT)
	mesh.custom_aabb = AABB(Vector3(-40.0,-4.0,-40.0),Vector3(80.0,SPLASH_HIGH+16.0,80.0))
	return mesh

## One trail puff's disc, its corners at its centre for gun_trail to spread.
static func _quad() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

# --- The guns' meshes, cut from the glb ----------------------------------------------

## The triangles of `mesh` whose middles `keep` takes (a point in the mesh's
## frame), moved by `xf`, as a mesh of their own: only surfaces `which` takes
## (Callable(Material) -> bool; all if null), each with its material, or
## `swap`'s for it (Material -> Material).
static func cut(mesh: Mesh, keep: Callable, xf: Transform3D, which: Variant = null, swap := {}) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var mat: Material = mesh.surface_get_material(si)
		if which != null and not bool((which as Callable).call(mat)): continue
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var nrm: Variant = arr[Mesh.ARRAY_NORMAL]
		var tng: Variant = arr[Mesh.ARRAY_TANGENT]
		var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
		var col: Variant = arr[Mesh.ARRAY_COLOR]
		var map := {}
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		var nt := PackedFloat32Array()
		var nu := PackedVector2Array()
		var nc := PackedColorArray()
		var ni := PackedInt32Array()
		for t in range(0,idx.size(),3):
			if not bool(keep.call((v[idx[t]]+v[idx[t+1]]+v[idx[t+2]])/3.0)): continue
			for k in 3:
				var j: int = idx[t+k]
				if not map.has(j):
					map[j] = nv.size()
					nv.append(xf*v[j])
					if nrm != null: nn.append((xf.basis*(nrm as PackedVector3Array)[j]).normalized())
					if tng != null:
						var ta: PackedFloat32Array = tng
						var d: Vector3 = (xf.basis*Vector3(ta[j*4],ta[j*4+1],ta[j*4+2])).normalized()
						nt.append_array([d.x,d.y,d.z,ta[j*4+3]])
					if uv != null: nu.append((uv as PackedVector2Array)[j])
					if col != null: nc.append((col as PackedColorArray)[j])
				ni.append(int(map[j]))
		if ni.is_empty(): continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = nv
		if nrm != null: arrays[Mesh.ARRAY_NORMAL] = nn
		if tng != null: arrays[Mesh.ARRAY_TANGENT] = nt
		if uv != null: arrays[Mesh.ARRAY_TEX_UV] = nu
		if col != null: arrays[Mesh.ARRAY_COLOR] = nc
		arrays[Mesh.ARRAY_INDEX] = ni
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		out.surface_set_material(out.get_surface_count()-1,swap.get(mat,mat))
	return out

## True for a point of a gun whose muzzle is `muzzle` (a frame: -z out, the
## mesh's): back up its bore `long` m, `wide` m to either side, `low` under it to
## `high` over.
static func in_gun(p: Vector3, muzzle: Transform3D, long := 7.5, wide := 1.5, low := 2.5, high := 1.4) -> bool:
	var l := muzzle.affine_inverse()*p
	return l.z > -0.7 and l.z < long and absf(l.x) < wide and l.y > -low and l.y < high

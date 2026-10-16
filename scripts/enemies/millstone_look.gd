extends RefCounted
## The Millstone Beetle's look,
## built from code: the wheel, a dressed millstone in the Olmec's weathered
## basalt (shaders/olmec_stone.gdshader via scripts/enemies/
## inhaler_head_look.gd `stone_material` and `_dressed`: the rest pose in UV
## and UV2, so the grain turns with the wheel) on a squared timber axle;
## the beetle a low domed scarab in old dusty chitin (shaders/
## beetle_chitin.gdshader), six legs on hip pivots (the front pair gripping
## the axle's ends), a small head with clubbed feelers. No horns, spikes or
## glows (AGENTS.md art direction): its menace is the stone's weight.
const HeadLook = preload("res://scripts/enemies/inhaler_head_look.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")
const CHITIN := preload("res://shaders/beetle_chitin.gdshader")

## The wheel's stone (one quarry for every beetle) and its lathe: the
## turns round, the chamfer and the eye as shares of the diameter.
const STONE_SEED := 11
const TURNS := 32
const CHAMFER := 0.045
const EYE := 0.1
## The axle: its side as a share of the diameter, how far past each face.
const AXLE := 0.13
const AXLE_OUT := 0.16
## Past this (m) the beetle's parts are not drawn (the wheel a half again).
const FAR := 140.0

static var _chitin: ShaderMaterial = null
static var _wood: StandardMaterial3D = null
static var _eye: StandardMaterial3D = null
static var _wheels := {}

static func chitin() -> ShaderMaterial:
	if _chitin == null:
		_chitin = ShaderMaterial.new()
		_chitin.shader = CHITIN
	return _chitin

static func wood() -> StandardMaterial3D:
	if _wood == null:
		_wood = StandardMaterial3D.new()
		_wood.albedo_color = Color(0.36,0.31,0.25)
		_wood.roughness = 0.95
	return _wood

## Its eyes: dark beads with a wet glint, no glow.
static func eye() -> StandardMaterial3D:
	if _eye == null:
		_eye = StandardMaterial3D.new()
		_eye.albedo_color = Color(0.05,0.045,0.04)
		_eye.roughness = 0.22
	return _eye

# --- The wheel ----------------------------------------------------------------------

## The millstone `d` m across and `t` m thick, its axle along X, its middle
## at the origin, dressed in the weathered stone (made once a size).
static func wheel_mesh(d: float, t: float) -> Mesh:
	var key := "%.3f/%.3f" % [d,t]
	if _wheels.has(key): return _wheels[key]
	var r := d*0.5
	var h := t*0.5
	var c := d*CHAMFER
	var re := d*EYE
	# The section, round the stone (x along the axle, r out).
	var prof: Array[Vector2] = [Vector2(-h*0.82,re),Vector2(-h,re+c*0.6),Vector2(-h,r-c),Vector2(-h+c,r),
		Vector2(h-c,r),Vector2(h,r-c),Vector2(h,re+c*0.6),Vector2(h*0.82,re)]
	var mid := Vector2(0.0,(r+re)*0.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in range(prof.size()):
		var a: Vector2 = prof[s]
		var b: Vector2 = prof[(s+1)%prof.size()]
		var tang := b-a
		var nrm := Vector2(tang.y,-tang.x).normalized()
		if nrm.dot((a+b)*0.5-mid) < 0.0: nrm = -nrm
		for i in range(TURNS):
			var q0 := TAU*float(i)/TURNS
			var q1 := TAU*float(i+1)/TURNS
			var v00 := _lathe(a,q0,re,r)
			var v01 := _lathe(b,q0,re,r)
			var v10 := _lathe(a,q1,re,r)
			var v11 := _lathe(b,q1,re,r)
			var n0 := Vector3(nrm.x,nrm.y*cos(q0),nrm.y*sin(q0))
			var n1 := Vector3(nrm.x,nrm.y*cos(q1),nrm.y*sin(q1))
			_tri(st,[v00,v01,v11],[n0,n0,n1])
			_tri(st,[v00,v11,v10],[n0,n1,n1])
	var raw := st.commit()
	var stone := Style.stone_of(STONE_SEED) if Style.ruled() else Color("5d5e60")
	var out: Mesh = HeadLook._dressed(raw,stone,Vector3(0.0,r,0.0))
	_wheels[key] = out
	return out

## A section point turned `q` round the axle; the rim worn uneven (a few
## soft dents and one chipped place), the eye true.
static func _lathe(p: Vector2, q: float, re: float, r: float) -> Vector3:
	var out := clampf((p.y-re)/maxf(r-re,0.001),0.0,1.0)
	var wear := 0.012*sin(3.0*q+1.3)+0.008*sin(7.0*q+0.4)+0.005*sin(13.0*q+2.0)
	var chip := -0.035*maxf(0.0,1.0-absf(angle_difference(q,2.1))/0.22)
	var rr := p.y*(1.0+(wear+chip)*out*out)
	return Vector3(p.x,rr*cos(q),rr*sin(q))

## A triangle facing along its normals (Godot's front faces wind clockwise).
static func _tri(st: SurfaceTool, v: Array, n: Array) -> void:
	var face := ((v[1] as Vector3)-(v[0] as Vector3)).cross((v[2] as Vector3)-(v[0] as Vector3))
	var order := [0,1,2] if face.dot((n[0] as Vector3)+(n[1] as Vector3)+(n[2] as Vector3)) < 0.0 else [0,2,1]
	for i: int in order:
		st.set_normal(n[i])
		st.add_vertex(v[i])

## The wheel, its axle and all, as a node turned by `rotation.x` (rolling
## toward -Z is a turn by minus the distance over the radius).
static func wheel(d: float, t: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Wheel"
	var stone := MeshInstance3D.new()
	stone.name = "Stone"
	stone.mesh = wheel_mesh(d,t)
	stone.material_override = HeadLook.stone_material()
	stone.visibility_range_end = FAR*1.5
	root.add_child(stone)
	var axle := MeshInstance3D.new()
	axle.name = "Axle"
	var box := BoxMesh.new()
	box.size = Vector3(t+d*AXLE_OUT*2.0,d*AXLE,d*AXLE)
	axle.mesh = box
	axle.material_override = wood()
	axle.rotation.x = 0.4
	root.add_child(axle)
	return root

# --- The beetle ---------------------------------------------------------------------

## A part of the shell: `mesh` at `at` in `parent`, in the chitin, its rest
## height over the ground `lift` (the dust reads it), `dust` more caked.
static func part(parent: Node3D, mesh: Mesh, at: Vector3, lift: float, dust := 0.0, seed_value := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	m.material_override = chitin()
	m.visibility_range_end = FAR
	parent.add_child(m)
	m.set_instance_shader_parameter("part_lift",lift)
	m.set_instance_shader_parameter("part_dust",dust)
	m.set_instance_shader_parameter("part_seed",seed_value)
	return m

## A dome: the upper half of an ellipsoid `size` (x, up, z) across.
static func dome(size: Vector3) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = size.x*0.5
	s.height = size.y
	s.is_hemisphere = true
	s.radial_segments = 20
	s.rings = 8
	return s

## An ellipsoid `size` across.
static func blob(size: Vector3) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = size.x*0.5
	s.height = size.y
	s.radial_segments = 14
	s.rings = 7
	return s

## A limb segment from `from` to `to` (in `parent`), `radius` thick.
static func limb(parent: Node3D, from: Vector3, to: Vector3, radius: float, lift: float, seed_value := 0.0) -> MeshInstance3D:
	var cap := CapsuleMesh.new()
	var len := from.distance_to(to)
	cap.radius = radius
	cap.height = maxf(len+radius*2.0,radius*2.01)
	cap.radial_segments = 8
	cap.rings = 2
	var m := part(parent,cap,(from+to)*0.5,lift,-0.2,seed_value)
	# Its +Y toward `from` (a shin's knee): the dust settles at the `to` end, the foot.
	var y := (from-to).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	m.basis = Basis(x,y,x.cross(y)).orthonormalized()
	return m

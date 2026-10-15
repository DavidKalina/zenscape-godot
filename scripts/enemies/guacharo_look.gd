extends Node3D
## The guacharo's body (docs/design/roguelike/flyer-round1.md): a giant
## oilbird, the cave bird of the Americas that screams in the dark and finds
## its way by clicks. Built in code: an ellipsoid body, neck and head, a
## hooked horn beak that opens (the scream), big dark eyes, a long graduated
## tail, and two wings of real feathers (each one a quad drawn by shaders/
## guacharo_feather.gdshader: rufous, white-spotted, dusky-tipped, ragged)
## on a shoulder and a wrist each, the outer primaries slotted into
## fingers, and talons that come down for the strike.
##
## Local frame: -Z forward, +Y up, +X the right wing; the design is
## HALF_SPAN m to a wing tip; `size_to(span)` scales it.
##
## Posed by `drive(p)` with a pose dictionary (any key missing keeps its
## rest value): elev (the wings' rise, rad), sweep (the arm swept back),
## wrist (the hand folded back), droop (the hand bent down), twist, spread
## (the primaries' fan 0..1), tail (the tail's fan 0..1), pitch (nose up,
## rad), head (the head's nod), jaw (0..1 open), talons (0..1 down),
## stretch (>1 long and thin, <1 squashed). Blending and timing are the
## brain's (scripts/enemies/guacharo.gd).
const SHADER = preload("res://shaders/guacharo_feather.gdshader")

const HALF_SPAN := 2.15
## Its render layer (the shadow's decal leaves it out).
const LAYER := 1 << 12

const REST := {"elev":0.12,"sweep":0.05,"wrist":0.12,"droop":-0.1,"twist":0.0,"spread":1.0,"tail":0.7,
	"pitch":0.0,"head":0.0,"jaw":0.0,"talons":0.0,"stretch":1.0}

var feather_mat: ShaderMaterial
var body_mat: ShaderMaterial
var horn_mat: StandardMaterial3D
var eye_mat: StandardMaterial3D
## The pose last driven.
var pose: Dictionary = REST.duplicate()

var _body: Node3D
var _head: Node3D
var _jaw: Node3D
var _tail: MeshInstance3D
var _talons: Node3D
var _shoulders: Array[Node3D] = []
var _wrists: Array[Node3D] = []
var _hands: Array[MeshInstance3D] = []
var _arms: Array[MeshInstance3D] = []

func _init() -> void:
	name = "GuacharoLook"
	_materials()
	_build()

func size_to(span: float) -> void:
	scale = Vector3.ONE*(span*0.5/HALF_SPAN)

func _materials() -> void:
	feather_mat = ShaderMaterial.new()
	feather_mat.shader = SHADER
	body_mat = ShaderMaterial.new()
	body_mat.shader = SHADER
	body_mat.set_shader_parameter("is_body",1.0)
	horn_mat = StandardMaterial3D.new()
	horn_mat.albedo_color = Color(0.2,0.17,0.13)
	horn_mat.roughness = 0.45
	eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.03,0.022,0.018)
	eye_mat.roughness = 0.08
	eye_mat.metallic_specular = 0.9

# --- Building it -----------------------------------------------------------------------

func _build() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_blob(_body,Vector3(0.0,0.0,0.02),Vector3(0.36,0.32,1.0))
	_blob(_body,Vector3(0.0,0.03,-0.4),Vector3(0.25,0.24,0.34))
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0,0.06,-0.52)
	_body.add_child(_head)
	_blob(_head,Vector3(0.0,0.0,-0.04),Vector3(0.25,0.23,0.28))
	# The hooked beak: the upper mandible a cone bent down at its tip, the
	# lower one a shorter cone hinged at the gape.
	var upper := _cone(0.055,0.17,horn_mat)
	upper.rotation = Vector3(-PI*0.5-0.32,0.0,0.0)
	upper.position = Vector3(0.0,0.0,-0.22)
	_head.add_child(upper)
	var hook := _cone(0.022,0.07,horn_mat)
	hook.rotation = Vector3(PI,0.0,0.0)
	hook.position = Vector3(0.0,-0.06,-0.29)
	_head.add_child(hook)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0.0,-0.035,-0.15)
	_head.add_child(_jaw)
	var lower := _cone(0.04,0.13,horn_mat)
	lower.rotation = Vector3(-PI*0.5+0.08,0.0,0.0)
	lower.position = Vector3(0.0,0.0,-0.06)
	_jaw.add_child(lower)
	for side: float in [-1.0,1.0]:
		var eye := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.034
		ball.height = 0.068
		ball.radial_segments = 10
		ball.rings = 6
		eye.mesh = ball
		eye.material_override = eye_mat
		eye.position = Vector3(side*0.085,0.035,-0.13)
		_head.add_child(eye)
	_tail = _mesh(_tail_mesh(),feather_mat)
	_tail.name = "Tail"
	_tail.position = Vector3(0.0,0.02,0.38)
	_body.add_child(_tail)
	_talons = _make_talons()
	_body.add_child(_talons)
	var arm_mesh := _arm_mesh()
	var hand_mesh := _hand_mesh()
	for side: float in [1.0,-1.0]:
		var mirror := Node3D.new()
		mirror.name = "Side%s" % ("R" if side > 0.0 else "L")
		mirror.scale = Vector3(side,1.0,1.0)
		_body.add_child(mirror)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.12,0.07,-0.14)
		mirror.add_child(shoulder)
		var arm := _mesh(arm_mesh,feather_mat)
		shoulder.add_child(arm)
		var wrist := Node3D.new()
		wrist.position = Vector3(0.82,0.0,0.0)
		shoulder.add_child(wrist)
		var hand := _mesh(hand_mesh,feather_mat)
		wrist.add_child(hand)
		_shoulders.append(shoulder)
		_wrists.append(wrist)
		_arms.append(arm)
		_hands.append(hand)
	_set_layers(self)
	drive(REST)

func _set_layers(n: Node) -> void:
	if n is VisualInstance3D: (n as VisualInstance3D).layers = LAYER
	for c in n.get_children(): _set_layers(c)

func _blob(parent: Node3D, at: Vector3, size: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 16
	s.rings = 10
	m.mesh = s
	m.material_override = body_mat
	m.position = at
	m.scale = size
	parent.add_child(m)
	return m

func _cone(radius: float, length: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 8
	c.rings = 1
	m.mesh = c
	m.material_override = mat
	return m

func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	return m

func _make_talons() -> Node3D:
	var holder := Node3D.new()
	holder.name = "Talons"
	holder.position = Vector3(0.0,-0.12,0.1)
	for side: float in [-1.0,1.0]:
		var leg := _cone(0.025,0.26,horn_mat)
		leg.rotation = Vector3(PI,0.0,0.0)
		leg.position = Vector3(side*0.08,-0.13,0.0)
		holder.add_child(leg)
		for k in range(3):
			var claw := _cone(0.014,0.11,horn_mat)
			claw.rotation = Vector3(-PI*0.5-0.6,(float(k)-1.0)*0.45,0.0)
			claw.position = Vector3(side*0.08+(float(k)-1.0)*0.025,-0.27,-0.04)
			holder.add_child(claw)
	return holder

## One feather into `a`: from `base` along `along` (unit) `length` m, `width`
## across `side`, cambered down, its fan pivot at its base (`fan` the turn
## folded), its tint (emarginate, spots, dark tip).
static func _feather(a: Dictionary, base: Vector3, along: Vector3, side: Vector3, length: float, width: float,
		camber: float, fan: float, seed: float, tint: Color) -> void:
	var normal := side.cross(along).normalized()
	if normal.y < 0.0: normal = -normal
	var segs := 4
	var first: int = (a.v as Array).size()
	for i in range(segs+1):
		var t := float(i)/segs
		var mid := base+along*length*t-normal*camber*length*t*t
		for j in range(2):
			var u := float(j)
			(a.v as Array).append(mid+side*width*(u-0.5))
			(a.n as Array).append(normal)
			(a.uv as Array).append(Vector2(u,t))
			(a.c as Array).append(tint)
			(a.cu as Array).append_array([base.x,base.z,fan,seed])
	for i in range(segs):
		var k := first+i*2
		(a.i as Array).append_array([k,k+2,k+1,k+1,k+2,k+3])

static func _arrays() -> Dictionary:
	return {"v":[],"n":[],"uv":[],"c":[],"cu":[],"i":[]}

static func _commit(a: Dictionary) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(a.v)
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(a.n)
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(a.uv)
	arr[Mesh.ARRAY_COLOR] = PackedColorArray(a.c)
	arr[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array(a.cu)
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array(a.i)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh

## The arm: tertials by the body, secondaries along it (backward, +Z), two
## rows of coverts over their bases.
static func _arm_mesh() -> ArrayMesh:
	var a := _arrays()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in range(11):
		var x := -0.04+float(i)*0.082
		var dir := Vector3(0.06+float(i)*0.012,0.0,1.0).normalized()
		var length := (0.7 if i < 2 else 0.62)+rng.randf_range(-0.03,0.03)
		_feather(a,Vector3(x,-0.005,0.0),dir,Vector3(1,0,0),length,0.17,0.08,0.0,rng.randf(),Color(0.0,0.8 if rng.randf() < 0.7 else 0.0,0.7,1.0))
	for row in range(2):
		for i in range(12):
			var x := -0.02+float(i)*0.072
			var dir := Vector3(0.1,0.0,1.0).normalized()
			_feather(a,Vector3(x,0.012+row*0.012,-0.04+row*0.03),dir,Vector3(1,0,0),0.26-row*0.08,0.11,0.12,0.0,rng.randf(),
				Color(0.0,0.9 if row == 0 else 0.5,0.35,1.0))
	return _commit(a)

## The hand: ten primaries fanned from backward (inner) to outward (the
## outer five slotted fingers, the longest), and their coverts. Folded
## (`spread` 0) each turns back about its base to lie along the arm.
static func _hand_mesh() -> ArrayMesh:
	var a := _arrays()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var folded := 1.48
	for i in range(10):
		var t := float(i)/9.0
		var ang := lerpf(1.3,0.16,t)
		var dir := Vector3(cos(ang),0.0,sin(ang))
		var side := Vector3(-dir.z,0.0,dir.x)
		var length := lerpf(0.66,1.0,pow(t,0.8))+rng.randf_range(-0.03,0.03)
		if i == 9: length -= 0.12
		var base := Vector3(0.02+t*0.46,-0.004*float(i),0.02-t*0.02)
		var tint := Color(1.0 if i >= 5 else 0.0,0.6 if i < 7 else 0.0,0.95,1.0)
		_feather(a,base,dir,side,length,lerpf(0.18,0.13,t),0.06,folded-ang,rng.randf(),tint)
	for i in range(8):
		var t := float(i)/7.0
		var ang := lerpf(1.15,0.35,t)
		var dir := Vector3(cos(ang),0.0,sin(ang))
		var side := Vector3(-dir.z,0.0,dir.x)
		_feather(a,Vector3(-0.02+t*0.4,0.015,0.0),dir,side,0.3,0.11,0.1,folded-ang,rng.randf(),Color(0.0,0.9,0.4,1.0))
	return _commit(a)

## The tail: nine long feathers, graduated (the middle longest), fanned.
static func _tail_mesh() -> ArrayMesh:
	var a := _arrays()
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in range(9):
		var t := float(i)/8.0-0.5
		var ang := PI*0.5+t*0.7
		var dir := Vector3(cos(ang),0.0,sin(ang))
		var side := Vector3(-dir.z,0.0,dir.x)
		var length := 0.68-absf(t)*0.3+rng.randf_range(-0.02,0.02)
		_feather(a,Vector3(t*0.06,0.0,0.0),dir,side,length,0.13,0.03,(PI*0.5-ang)*0.8,rng.randf(),Color(0.0,0.0,0.8,1.0))
	return _commit(a)

# --- Posing it ------------------------------------------------------------------------

## Poses the rig: `p`'s keys over REST's.
func drive(p: Dictionary) -> void:
	for k: String in REST:
		pose[k] = float(p.get(k,REST[k]))
	var elev: float = pose.elev
	var sweep: float = pose.sweep
	for i in range(_shoulders.size()):
		_shoulders[i].basis = Basis(Vector3.UP,-sweep)*Basis(Vector3.BACK,elev)*Basis(Vector3.RIGHT,float(pose.twist))
		_wrists[i].basis = Basis(Vector3.UP,-float(pose.wrist))*Basis(Vector3.BACK,float(pose.droop))
		_hands[i].set_instance_shader_parameter("spread",float(pose.spread))
		_arms[i].set_instance_shader_parameter("spread",1.0)
	_tail.set_instance_shader_parameter("spread",float(pose.tail))
	var st: float = pose.stretch
	_body.scale = Vector3(1.0/sqrt(st),1.0/sqrt(st),st)
	_body.rotation = Vector3(float(pose.pitch),0.0,0.0)
	_head.rotation = Vector3(-float(pose.head),0.0,0.0)
	_jaw.rotation = Vector3(-float(pose.jaw)*0.75,0.0,0.0)
	var down: float = pose.talons
	_talons.visible = down > 0.02
	_talons.rotation = Vector3(down*1.1,0.0,0.0)
	_talons.scale = Vector3.ONE*maxf(down,0.02)

## Blends poses `a` and `b` at `t`.
static func mix_pose(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k: String in REST:
		out[k] = lerpf(float(a.get(k,REST[k])),float(b.get(k,REST[k])),t)
	return out

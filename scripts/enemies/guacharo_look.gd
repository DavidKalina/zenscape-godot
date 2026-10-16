extends Node3D
## The guacharo's body: a giant oilbird, the cave bird of the Americas that
## screams in the dark and finds its way by clicks.
##
## The body is assets/models/guacharo.glb (built by
## art/blender/guacharo/guacharo_build.py): a sculpted, rigged oilbird and
## its clips (glide, flap, circle, stalk, scream, fold, stoop, flare, carry,
## pull, hurt). `drive(p)` picks and crossfades them from the mind's state
## (the parent's `state`, `state_t`, `bank`, `_flap_w`, read only), then
## layers procedural corrections on top: the circle clip's bank mirrored to
## the turn and its roll handed back to the mind's bank, the head tracking
## him, the mind's clicks on the head and jaw, and the talons reaching for
## him. Without a mind (a study) it plays `clip`.
##
## If the glb is missing, the old body built in code stands in: an ellipsoid
## body, neck and head, a hooked horn beak, big dark eyes, a long tail and
## two wings of feather quads (shaders/guacharo_feather.gdshader), posed by
## the pose dictionary.
##
## Local frame: -Z forward, +Y up, +X the right wing; the design is
## HALF_SPAN m to a wing tip; `size_to(span)` scales it.
##
## The pose dictionary `drive(p)` takes (any key missing keeps its rest
## value): elev (the wings' rise, rad), sweep (the arm swept back), wrist
## (the hand folded back), droop (the hand bent down), twist, spread (the
## primaries' fan 0..1), tail (the tail's fan 0..1), pitch (nose up, rad),
## head (the head's nod), jaw (0..1 open), talons (0..1 down), stretch (>1
## long and thin, <1 squashed). The glb body reads only `talons` (the flare
## in the stoop); the fallback is posed by all of it.
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

const GLB := "res://assets/models/guacharo.glb"
## The looping clips; the rest are one-shots, played at speed 1 and held on
## their last frame (a longer state only lengthens the hold).
const LOOPS := ["glide","flap","circle","stalk","stoop","carry"]
## Crossfade (s) into each clip.
const BLEND := {"glide":0.4,"flap":0.2,"circle":0.5,"stalk":0.3,"scream":0.06,"fold":0.05,"stoop":0.1,
	"flare":0.04,"carry":0.12,"pull":0.15,"hurt":0.04}
## The circle clip's own bank (left), handed back so the mind's bank is
## the bird's bank.
const CIRCLE_ROLL := 0.384
## The head on him: its weight per state and the most it turns (rad).
const HEAD_AIM := {"home":0.0,"circle":0.4,"stalk":0.9,"fold":0.6,"stoop":0.85,"carry":0.0,"pull":0.2}
const HEAD_MAX := 1.0
## A click: the head dips CLICK_HEAD rad and the beak cracks CLICK_JAW rad,
## CLICK_DOWN s down, then CLICK_BACK s back (the baked clicks are the same
## size: 12 deg, jaw 0.4 x 38 deg).
const CLICK_HEAD := 0.21
const CLICK_JAW := 0.27
const CLICK_DOWN := 0.04
const CLICK_BACK := 0.08
## Each clip's swept box (glb units, CPU-skinned over every frame by
## scratch/guac_extent.gd): the ground lift keeps its lowest corner over
## the ground, and SWEPT_ALL (grown) is the mesh's custom AABB, so a wing
## swung past the rest pose's box is never culled.
const SWEPT := {"carry":[-1.13,1.59,2.11,-0.83,1.23],"circle":[-0.99,1.41,2.15,-0.78,1.18],
	"flap":[-0.86,1.48,2.22,-0.84,1.22],"flare":[-0.51,1.68,1.80,-0.97,1.48],"fold":[-0.42,1.66,0.56,-1.01,1.50],
	"glide":[-0.26,0.20,2.21,-0.81,1.18],"hurt":[-0.38,1.65,2.21,-0.91,1.29],"pull":[-0.86,1.50,2.21,-0.95,1.34],
	"scream":[-0.44,1.65,2.17,-0.72,1.50],"stalk":[-0.48,1.22,2.19,-0.71,1.19],"stoop":[-0.22,0.13,0.61,-0.98,1.37]}
const SWEPT_ALL := AABB(Vector3(-2.45,-1.35,-1.2),Vector3(4.9,3.25,2.95))
## Ground lift: the clearance (m) kept under the bird's lowest point, the
## most it lifts (m) and how fast the lift lets go (m/s).
const GROUND_CLEAR := 0.06
const LIFT_MAX := 1.6
const LIFT_FALL := 2.0
## The point between the eyes in the skeleton's rest frame (the build's
## eye centres, x mirrored to the middle): where the scream's glare sits.
const EYES := Vector3(0.0,0.078,-0.612)

## A clip to play when no mind drives it (studies); "" picks from the mind.
var clip := ""
## The clip playing now (glb body).
var playing := ""
## True when the glb body stands (false: the fallback built in code).
var glb := false

var _model: Node3D
var _ap: AnimationPlayer
var _skel: Skeleton3D
var _bone := {}
var _eyes_local := Vector3.ZERO
var _mirror := false
var _circle_w := 0.0
var _circle_on := false
var _head_w := 0.0
var _talon_w := 0.0
var _click_age := 1.0
var _click_prev := 0.0
var _hurt_t := 0.0
## How far (m) the body is lifted off the ground now.
var lift := 0.0

func _init() -> void:
	name = "GuacharoLook"
	_materials()
	if ResourceLoader.exists(GLB):
		var scene := load(GLB) as PackedScene
		if scene != null: _build_glb(scene)
	if not glb: _build()

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

# --- The glb body ----------------------------------------------------------------------

func _build_glb(scene: PackedScene) -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var g := scene.instantiate() as Node3D
	_model.add_child(g)
	_ap = g.find_child("AnimationPlayer",true,false) as AnimationPlayer
	_skel = g.find_child("Skeleton3D",true,false) as Skeleton3D
	if _ap == null or _skel == null:
		_model.queue_free()
		_model = null
		return
	for n: String in ["head","jaw","neck","thigh.L","thigh.R","toes.L","toes.R"]:
		_bone[n] = _skel.find_bone(n)
	if int(_bone.head) >= 0: _eyes_local = _skel.get_bone_global_rest(int(_bone.head)).affine_inverse()*EYES
	for a: StringName in _ap.get_animation_list():
		_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR if String(a) in LOOPS else Animation.LOOP_NONE
	# Advanced by drive(), so the procedural layers go on after the clip.
	_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for mi: Node in g.find_children("*","MeshInstance3D",true,false):
		(mi as MeshInstance3D).custom_aabb = SWEPT_ALL
	_set_layers(self)
	glb = true
	_play("glide",0.0,1.0)
	_ap.advance(0.0)

func _play(n: String, blend: float, speed: float) -> void:
	if not _ap.has_animation(n): n = "glide"
	if n == playing:
		_ap.speed_scale = speed
		return
	playing = n
	_ap.speed_scale = speed
	_ap.play(n,blend)
	if not n in LOOPS: _ap.seek(0.0,false)

## The point between the eyes (world), riding the head bone through the
## clip, the head aim and the clicks; the fallback body's head otherwise.
func eyes() -> Vector3:
	if glb and int(_bone.get("head",-1)) >= 0:
		return _skel.global_transform*(_skel.get_bone_global_pose(int(_bone.head))*_eyes_local)
	if _head != null: return _head.global_transform*Vector3(0.0,0.035,-0.13)
	return global_position

## A hit: the hurt flinch, over whatever it was doing.
func flinch() -> void:
	if not glb: return
	_hurt_t = _ap.get_animation("hurt").length
	_play("hurt",BLEND.hurt,1.0)

## The clip for the mind's state, and its speed.
func _pick(m: Object) -> Array:
	var st := String(m.get("state"))
	var t := float(m.get("state_t"))
	var flap_w := float(m.get("_flap_w")) if m.get("_flap_w") != null else 0.0
	var bank := float(m.get("bank")) if m.get("bank") != null else 0.0
	var freq := 1.7 if st in ["home","circle"] else (2.4 if st in ["pull","carry"] else 2.0)
	match st:
		"stalk": return ["stalk",1.0]
		"fold":
			var knobs: Variant = m.get("knobs")
			var fold := float((knobs as Dictionary).get("fold",0.95)) if knobs is Dictionary else 0.95
			var consts: Dictionary = (m.get_script() as Script).get_script_constant_map() if m.get_script() else {}
			var scream := float(consts.get("TELL_SCREAM",0.45))
			return ["scream" if t < fold*scream else "fold",1.0]
		"stoop": return ["flare" if float(pose.talons) > 0.3 else "stoop",1.0]
		"carry": return ["carry",freq*0.5]
		"pull": return ["pull",1.0]
	# Riding the air: the beats, else the glide, the circle in a steep bank.
	_circle_on = absf(bank) > (0.15 if _circle_on else 0.25)
	if flap_w > 0.5: return ["flap",freq*0.5]
	return ["circle" if _circle_on else "glide",1.0]

func _drive_glb(dt: float) -> void:
	var m: Node = get_parent()
	var minded := m != null and m.get("state") != null
	var want := [clip,1.0]
	if clip == "" and minded: want = _pick(m)
	elif clip == "": want = ["glide",1.0]
	var n: String = want[0]
	if _hurt_t > 0.0:
		_hurt_t -= dt
		n = "hurt"
	elif n != playing and playing == "flap" and n in ["glide","circle"]:
		# A beat is let finish: back to the glide only at its top.
		var f := _ap.current_animation_position/maxf(_ap.current_animation_length,0.01)
		if f > 0.06 and f < 0.9: n = "flap"
	if n == "circle":
		# The circle clip banks left: mirrored for a right turn. The side is
		# switched only with no circle weight left: a turn the other way
		# rolls out through the glide (BLEND.circle s) and in again, never
		# a flip of the banked pose.
		var right := float(m.get("bank") if minded else 0.0) > 0.0
		if right != _mirror:
			if _circle_w < 0.05: _mirror = right
			else: n = "glide"
	_play(n,float(BLEND.get(n,0.2)),float(want[1]) if n == want[0] else _ap.speed_scale)
	_ap.advance(dt)
	_circle_w = move_toward(_circle_w,1.0 if playing == "circle" else 0.0,dt/BLEND.circle)
	var side := -1.0 if _mirror else 1.0
	_model.scale = Vector3(side,1.0,1.0)
	_model.rotation = Vector3(0.0,0.0,-side*CIRCLE_ROLL*_circle_w)
	_model.position = Vector3.ZERO
	if not minded or not is_inside_tree(): return
	_ground_lift(m,dt)
	var st := String(m.get("state"))
	var target: Variant = m.call("_middle") if m.has_method("_middle") else null
	# The head on him.
	_head_w = move_toward(_head_w,float(HEAD_AIM.get(st,0.0)) if target != null else 0.0,dt*3.0)
	if _head_w > 0.01: _aim_bone(int(_bone.head),"jaw",target,_head_w,HEAD_MAX)
	# The clicks: the mind's clock (`_click_t` restarts on each).
	var ct: Variant = m.get("_click_t")
	if ct != null:
		if st == "stalk" and float(ct) > _click_prev+0.02: _click_age = 0.0
		_click_prev = float(ct)
	_click_age += dt
	var a := 0.0
	if _click_age < CLICK_DOWN: a = _click_age/CLICK_DOWN
	elif _click_age < CLICK_DOWN+CLICK_BACK: a = 1.0-(_click_age-CLICK_DOWN)/CLICK_BACK
	if a > 0.0:
		_dip_bone(int(_bone.head),CLICK_HEAD*a)
		_dip_bone(int(_bone.jaw),CLICK_JAW*a)
	# The talons for him: on the flare at his middle, in the carry at his
	# shoulders under it.
	var talon_to: Variant = null
	if playing == "flare": talon_to = target
	elif playing == "carry" and m.get("motor") != null:
		talon_to = (m.get("motor") as Object).get("feet")+Vector3.UP*float(m.get("unit"))*0.9
	_talon_w = move_toward(_talon_w,0.7 if talon_to != null else 0.0,dt*6.0)
	if _talon_w > 0.01 and talon_to != null:
		for s: String in ["L","R"]:
			_aim_bone(int(_bone["thigh."+s]),"toes."+s,talon_to,_talon_w,0.7)

## Lifts the body (the Model, not the mind) so the playing clip's swept box
## stays over the ground under it: the flap's downstroke, the carry's legs
## and the pull's first beat never sink in, however low the mind flies.
func _ground_lift(m: Node, dt: float) -> void:
	var field: Variant = m.get("field")
	if field == null or not (field as Object).has_method("floor_under"): return
	var box: Array = SWEPT.get(playing,SWEPT.glide)
	var xf := global_transform*Transform3D(_model.basis,Vector3.ZERO)
	var low := INF
	for c in 8:
		var p := Vector3(float(box[2])*(1.0 if c & 1 else -1.0),float(box[1]) if c & 2 else float(box[0]),
			float(box[4]) if c & 4 else float(box[3]))
		low = minf(low,(xf*p).y)
	var o := global_position
	var want := 0.0
	var ground: float = field.floor_under(o,0.5,o.y-low+GROUND_CLEAR+0.5)
	if ground != -INF: want = clampf(ground+GROUND_CLEAR-low,0.0,LIFT_MAX)
	lift = want if want > lift else move_toward(lift,want,dt*LIFT_FALL)
	if lift > 0.001: _model.position = global_basis.inverse()*Vector3.UP*lift

## Turns bone `b` (in the skeleton's frame, over its clip pose) so the line
## from it to bone `tip` swings toward `at` (world), by `w` of the way, at
## most `most` rad.
func _aim_bone(b: int, tip: String, at: Vector3, w: float, most: float) -> void:
	if b < 0 or int(_bone.get(tip,-1)) < 0: return
	var g := _skel.get_bone_global_pose(b)
	var t := _skel.get_bone_global_pose(int(_bone[tip]))
	var fwd := (t.origin-g.origin).normalized()
	var to := ((_skel.global_transform.affine_inverse()*at)-g.origin).normalized()
	var ang := fwd.angle_to(to)
	var axis := fwd.cross(to)
	if ang < 0.001 or axis.length() < 0.0001: return
	_turn_bone(b,Basis(axis.normalized(),minf(ang,most)*w))

## Dips bone `b` (its line nodded toward the skeleton's down) by `ang` rad.
func _dip_bone(b: int, ang: float) -> void:
	if b < 0: return
	var g := _skel.get_bone_global_pose(b)
	var fwd := g.basis.y.normalized()
	var axis := fwd.cross(Vector3.DOWN)
	if axis.length() < 0.001: return
	_turn_bone(b,Basis(axis.normalized(),ang))

func _turn_bone(b: int, r: Basis) -> void:
	var g := _skel.get_bone_global_pose(b)
	var p := _skel.get_bone_parent(b)
	var pg := _skel.get_bone_global_pose(p) if p >= 0 else Transform3D.IDENTITY
	var local := pg.basis.inverse()*(r*g.basis)
	_skel.set_bone_pose_rotation(b,local.get_rotation_quaternion())

# --- Building it (the fallback) ----------------------------------------------------------

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

## Poses it: `p`'s keys over REST's (the glb body plays its clips from
## the mind's state; the fallback is posed by `p`).
func drive(p: Dictionary) -> void:
	for k: String in REST:
		pose[k] = float(p.get(k,REST[k]))
	if glb:
		var dt := get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time()
		_drive_glb(clampf(dt,0.0,0.1))
		return
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

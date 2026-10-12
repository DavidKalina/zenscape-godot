extends "res://scripts/traps/trap.gd"
## The Tumbling Block (the user's idea, docs/design/roguelike/traps-round4-giants.md;
## built to the contract in scripts/traps/trap.gd): a giant stone cube,
## several pilot-heights a side, floating over the drop between two decks and
## rolling slowly about a horizontal axis through its middle (across the
## route, x). Its top moves back toward the entry, so the face he stands on
## tips away from the way out: he is carried round with it (`motor.carry`
## with the block's own transform delta, rotation and all) and slid down the
## tilt (`slip`, m/s at a sheer fall: the friction feel); past the motor's
## own slide angle he cannot stand at all. To stay on top he keeps walking
## "uphill" (-z, the way out), and as a face goes steep he steps or jumps to
## the next one coming up, or grabs its lip and climbs (the motor's ledge,
## wall slide and wall kick work on the block's faces as on any stone).
## Left alone he is walked off the back.
##
## Four faces round the axis, each with greybox ruin features that rotate
## into him: 0 a low wall to stand on or hide behind, 1 a raised step over
## half the face, 2 a trench across it (a jump), 3 two low walls. The ends
## are plain walls (wall kick). The edges are bevelled (`bevel`), so the
## step from one face to the next is a hop and not a knife-edge; 0 makes it
## a true cube.
##
## It can run continuous (`pause` 0) or turn 90 degrees at a time with a
## `pause` s between. Optional: `yaw` (rad/s), a slow turn about the
## vertical as well, a later tier.
##
## The tell: the face about to come up warms to orange; with a pause, the
## whole block warms in the last part of it and a `grind` sounds as each
## turn starts. Cost 4, over the void 5.
##
## Sizes from the pilot: `size` 4.5 of his heights (the body's HEAD x the
## wanderer's size), `spin` so that the walk it asks to keep station at its
## worst is `spin_walk` x his walk, `gap` a share of a running small hop's
## reach, features from his jumps, the trench from his run.
## Knobs: `size`, `plate`, `bevel`, `spin` (rad/s), `dir` (+1 the top moves
## back toward the entry, -1 toward the exit), `pause` (s, 0 continuous),
## `yaw` (rad/s), `gap`, `top` (the flat top's height over the decks),
## `slip`, `wall_h`, `step_h`, `trench`, `tell`.
const Ground = preload("res://scripts/pilot_physics_ground.gd")
const STONES := [Color(0.42,0.41,0.4),Color(0.46,0.43,0.38),Color(0.38,0.41,0.43),Color(0.43,0.39,0.41)]
const REACH_SHARE := 0.6
const SPIN_WALK := 0.6

var body: StaticBody3D
## The block's turn about its axis (x), its yaw, and where in the pause it is.
var roll := 0.0
var yaw := 0.0
var _turned := 0.0
var _pausing := 0.0
var _plate_mats: Array[StandardMaterial3D] = []
var _all_mats: Array[StandardMaterial3D] = []
var _grind_t := 0.0
## Seconds he has been on it, and the longest stretch.
var riding_time := 0.0

func _init() -> void:
	super()
	trap_name = "tumble"
	cost = 4
	under = "void"
	verbs = PackedStringArray(["jump","walk","climb"])

func defaults() -> Dictionary:
	var p := pilot()
	var height: float = Ground.HEAD*WorldScale.wanderer
	var size := height*4.5
	var reach := p.run*2.0*sqrt(2.0*p.jumps[0]/p.gravity)
	return {
		"size":size,"plate":0.6,"bevel":size*0.2,
		"spin":SPIN_WALK*p.walk/size,"dir":1.0,"pause":0.0,"yaw":0.0,
		"gap":reach*REACH_SHARE,"top":0.0,
		"slip":p.walk*0.9,
		"wall_h":p.jumps[0]*0.7,"step_h":p.jumps[0]*0.9,"trench":p.run*0.25,
		"tell":0.8,
	}

func length() -> float:
	return float(knob("size"))+2.0*float(knob("gap"))

func footprint() -> Rect2:
	var s := float(knob("size"))
	return Rect2(-s*0.5,-length(),s,length())

## The block's centre in the trap's frame.
func centre() -> Vector3:
	return Vector3(0.0,float(knob("top"))-float(knob("size"))*0.5,-(float(knob("gap"))+float(knob("size"))*0.5))

## Where the middle of the flat top is (world), at roll 0.
func top_point() -> Vector3:
	return to_global(centre()+Vector3(0.0,float(knob("size"))*0.5,0.0))

## One box of the block, in face `k`'s frame (face-local centre and size).
func _box(centre_l: Vector3, size: Vector3, k: int, mat: StandardMaterial3D, turn := 0.0) -> void:
	var basis := Basis(Vector3.RIGHT,float(k)*PI*0.5)*Basis(Vector3.RIGHT,turn)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = Transform3D(basis,Basis(Vector3.RIGHT,float(k)*PI*0.5)*centre_l)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.transform = shape.transform
	mesh.material_override = mat
	body.add_child(mesh)

func _mat(colour: Color, plate := false) -> StandardMaterial3D:
	var m := paint(colour)
	_all_mats.append(m)
	if plate: _plate_mats.append(m)
	return m

func build() -> void:
	body = StaticBody3D.new()
	body.transform = Transform3D(Basis.IDENTITY,centre())
	add_child(body)
	var s := float(knob("size"))
	var half := s*0.5
	var pl := float(knob("plate"))
	var bev := clampf(float(knob("bevel")),0.0,pl*2.0)
	var long := s-2.0*bev
	# The core: the cube less its plates, full width across the axis.
	var core := paint(Color(0.3,0.3,0.32))
	var cshape := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(s,s-2.0*pl,s-2.0*pl)
	cshape.shape = cbox
	body.add_child(cshape)
	var cmesh := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	cbm.size = cbox.size
	cmesh.mesh = cbm
	cmesh.material_override = core
	body.add_child(cmesh)
	var wall_h := float(knob("wall_h"))
	var step_h := float(knob("step_h"))
	var trench := float(knob("trench"))
	for k in range(4):
		var m := _mat(STONES[k],true)
		var ruin := _mat(STONES[k].darkened(0.2))
		# Plate: whole, or two with a trench between.
		if k == 2:
			var at := s*0.1
			var back := (half-bev)-(at+trench*0.5)
			var front := (at-trench*0.5)+(half-bev)
			_box(Vector3(0.0,half-pl*0.5,at+trench*0.5+back*0.5),Vector3(s,pl,back),k,m)
			_box(Vector3(0.0,half-pl*0.5,-(half-bev)+front*0.5),Vector3(s,pl,front),k,m)
		else:
			_box(Vector3(0.0,half-pl*0.5,0.0),Vector3(s,pl,long),k,m)
		# The bevel toward the next face: a 45 degree slab across the edge.
		if bev > 0.0:
			var w := bev*sqrt(2.0)
			_box(Vector3(0.0,half-bev*0.5-pl*0.35,half-bev*0.5-pl*0.35),Vector3(s,pl,w),k,m,PI*0.25)
		match k:
			0: _box(Vector3(0.0,half+wall_h*0.5,half*0.3),Vector3(s*0.7,wall_h,0.4),k,ruin)
			1: _box(Vector3(0.0,half+step_h*0.5,-(half-bev)*0.5),Vector3(s,step_h,half-bev),k,ruin)
			3:
				_box(Vector3(0.0,half+wall_h*0.5,half*0.5),Vector3(s*0.5,wall_h,0.4),k,ruin)
				_box(Vector3(0.0,half+wall_h*0.5,-half*0.5),Vector3(s*0.5,wall_h,0.4),k,ruin)
	_pose()

## The block's pose: roll about x, then yaw, at its centre.
func _transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,roll),centre())

func _pose() -> void:
	if body != null: body.transform = _transform()

## Is `feet` (world) on the block: near its outside, in its own frame?
func on_block(feet: Vector3) -> bool:
	var l := _transform().affine_inverse()*to_local(feet)
	var half := float(knob("size"))*0.5
	var m := maxf(absf(l.x),maxf(absf(l.y),absf(l.z)))
	return absf(l.x) <= half+0.2 and absf(l.y) <= half+1.0 and absf(l.z) <= half+1.0 and m >= half-0.8 and m <= half+1.0

## The surface normal under the feet (world): the block's nearest face axis.
func normal_at(feet: Vector3) -> Vector3:
	var t := _transform()
	var l := t.affine_inverse()*to_local(feet)
	var n := Vector3.ZERO
	if absf(l.y) >= absf(l.z): n.y = signf(l.y)
	else: n.z = signf(l.z)
	return global_transform.basis*(t.basis*n)

## The face on top and its tilt (rad, 0 flat).
func top_tilt() -> float:
	var a := fposmod(roll+PI*0.25,PI*0.5)-PI*0.25
	return a

func _advance(delta: float) -> void:
	var w := float(knob("spin"))*float(knob("dir"))
	var pause := float(knob("pause"))
	if pause <= 0.0:
		roll += w*delta
		_turned += absf(w)*delta
		if _turned >= PI*0.5:
			_turned -= PI*0.5
			tell_sound(&"grind",to_global(centre()))
	else:
		if _pausing > 0.0:
			_pausing -= delta
			if _pausing <= 0.0: tell_sound(&"grind",to_global(centre()))
		else:
			var step := w*delta
			var left := PI*0.5-_turned
			if absf(step) >= left:
				step = signf(w)*left
				_pausing = pause
				_turned = 0.0
			else:
				_turned += absf(step)
			roll += step
	yaw += float(knob("yaw"))*delta
	roll = fposmod(roll+PI,TAU)-PI

func before(delta: float) -> void:
	if body == null or delta <= 0.0: return
	var riding := motor != null and motor.rider == null and not motor.swimming and (motor.grounded or motor.on_ledge()) and on_block(motor.feet)
	var was := _transform()
	_advance(delta)
	_pose()
	if riding:
		riding_time += delta
		var moved := global_transform*(_transform()*was.affine_inverse())*global_transform.affine_inverse()
		motor.carry(moved,0.0)
		# Down the face's tilt.
		var n := normal_at(motor.feet)
		var dir := Vector3(n.x,0.0,n.z)
		if n.y > 0.2 and dir.length() > 0.01:
			motor.carry(Transform3D(Basis.IDENTITY,dir*float(knob("slip"))*delta),0.0)
	_tell()

## The face about to come up warms; with a pause, the whole block in its last part.
func _tell() -> void:
	var loud := 0.0
	var pause := float(knob("pause"))
	if pause > 0.0 and _pausing > 0.0:
		loud = clampf(1.0-_pausing/minf(float(knob("tell")),pause),0.0,1.0)
	var w := float(knob("spin"))*float(knob("dir"))
	for k in range(_plate_mats.size()):
		var a := fposmod(roll+float(k)*PI*0.5+PI,TAU)-PI
		var share := loud
		# Rising (heading for the top) and nearly there.
		if a*w < 0.0 and absf(a) >= PI*0.25 and absf(a) < PI*0.25+0.4:
			share = maxf(share,1.0-(absf(a)-PI*0.25)/0.4)
		_plate_mats[k].albedo_color = STONES[k].lerp(TELL,share)
	tell_sight(loud)

func reset() -> void:
	super()
	roll = 0.0
	yaw = 0.0
	_turned = 0.0
	_pausing = 0.0
	riding_time = 0.0
	_pose()

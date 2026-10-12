extends "res://scripts/traps/trap.gd"
## The Sky Ray (the user's idea, a Mario Sunshine sand bird; docs/design/
## roguelike/traps-round4-giants.md; built to the contract in scripts/traps/
## trap.gd): a broad flat creature, greybox, that flies a closed loop (a
## stadium: two straights joined by two turns) round the lane at a steady
## pace, banking into the turns and pitching on the climb and dive of a hump
## over the far half. Its back is a slab with two raised ridges. The pilot
## boards from the deck's east edge as it passes (the near straight runs
## beside both decks, level with them), is carried with it (`motor.carry`
## with its full transform delta, so the bank and pitch swing him round, no
## teleport), and gets off at the far deck as it passes again. Tilted, its
## back pushes him down the slope toward the low edge (`slip`, m/s at a
## sheer fall: the friction feel); he shifts uphill to hold his place.
##
## The tells: its head dips before a dive, and its wing edge lifts (and
## warms to orange) before a bank, both `tell` seconds ahead; a `whoosh`
## sounds as a bank starts and a `screech` as the dive does. `shake` (rad)
## is a wobble about its length that tries to shed a rider (0 off).
## Cost 4, over the void 5.
##
## Sizes from the pilot and his heights: `width` 6 of them, `long` 8,
## `speed` his run, `slip` his walk x 0.9, `radius` the turn's, `bank` max
## 26 degrees, `height` the hump. Knobs: `width`, `long`, `thick`, `speed`,
## `radius`, `height`, `max_bank`, `max_pitch`, `bank_lag` (s the bank takes
## to settle), `slip`, `shake`, `tell`, `ride` (m of the route he rides),
## `edge_x` (the deck's east edge), `gap` (between it and the ray's side),
## `lead_in`/`lead_out` (m the straight runs past the decks).
const Ground = preload("res://scripts/pilot_physics_ground.gd")
const SKIN := Color(0.42,0.41,0.4)
const RIDGE := Color(0.5,0.46,0.4)
const WING := Color(0.36,0.4,0.46)
const HEAD_COLOUR := Color(0.33,0.36,0.4)
const REACH_SHARE := 0.45

var body: StaticBody3D
var head: MeshInstance3D
var wing_l: MeshInstance3D
var wing_r: MeshInstance3D
var wing_mats: Array[StandardMaterial3D] = []
## Distance flown along the loop (m), the bank now (rad), the clock.
var s := 0.0
var bank := 0.0
var clock := 0.0
var pitch := 0.0
var _whoosh_ready := true
var _screech_ready := true
var riding_time := 0.0

func _init() -> void:
	super()
	trap_name = "ray"
	cost = 4
	under = "void"
	verbs = PackedStringArray(["jump","balance"])

func defaults() -> Dictionary:
	var p := pilot()
	var height: float = Ground.HEAD*WorldScale.wanderer
	var reach := p.run*2.0*sqrt(2.0*p.jumps[0]/p.gravity)
	return {
		"width":height*6.0,"long":height*8.0,"thick":0.8,
		"speed":p.run,"radius":height*7.5,"height":height*7.0,
		"max_bank":0.45,"max_pitch":0.35,"bank_lag":0.5,
		"slip":p.walk*0.9,"shake":0.0,"tell":1.0,
		"ride":height*20.0,"edge_x":5.0,"gap":reach*REACH_SHARE,
		"lead_in":10.0,"lead_out":10.0,
	}

func length() -> float:
	return float(knob("ride"))

## Room the loop takes to the east of the lane (m past the deck's edge),
## for a yard that lays lanes side by side.
func lane_extra() -> float:
	return float(knob("gap"))+float(knob("width"))+2.0*float(knob("radius"))

# ---- the path: a stadium in x z; the straights run along z ----

## x of the west straight (the ray's middle line).
func line_x() -> float:
	return float(knob("edge_x"))+float(knob("gap"))+float(knob("width"))*0.5

func _z_north() -> float:
	return float(knob("lead_in"))

func _z_south() -> float:
	return -(float(knob("ride"))+float(knob("lead_out")))

func straight() -> float:
	return _z_north()-_z_south()

func loop_length() -> float:
	return 2.0*straight()+2.0*PI*float(knob("radius"))

## Position on the loop at distance `d` (local, y the hump).
func path_at(d: float) -> Vector3:
	var total := loop_length()
	d = fposmod(d,total)
	var r := float(knob("radius"))
	var leg := straight()
	var x0 := line_x()
	var out := Vector3.ZERO
	var semi := PI*r
	if d < leg:
		out = Vector3(x0,0.0,_z_north()-d)
	elif d < leg+semi:
		var phi := (d-leg)/r
		out = Vector3(x0+r-r*cos(phi),0.0,_z_south()-r*sin(phi))
	elif d < 2.0*leg+semi:
		out = Vector3(x0+2.0*r,0.0,_z_south()+(d-leg-semi))
	else:
		var phi := (d-2.0*leg-semi)/r
		out = Vector3(x0+r+r*cos(phi),0.0,_z_north()+r*sin(phi))
	out.y = _hump(d)
	return out

## The hump over the far half (smooth, level on the near straight).
func _hump(d: float) -> float:
	var leg := straight()
	var total := loop_length()
	if d < leg: return 0.0
	var u := (d-leg)/(total-leg)
	var sn := sin(PI*u)
	return float(knob("height"))*sn*sn

## Turn rate of the heading at `d`: 0 straight, -1/r a right turn (the loop's).
func curvature_at(d: float) -> float:
	d = fposmod(d,loop_length())
	var leg := straight()
	var semi := PI*float(knob("radius"))
	if (d >= leg and d < leg+semi) or d >= 2.0*leg+semi: return -1.0/float(knob("radius"))
	return 0.0

func _heading(d: float) -> float:
	var a := path_at(d)
	var b := path_at(d+0.5)
	return atan2(-(b.x-a.x),-(b.z-a.z))

func _slope(d: float) -> float:
	var a := path_at(d)
	var b := path_at(d+0.5)
	var run := Vector2(b.x-a.x,b.z-a.z).length()
	return atan2(b.y-a.y,maxf(run,0.001))

func build() -> void:
	var w := float(knob("width"))
	var l := float(knob("long"))
	var th := float(knob("thick"))
	body = StaticBody3D.new()
	add_child(body)
	_add(Vector3(0.0,-th*0.5,0.0),Vector3(w,th,l),paint(SKIN),true)
	# Two ridges on its back.
	var rh: float = pilot().jumps[0]*0.7
	_add(Vector3(-w*0.22,rh*0.5,l*0.22),Vector3(w*0.22,rh,1.0),paint(RIDGE),true)
	_add(Vector3(w*0.22,rh*0.5,-l*0.12),Vector3(w*0.22,rh,1.0),paint(RIDGE),true)
	# The head (it dips), a tail, and the wing edges (they lift).
	head = _add(Vector3(0.0,-th*0.5,-l*0.5-0.9),Vector3(w*0.3,th*0.8,1.8),paint(HEAD_COLOUR),false)
	_add(Vector3(0.0,-th*0.5,l*0.5+1.4),Vector3(0.4,th*0.5,2.8),paint(HEAD_COLOUR),false)
	for side in [-1.0,1.0]:
		var m := paint(WING)
		wing_mats.append(m)
		var wing := _add(Vector3(side*(w*0.5+0.5),-th*0.5,0.0),Vector3(1.0,th*0.4,l*0.8),m,false)
		if side < 0.0: wing_l = wing
		else: wing_r = wing
	_pose()

## A box of the creature: with collision if `solid`.
func _add(at: Vector3, size: Vector3, mat: StandardMaterial3D, solid: bool) -> MeshInstance3D:
	if solid:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = at
		body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.position = at
	mesh.material_override = mat
	body.add_child(mesh)
	return mesh

func _transform() -> Transform3D:
	var p := path_at(s)
	var ptch := clampf(_slope(s),-float(knob("max_pitch")),float(knob("max_pitch")))
	pitch = ptch
	var wobble := 0.0
	if float(knob("shake")) > 0.0: wobble = float(knob("shake"))*sin(clock*2.3)
	var basis := Basis(Vector3.UP,_heading(s))*Basis(Vector3.RIGHT,ptch)*Basis(Vector3(0.0,0.0,1.0),bank+wobble)
	return Transform3D(basis,p)

func _pose() -> void:
	if body != null: body.transform = _transform()

## Is `feet` (world) on its back (grounded there)?
func on_back(feet: Vector3) -> bool:
	var l := body.transform.affine_inverse()*to_local(feet)
	return absf(l.x) <= float(knob("width"))*0.5+0.1 and absf(l.z) <= float(knob("long"))*0.5+0.1 and l.y >= -0.3 and l.y <= pilot().jumps[0]*0.7+0.4

func _bank_target() -> float:
	# Early by the lag, so the bank is in when the turn is.
	var ahead := float(knob("speed"))*float(knob("bank_lag"))
	var k := curvature_at(s+ahead)*float(knob("radius"))
	return -k*float(knob("max_bank"))

func before(delta: float) -> void:
	if body == null or delta <= 0.0: return
	var riding := motor != null and motor.rider == null and not motor.swimming and (motor.grounded or motor.on_ledge()) and on_back(motor.feet)
	var was := body.transform
	clock += delta
	s += float(knob("speed"))*delta
	var lag := maxf(float(knob("bank_lag")),0.05)
	bank += (_bank_target()-bank)*(1.0-exp(-delta/lag))
	_pose()
	if riding:
		riding_time += delta
		var moved := global_transform*(body.transform*was.affine_inverse())*global_transform.affine_inverse()
		motor.carry(moved,0.0)
		# Down the back's tilt, toward the low edge.
		var n := global_transform.basis*(body.transform.basis*Vector3.UP)
		var dir := Vector3(n.x,0.0,n.z)
		if n.y > 0.2:
			motor.carry(Transform3D(Basis.IDENTITY,dir*float(knob("slip"))*delta),0.0)
	_tells()

## Head down before a dive, a wing edge up before a bank.
func _tells() -> void:
	var lead := float(knob("speed"))*float(knob("tell"))
	var ahead_pitch := _slope(s+lead)
	var dive := clampf(-(ahead_pitch)/float(knob("max_pitch")),0.0,1.0) if _slope(s) > ahead_pitch+0.02 else 0.0
	head.rotation.x = -dive*0.6
	head.position.y = -float(knob("thick"))*0.5-dive*0.5
	var k := curvature_at(s+lead)*float(knob("radius"))
	# Right turn (k < 0): the left wing (the outside) lifts.
	var lift := clampf(absf(k),0.0,1.0) if bank_ahead(k) else 0.0
	var outer: MeshInstance3D = wing_l if k < 0.0 else wing_r
	for wing: MeshInstance3D in [wing_l,wing_r]:
		var up := lift if wing == outer else 0.0
		wing.rotation.z = up*0.5*(1.0 if wing == wing_r else -1.0)
		wing.position.y = -float(knob("thick"))*0.5+up*0.5
	wing_mats[0].albedo_color = WING.lerp(TELL,lift if outer == wing_l else 0.0)
	wing_mats[1].albedo_color = WING.lerp(TELL,lift if outer == wing_r else 0.0)
	if lift > 0.5 and _whoosh_ready:
		_whoosh_ready = false
		tell_sound(&"whoosh",to_global(body.position))
	elif lift < 0.1: _whoosh_ready = true
	if dive > 0.5 and _screech_ready:
		_screech_ready = false
		tell_sound(&"screech",to_global(body.position))
	elif dive < 0.1: _screech_ready = true
	tell_sight(maxf(lift,dive))

func bank_ahead(k: float) -> bool:
	return absf(k) > 0.01 and absf(bank) < float(knob("max_bank"))*0.9

func reset() -> void:
	super()
	s = 0.0
	bank = 0.0
	clock = 0.0
	riding_time = 0.0
	_whoosh_ready = true
	_screech_ready = true
	_pose()

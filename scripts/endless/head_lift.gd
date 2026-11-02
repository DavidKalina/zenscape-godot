extends Node3D
## The head the stomper lifts (docs/design/endless-flight/head-lift-handoff.md): a
## prototype. One 55 m head at one site on his route. When the plane comes near he
## stops, stoops, takes it by the ears, raises it to his chest and holds it turned,
## its glowing stump to the run-in. A surge roll breaks the plate on the stump and
## the plane flies a straight bore out through one socket, past a find in the
## middle. He sets it down, and while the plane stays near he lifts it again; it
## gone, he walks on. Coming back he's put at the site again, out of sight if he can
## be (`_arrive`).
##
## Its solid is the pirate ship's way: records in LandArches `loose`, whose pos, cos
## and sin are rewritten each frame, and a StaticBody on layer 1 for the wing rays.
## Records turn on y only, so the model's tilt is baked into the boxes
## (art/blender/giant_ruins/lift_head.py, assets/models/giants/lift_head.json) for
## the hold alone. Off the hold it's a round lump (LUMP), which any tilt fits.
##
##   setup(study, stomper)   stands it at the site
##   step(delta)             the lift, one frame; called by the stomper
##   stops_him()             he's standing for it
##   again()                 U: at the site, lifting now
##   way_off(p)              out of the bore's wall, for FlightContact, or ZERO
##   debug_start(host)       --head-lift-start

const LaunchArgs = preload("res://scripts/launch_args.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const PirateShip = preload("res://scripts/endless/pirate_ship.gd")
const Pose = preload("res://scripts/endless/stomper_lift_pose.gd")

const MODEL := "res://assets/models/giants/lift_head.glb"
const DATA := "res://assets/models/giants/lift_head.json"
const HANDLE := "amber/lift-head"
## Where it happens: how far along his loop he stands for it (m), the straight at
## the west end of the plain, flat a kilometre to both sides.
const SITE_S := 2320.0
## In his frame (x right, y up, -z ahead, from his feet' ground): the head at rest
## out of his way, and held, straight out from his chest. The bore's way runs across
## him, left to right, on the head's far side, with both arms behind it.
const REST_AT := Vector3(-105.0,0.0,-100.0)
const HOLD_AT := Vector3(0.0,140.0,-115.0)
## The head's middle over its stump (m).
const STANDS := 27.2
## The timings (s): stoop, take hold, raise, hold (least, most), lower, let go, stand.
const STOOP_S := 5.0
const GRASP_S := 1.5
const RAISE_S := 7.0
const HOLD_LEAST := 8.0
const HOLD_MOST := 40.0
const LOWER_S := 6.0
const LETGO_S := 1.5
const RISE_S := 4.0
## The pose: bent to the ground and at the hold (rad), the drop of his hips (m), the
## back's turn to the head at rest and held (rad).
const LOW_BACK := 1.12
const HOLD_BACK := 0.22
const CROUCH := 34.0
const LOW_TURN := 0.42
const HOLD_TURN := 0.0
## His wrists on the back of the skull, carried frame (m); z each way along the bore,
## the left hand's on the run-in's side.
const GRIP := Vector3(40.0,6.0,20.0)
## Plane to head (m): he's put at the site unseen inside FAR, seen or not inside
## TRIGGER, where he starts; past LEFT a lift is over and he walks on; inside
## STAY he lifts it again without walking.
const FAR := 2300.0
const TRIGGER := 1500.0
const LEFT := 2200.0
const STAY := 1100.0
## After the plane's through: how long it's held on (s), how far past it's through (m).
const AFTER_S := 4.0
const PAST := 40.0
## The hold's slow sway (m, s).
const SWAY := Vector2(1.5,7.0)
## --head-lift-start: how far out on the line, the speed, ticks held (least, most).
const START_OUT := 1750.0
const START_SPEED := 54.0
const START_LEAST := 90
const START_MOST := 360
## The plate: its colour, glow and how far it stands off the way's edge (m).
const PLATE_C := Color(1.0,0.56,0.18)
const PLATE_GLOW := 2.6
const PLATE_LIP := 2.5
const STONE_C := Color(0.62,0.56,0.48)
## The lump: (half height off the middle, half width) a box.
const LUMP := [Vector2(9.0,29.0),Vector2(20.0,23.0),Vector2(29.0,12.0)]

enum {WALK,WAIT,STOOP,GRASP,RAISE,HOLD,LOWER,LETGO,RISE}

signal broke
var state := WALK
## Seconds in this state, the head's way from rest (0) to held (1).
var t := 0.0
var raised := 0.0
var open := false
## Counted, for the drivers.
var lifts := 0
var hops := 0
var breaks := 0
var game: Node3D
var stomper: Node3D
var pose: SkeletonModifier3D
var refill := false
var plate_record := {}
var shell_record := {}
var lump_record := {}
## The line through the bore, carried frame.
var entry := Vector3.ZERO
var socket := Vector3.ZERO
var way_wide := 0.0
var _model: Node3D
var _plate: Node3D
var _light: OmniLight3D
var _shell_body: StaticBody3D
var _lump_body: StaticBody3D
var _middle: Node3D
var _rest_turn := Basis.IDENTITY
var _hold_turn := Basis.IDENTITY
var _grip: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _frame := Transform3D.IDENTITY
var _rest := Vector3.ZERO
var _hold := Vector3.ZERO
var _inv := Transform3D.IDENTITY
var _yaw := 0.0
var _held := 0.0
var _through := -1.0
var _start_held := 0
var _sway := 0.0

static func wanted() -> bool:
	return not "--head-lift=0" in LaunchArgs.user_args()

func setup(study: Node3D, him: Node3D) -> void:
	game = study
	stomper = him
	name = "HeadLift"
	top_level = true
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var c: Array = data.turn
	_hold_turn = Basis(Vector3(c[0],c[1],c[2]),Vector3(c[3],c[4],c[5]),Vector3(c[6],c[7],c[8])).orthonormalized()
	_grip = [_hold_turn.inverse()*GRIP,_hold_turn.inverse()*(GRIP*Vector3(1.0,1.0,-1.0))]
	var from: Array = data.entry
	var to: Array = data.socket
	entry = _hold_turn*Vector3(from[0],from[1],from[2])
	socket = _hold_turn*Vector3(to[0],to[1],to[2])
	way_wide = WorldScale.opening(float(data.toy_way))
	# The site: his frame there. The head's own carries the bore's way.
	var at: Vector2 = him.route.at(SITE_S)
	var dir: Vector2 = him.route.way(SITE_S)
	var turn := atan2(-dir.x,-dir.y)
	_frame = Transform3D(Basis(Vector3.UP,turn),Vector3(at.x,float(him.field.height(at.x,at.y)),at.y))
	_frame = LayoutOverrides.xform(HANDLE,_frame)
	_rest = _frame*REST_AT
	_rest.y = float(him.field.height(_rest.x,_rest.z))+STANDS
	_hold = _frame*HOLD_AT
	_yaw = turn-PI*0.5
	_rest_turn = Basis(Vector3.UP,-(_yaw-turn)+PI)
	transform = Transform3D(Basis(Vector3.UP,_yaw),_rest)
	_inv = transform.affine_inverse()
	_build(data)
	_place()
	refill = _started()
	pose = Pose.new()
	him.skeleton.add_child(pose)
	pose.bind(him.skeleton)

func _started() -> bool:
	return "--head-lift-start" in LaunchArgs.user_args()

## Standing for it, not walking.
func stops_him() -> bool:
	return state != WALK

## U: he's at the site and lifting, whatever he was at.
func again() -> void:
	if state == HOLD: _solid_held(false)
	_put_him()
	_begin()

func _begin() -> void:
	state = STOOP
	t = 0.0
	lifts += 1
	_reset()

## The plate back, the find back and, on a charged run, the meter.
func _reset() -> void:
	raised = 0.0
	_through = -1.0
	if open:
		open = false
		_plate.visible = true
		_light.visible = true
	if refill: game.near.meter = 1.0
	var finds: Node = game.get("finds")
	if finds != null: finds.unfind(HANDLE.get_file())

func _put_him() -> void:
	if not stomper.stands_for_lift(SITE_S): return
	hops += 1

## On the way in he's put at the site, out of the plane's sight if it can be.
func _arrive(d: float) -> void:
	if state != WALK: return
	var eye: Vector3 = game.camera.global_position
	var look: Vector3 = -game.camera.global_basis.z
	var body: Vector3 = stomper.position+Vector3.UP*120.0
	if d < TRIGGER or (d < FAR and PirateShip.unseen(body,eye,look)):
		_put_him()
		state = WAIT
		t = 0.0

func step(delta: float) -> void:
	var p: Vector3 = game.plane.position
	var d: float = p.distance_to(_hold)
	t += delta
	match state:
		WALK: _arrive(d)
		WAIT:
			if d < TRIGGER: _begin()
			elif d > LEFT: state = WALK
		STOOP:
			if t >= STOOP_S: _go(GRASP)
		GRASP:
			if t >= GRASP_S: _go(RAISE)
		RAISE:
			if t >= RAISE_S:
				_go(HOLD)
				_solid_held(true)
		HOLD:
			_watch_through(delta)
			if ((_through >= AFTER_S or d > LEFT) and t >= HOLD_LEAST) or t >= HOLD_MOST:
				_solid_held(false)
				_go(LOWER)
		LOWER:
			if t >= LOWER_S: _go(LETGO)
		LETGO:
			if t >= LETGO_S: _go(RISE)
		RISE:
			if t >= RISE_S:
				if d < STAY: _begin()
				else: state = WALK
	_sway += delta
	_animate()
	_place()

func _go(next: int) -> void:
	state = next
	t = 0.0

## Time runs from when it's passed through, or left behind, or the plane's down.
func _watch_through(delta: float) -> void:
	if _through >= 0.0:
		_through += delta
		return
	var l: Vector3 = _carried(game.plane.position)
	var away: bool = l.z < socket.z-PAST
	if (open and away) or int(game.contact.crashes) > _held: _through = 0.0

## The world's point in the head's carried frame.
func _carried(p: Vector3) -> Vector3:
	return _inv*p

func _s(e: float) -> float:
	return smoothstep(0.0,1.0,e)

## This frame's pose from the state.
func _animate() -> void:
	var back := 0.0
	var turn := 0.0
	var arms := 0.0
	var crouch := 0.0
	match state:
		STOOP:
			var k := _s(t/STOOP_S)
			back = LOW_BACK*k
			turn = LOW_TURN*k
			crouch = CROUCH*k
			arms = 0.7*k
		GRASP:
			back = LOW_BACK
			turn = LOW_TURN
			crouch = CROUCH
			arms = lerpf(0.7,1.0,_s(t/GRASP_S))
		RAISE:
			var k := _s(t/RAISE_S)
			raised = k
			back = lerpf(LOW_BACK,HOLD_BACK,k)
			turn = lerpf(LOW_TURN,HOLD_TURN,k)
			crouch = CROUCH*(1.0-k)
			arms = 1.0
		HOLD:
			raised = 1.0
			back = HOLD_BACK
			turn = HOLD_TURN
			arms = 1.0
		LOWER:
			var k := _s(t/LOWER_S)
			raised = 1.0-k
			back = lerpf(HOLD_BACK,LOW_BACK,k)
			turn = lerpf(HOLD_TURN,LOW_TURN,k)
			crouch = CROUCH*k
			arms = 1.0
		LETGO:
			raised = 0.0
			back = LOW_BACK
			turn = LOW_TURN
			crouch = CROUCH
			arms = lerpf(1.0,0.7,_s(t/LETGO_S))
		RISE:
			var k := 1.0-_s(t/RISE_S)
			back = LOW_BACK*k
			turn = LOW_TURN*k
			crouch = CROUCH*k
			arms = 0.7*k
	stomper.crouch = crouch
	pose.stoop = back
	pose.twist = turn
	pose.arms = arms

func _place() -> void:
	var sway := Vector3(0.0,sin(TAU*_sway/SWAY.y)*SWAY.x,0.0)*raised
	# Up first, the turn over the second half of the rise, in sight of the run-in.
	var up := _s(clampf(raised*1.4,0.0,1.0))
	position = _rest.lerp(_hold,up)+sway
	var k := _s(clampf(raised*2.0-1.0,0.0,1.0))
	_model.basis = Basis(_rest_turn.get_rotation_quaternion().slerp(_hold_turn.get_rotation_quaternion(),k))
	_inv = transform.affine_inverse()
	for r: Dictionary in [plate_record,shell_record,lump_record]:
		r.pos = position
		r.cos = cos(_yaw)
		r.sin = sin(_yaw)
	if pose != null:
		var b := transform.basis*_model.basis
		for side in range(2): pose.goals[side] = position+b*_grip[side]

## The hold's solid (shell, plate) or the lump's.
func _solid_held(on: bool) -> void:
	var loose: Array = game.arches.loose
	_held = int(game.contact.crashes)
	if on:
		loose.erase(lump_record)
		loose.append(shell_record)
		if not open: loose.push_front(plate_record)
	else:
		loose.erase(shell_record)
		loose.erase(plate_record)
		loose.append(lump_record)
	_shell_body.collision_layer = game.arches.LAYER if on else 0
	_lump_body.collision_layer = 0 if on else game.arches.LAYER

## The plane's breaking the plate (SurgeSmash `_hit`).
func _strike(_r: Dictionary, _q: Vector3) -> void:
	if open: return
	open = true
	breaks += 1
	game.arches.loose.erase(plate_record)
	_plate.visible = false
	_light.visible = false
	game.smash.keep_hot(entry.distance_to(socket)/maxf(float(game.plane.velocity.length()),30.0)+0.5)
	broke.emit()

## Out of the bore's wall toward its middle, world, for FlightContact: inside it a
## touch glances, the shut plate's face excepted. ZERO elsewhere.
func way_off(p: Vector3, _what := "") -> Vector3:
	if state != HOLD or not open: return Vector3.ZERO
	var l := _carried(p)
	var axis := (socket-entry).normalized()
	var along := (l-entry).dot(axis)
	if along < -2.0 or along > entry.distance_to(socket)+6.0: return Vector3.ZERO
	var off := l-entry-axis*along
	if off.length() > way_wide*0.5+2.0 or off.length() < 0.001: return Vector3.ZERO
	return (transform.basis*-off).normalized()

func _build(data: Dictionary) -> void:
	_model = (load(MODEL) as PackedScene).instantiate()
	add_child(_model)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = STONE_C
	stone.roughness = 0.95
	stone.emission_enabled = true
	stone.emission = STONE_C
	stone.emission_energy_multiplier = 0.2
	stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	for m: Node in _model.find_children("*","MeshInstance3D",true,false):
		(m as MeshInstance3D).material_override = stone
	var at: Array = data.entry
	var mouth := Vector3(at[0],at[1],at[2])
	var tip: Array = data.socket
	_plate_look(mouth,(Vector3(tip[0],tip[1],tip[2])-mouth).normalized())
	_middle = Node3D.new()
	_middle.name = "LiftMiddle"
	add_child(_middle)
	_middle.position = (entry+socket)*0.5
	LayoutOverrides.track(HANDLE,_middle,"coast",_middle.transform)
	var boxes: Array = []
	for b: Array in data.boxes:
		boxes.append(AABB(Vector3(b[0],b[1],b[2]),Vector3(b[3]-b[0],b[4]-b[1],b[5]-b[2])))
	shell_record = _record("shell",boxes)
	shell_record["no_break"] = true
	shell_record["adopted"] = 0
	var half := way_wide*0.5+1.0
	var mid := entry
	var plug := AABB(Vector3(mid.x-half,mid.y-half,mid.z-9.0),Vector3(half*2.0,half*2.0,18.0))
	plate_record = _record("plate",[plug])
	plate_record["strike"] = Callable(self,"_strike")
	var lump: Array = []
	for r: Vector2 in LUMP: lump.append(AABB(Vector3(-r.y,-r.x,-r.y),Vector3(r.y*2.0,r.x*2.0,r.y*2.0)))
	lump_record = _record("lump",lump)
	lump_record["no_break"] = true
	lump_record["adopted"] = 0
	game.arches.loose.append(lump_record)
	_shell_body = _body("Shell",boxes+[plug])
	_shell_body.collision_layer = 0
	_lump_body = _body("Lump",lump)

## A glowing disc flush on the stump, the bore's slant its ellipse, and its light.
func _plate_look(mouth: Vector3, axis: Vector3) -> void:
	var down := Vector3.UP
	var lean := (axis-down*axis.dot(down)).normalized()
	var stretch := 1.0/maxf(axis.dot(down),0.3)
	var r := way_wide*0.5+PLATE_LIP
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.8
	disc.radial_segments = 40
	disc.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLATE_C
	mat.emission_enabled = true
	mat.emission = PLATE_C
	mat.emission_energy_multiplier = PLATE_GLOW
	disc.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis(lean*stretch,down,lean.cross(down)),mouth+down*0.6)
	_model.add_child(mi)
	_plate = mi
	_light = OmniLight3D.new()
	_light.light_color = PLATE_C
	_light.light_energy = 6.0
	_light.omni_range = 70.0
	_light.position = mouth-down*12.0
	_model.add_child(_light)

func _record(part: String, boxes: Array) -> Dictionary:
	return {"name":HANDLE+"/"+part,"kind":"ship","node":self,"pos":position,"cos":cos(_yaw),"sin":sin(_yaw),
		"solid":BoxSolid.build(boxes),"reach":60.0,"spec":{}}

func _body(label: String, boxes: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = game.arches.LAYER
	body.collision_mask = 0
	for box: AABB in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
	add_child(body)
	return body

## --head-lift-start: the far side at once, him at the site, the plane held on the
## bore's line, charged, till the land's streamed in, then let go at speed.
func debug_start(host: Node3D) -> void:
	if _start_held < 0: return
	if _start_held == 0:
		if not _started():
			_start_held = -1
			return
		host.doors._swap(1)
		_put_him()
		state = WAIT
		host.near.meter = 1.0
	_start_held += 1
	var holds := Transform3D(Basis(Vector3.UP,_yaw),_hold)
	var mouth := holds*entry
	var way: Vector3 = (holds*socket-mouth).normalized()
	var flat := Vector3(way.x,0.0,way.z).normalized()
	var at := mouth-flat*START_OUT
	host.plane.heading = atan2(-flat.x,-flat.z)
	host.plane.pitch = 0.0
	host.plane.carry(at,flat*START_SPEED,START_SPEED)
	var c: Dictionary = host.land.counts()
	if _start_held > START_LEAST and (_start_held > START_MOST or int(c.queued)+int(c.in_flight) == 0):
		_start_held = -1

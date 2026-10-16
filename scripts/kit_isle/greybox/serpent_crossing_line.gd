extends Node3D
## The Serpent Crossing's serpent (scripts/kit_isle/greybox/gb_serpent_
## crossing.gd): the rune serpent on its line round the motif, its two
## collars, the dais's countdown, the shrug past the coil's cap, the wake's
## shove and the runes woken as it passes. The yard's wiring (studies/city_
## serpent_yard.gd) moved into
## a motif: its body is moving ground (PhysicsGround.mark_moving, the
## capsules cut to its crest), its heave held (heave_share 0), each collar
## follows its ring every step. Stepped in this node's own physics frame
## (the motor carries him by the ground's move since its last step, so the
## order doesn't matter).
const CS = preload("res://scripts/city_kit_serpent.gd")
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")

## Its paces by stretch (m/s, by the front collar's place on its line),
## eased at PACE_EASE (m/s²).
const PACE := {"loop":20.0,"approach":7.0,"station":7.0,"ring":10.0,"coil":12.0,"couple":11.0,"top":7.0,"leave":14.0}
const PACE_EASE := 2.4
const BANK_SHARE := 0.45
## The collars' places back from its snout (m).
const COLLARS_AT := [24.0,54.0]
## The shrug: tossed toward the coil's axis (m/s in, up).
const SHRUG := Vector2(8.5,5.0)
## The wake: a body inside its girth not riding it is shoved out (m/s out,
## up), not more often than WAKE_EVERY (s).
const WAKE_SHOVE := Vector2(4.5,4.0)
const WAKE_EVERY := 0.6

var motif: RefCounted
var study: Node
var motor: Variant
## The line's control points and marks (world), the coil's axis (world).
var route: Array = []
var marks := {}
var coil_axis := Vector3.ZERO
var serpent: Node3D
var collars: Array = []
var arcs := {}
var lap := 0.0
var held := false
## Counts and the last of each, for the drivers.
var boardings := 0
var shrugs := 0
var shoves := 0
var on_now := ""
var _was_on := ""
var _pace := 9.0
var _shove_t := 0.0
var _collar_arc: Array = []

func setup(m: RefCounted, s: Node, made: Array, axis: Vector3) -> void:
	motif = m
	study = s
	motor = s.get("motor")
	route = made[0]
	marks = made[1]
	coil_axis = axis
	serpent = RuneSerpent.new()
	serpent.route = route
	serpent.route_marks = marks
	serpent.start_mark = "loop"
	serpent.girth = 1.0
	serpent.heave_share = 0.0
	serpent.solid = true
	serpent.look_back = true
	add_child(serpent)
	serpent.setup(study)
	serpent.set_process(false)
	serpent.set_physics_process(false)
	arcs = serpent.marks()
	lap = float(serpent.route_length)
	# Its body is ground he rides: its capsules moving ground, their tops at
	# its crest (not its widest girth), so he stands on the stone he sees.
	var solid := serpent.get_node_or_null("Solid") as CollisionObject3D
	if solid != null:
		PhysicsGround.mark_moving(solid)
		for c: Node in solid.get_children():
			var cs := c as CollisionShape3D
			if cs == null or not (cs.shape is CapsuleShape3D): continue
			var cap := cs.shape as CapsuleShape3D
			var length := cap.height-cap.radius*2.0
			cap.radius = cap.radius/RuneSerpent.CAPSULE_SHARE*CS.CREST_SHARE
			cap.height = length+cap.radius*2.0
	serpent._place_solid()
	var st: PackedFloat32Array = serpent.stations()
	for i in COLLARS_AT.size():
		var k := 0
		for j in st.size():
			if absf(st[j]-float(COLLARS_AT[i])) < absf(st[k]-float(COLLARS_AT[i])): k = j
		var c := CS.collar(self,serpent,k,{"lamp":i == 0,"name":"Collar%d" % i})
		collars.append(c)
		_collar_arc.append(float(st[k]))
	_pace = float(serpent.speed())
	var at := float(arcs.get("loop",0.0))
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		# The serpent set this many seconds before its head reaches the dais.
		if a.begins_with("--serpent-due="): at = fposmod(float(arcs.station)-float(a.get_slice("=",1))*float(PACE.station)-20.0,lap)
	place(at)
	print("serpent crossing: lap %.0f m, marks %s" % [lap,str(arcs)])

## Its head set at `at` m round its line.
func place(at: float) -> void:
	serpent.place(at)
	_pace = float(PACE.station) if fposmod(float(arcs.station)-at,lap) < 160.0 else float(PACE.loop)
	serpent._place_solid()
	for c: Node3D in collars: c.follow(0.0)

## The serpent set `seconds` before its head reaches the dais.
func call_serpent(seconds := 12.0) -> void:
	place(fposmod(float(arcs.station)-seconds*float(PACE.station)-20.0,lap))

func collar_arc(i := 0) -> float:
	return fposmod(float(serpent.s)-float(_collar_arc[i]),lap)

func _between(a: float, from: String, to: String) -> bool:
	var f := float(arcs.get(from,0.0))
	var t := float(arcs.get(to,0.0))
	return fposmod(a-f,lap) < fposmod(t-f,lap)

## The stretch the front collar is on.
func stretch() -> String:
	var a := collar_arc(0)
	var near_station := fposmod(float(arcs.station)-a,lap)
	if near_station < 110.0 or fposmod(a-float(arcs.station),lap) < 10.0: return "station"
	for pair: Array in [["station","ring"],["ring","coil"],["coil","couple"],["couple","top"],["top","leave"],["leave","loop"]]:
		if _between(a,str(pair[0]),str(pair[1])): return str(pair[0])
	return "loop"

func _pace_goal() -> float:
	var s := stretch()
	return float(PACE.get(s,PACE.loop))

func _physics_process(delta: float) -> void:
	if serpent == null or held: return
	var step := minf(delta,RuneSerpent.MAX_STEP)
	_pace = move_toward(_pace,_pace_goal(),PACE_EASE*step)
	serpent.pace_hold = _pace*float(serpent.get("_speed_scale"))
	serpent.bank_share = BANK_SHARE
	serpent.advance(step)
	serpent._place_solid()
	for c: Node3D in collars: c.follow(step)
	var pieces: Dictionary = motif.get("pieces")
	_count(pieces)
	_shrug_check()
	_shove(step)
	_wake(pieces,step)
	_on_what()

## The dais's countdown: seconds before its head is at the dais's middle.
func _count(pieces: Dictionary) -> void:
	var dais: Node3D = pieces.get("dais")
	if dais == null or not is_instance_valid(dais): return
	var a := float(arcs.station)
	var s := float(serpent.s)
	var ahead := fposmod(a-s,lap)
	var behind := fposmod(s-a,lap)
	dais.call("update",ahead/maxf(float(serpent.speed()),1.0),behind < RuneSerpent.LENGTH+8.0)

## Past the coil's cap a collar rolls; a rider on it is thrown toward the
## cap, in the frame it moves in.
func _shrug_check() -> void:
	var mark := float(arcs.get("shrug",-1.0))
	if mark < 0.0: return
	for i in collars.size():
		var c: Node3D = collars[i]
		var a := collar_arc(i)
		var was: float = c.get_meta("arc",a)
		c.set_meta("arc",a)
		var went := fposmod(a-was,lap)
		if went <= 0.0 or went > 20.0 or fposmod(a-mark,lap) >= went: continue
		var inward := coil_axis-c.global_position
		inward.y = 0.0
		inward = inward.normalized()
		var side := signf((c.global_transform.basis.x).dot(inward))
		c.call("shrug",side if side != 0.0 else 1.0)
		if motor != null and c.call("carries",motor.platform) and (motor.grounded or motor.on_ledge()):
			shrugs += 1
			motor.toss(inward*SHRUG.x+Vector3.UP*SHRUG.y)
			print("serpent crossing: shrugged onto the cap")

## A body in its girth, not riding it, shoved out of its way (a toss, never
## a stun or a hurt).
func _shove(delta: float) -> void:
	if motor == null: return
	_shove_t = maxf(0.0,_shove_t-delta)
	if _shove_t > 0.0 or motor.on_ledge() or motor.recovering(): return
	if on_now != "": return
	var p: Vector3 = motor.feet+Vector3.UP*0.6
	var rings: PackedVector3Array = serpent.rings()
	var radii: PackedFloat32Array = serpent.radii()
	for i in range(rings.size()-1):
		var a := rings[i]
		var b := rings[i+1]
		var ab := b-a
		var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
		var q := a+ab*t
		if p.distance_to(q) < radii[i]*0.92:
			var out := p-q
			out.y = 0.0
			out = out.normalized() if out.length() > 0.05 else Vector3(-ab.z,0.0,ab.x).normalized()
			var ahead := -ab.normalized()*float(serpent.speed())*0.5
			motor.toss(out*WAKE_SHOVE.x+Vector3.UP*WAKE_SHOVE.y+ahead)
			shoves += 1
			_shove_t = WAKE_EVERY
			return

func _collar_of(node: Node) -> int:
	for i in collars.size():
		if (collars[i] as Node3D).call("carries",node): return i
	return -1

func _wake(pieces: Dictionary, delta: float) -> void:
	var pts := PackedVector3Array()
	var rings: PackedVector3Array = serpent.rings()
	for i in range(0,rings.size(),3): pts.append(rings[i])
	pts.append(serpent.head())
	for key: String in ["dais","ring","coil","bowl"]:
		var p: Node3D = pieces.get(key)
		if p != null and is_instance_valid(p) and p.is_inside_tree(): CS.wake(p,pts,delta)

## What he stands on now: boardings counted.
func _on_what() -> void:
	if motor == null: return
	var now := ""
	if motor.platform != null and is_instance_valid(motor.platform):
		var k := _collar_of(motor.platform)
		if k >= 0: now = "collar%d" % k
		elif motor.platform.get_parent() == serpent.get_node_or_null("Solid"): now = "back"
	on_now = now
	if now != "" and _was_on == "":
		boardings += 1
		print("serpent crossing: aboard (%s) at %s" % [now,str(motor.feet.round())])
	if now != "": _was_on = now
	elif motor.grounded or motor.on_ledge(): _was_on = ""

extends SceneTree
## The pilot on a ledge (scripts/pilot_motor.gd's hold, scripts/pilot_ledge.gd,
## drawn by scripts/pilot_figure.gd), on a made-up island: flat ground
## inside a wavy rim with nothing past it, and a block standing on it too
## high to step up. The lip is found on the rim, its way off it outwards;
## walked off the rim slowly he turns, lowers himself and hangs under it,
## facing it, the mitts on the lip, and so he does sliding over it with the
## stick let go at a run; run off it, he goes over. Hanging, the
## stick along it shimmies him round its curve, staying under it and facing
## it, the gripping mitt not sliding; at the block's square corner the
## shimmy stops. Towards the wall he climbs up and stands on top, in from
## the edge; away he lets go and falls. Jumped at the block and falling past
## its lip, he catches it and climbs onto it. Through it all the body never
## jumps from one frame to the next.
##   godot --headless --path . --script tests/test_pilot_ledge.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PilotLedge = preload("res://scripts/pilot_ledge.gd")
const DT := 1.0/60.0
## The rim's radius at angle `a` and the block (x, z ranges) and its height.
const BLOCK := Rect2(2.0,-1.0,2.0,2.0)
const BLOCK_TOP := 1.6
var failures := 0
var m := PilotMotor.new()
var figure: Node3D
var skeleton: Skeleton3D
var bones := {}
## The most the drawn body moved on its origin in a frame, and where.
var worst_jump := 0.0
var worst_at := ""
var _hips_was := Vector3.INF
var _velocity_was := Vector3.ZERO

static func rim(a: float) -> float:
	return 6.0+0.8*sin(3.0*a)

var ground := func(p: Vector2) -> float:
	if p.length() > rim(p.angle()): return -INF
	return BLOCK_TOP if BLOCK.has_point(p) else 0.0
var slide := func(feet: Vector3, step: Vector2) -> Vector3: return feet+Vector3(step.x,0.0,step.y)
var ledge := func(near: Vector2, y: float) -> Dictionary: return PilotLedge.find(ground,near,y)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	figure = PilotFigure.new()
	root.add_child(figure)
	skeleton = figure.find_children("*","Skeleton3D",true,false)[0]
	for bone in ["hand.L","hand.R","hips"]: bones[bone] = skeleton.find_bone(bone)
	var player := figure.find_child("AnimationPlayer",true,false) as AnimationPlayer
	check(["hang","shimmy_left","shimmy_right","climb"].all(func(c: String) -> bool: return player.has_animation(c)),"The model has its hang, shimmies and climb")
	# The lip on the rim.
	var a := 0.4
	var found: Dictionary = PilotLedge.find(ground,Vector2.from_angle(a)*rim(a),0.0)
	check(not found.is_empty(),"A lip is found on the rim")
	if not found.is_empty():
		var edge := Vector2(found.at.x,found.at.z)
		check(absf(edge.length()-rim(edge.angle())) < 0.05 and absf(found.at.y) < 0.01,"On the rim's edge (%.3f m off)" % (edge.length()-rim(edge.angle())))
		var outward := Vector2(cos(a),sin(a))
		check((found.out as Vector2).dot(outward) > 0.8,"Its way off points out (%.2f)" % (found.out as Vector2).dot(outward))
	check(PilotLedge.find(ground,Vector2(-2.0,0.0),0.0).is_empty(),"Out on the flat there is no lip")
	# Walked off the rim slowly: turned round, lowered, hanging.
	var events := _walk_off(PilotMotor.WALK,0.5)
	check(events.has("grabbed") and events.grabbed == "step","Walked slowly off the rim, he catches it")
	var hung := _until(func() -> bool: return m.hold == "hang",Vector2.ZERO,false,90)
	check(hung,"He lowers himself over it and hangs")
	_check_hang("Off the rim")
	# At a full run, the stick let go just short of the rim (the keys have no
	# walk): the slide carries him over and he catches it.
	var a2 := 0.4
	var out2 := Vector2(cos(a2),sin(a2))
	_settle(Vector3(out2.x,0.0,out2.y)*(rim(a2)-3.0),out2)
	var slid_off := {}
	for i in range(180):
		var short: bool = Vector2(m.feet.x,m.feet.z).length() > rim(a2)-0.25
		slid_off = _step(Vector2.ZERO if short else out2,false)
		if slid_off.has("grabbed") or not m.grounded: break
	check(slid_off.has("grabbed"),"Let go of the stick at a run just short of it, he slides over and catches it")
	# Run off it: over he goes.
	var ran := _walk_off(PilotMotor.RUN,1.0)
	check(not ran.has("grabbed") and not m.on_ledge() and not m.grounded,"Run off it, he goes over")
	# Shimmy round the rim's curve.
	_walk_off(PilotMotor.WALK,0.5)
	_until(func() -> bool: return m.hold == "hang",Vector2.ZERO,false,90)
	var start := Vector2(m.lip.x,m.lip.z)
	var under := true
	var facing := true
	var slid := 0.0
	var right := _right()
	var hand_was := []
	for i in range(180):
		_step(right*0.0+_right(),false)
		var edge := Vector2(m.lip.x,m.lip.z)
		under = under and absf(edge.length()-rim(edge.angle())) < 0.06
		facing = facing and PilotMotor.forward(m.facing).dot(-edge.normalized()) > 0.85
		# A gripping mitt (down on the lip) stays put.
		var hands := [_bone("hand.L"),_bone("hand.R")]
		if i > 30 and hand_was.size() == 2:
			for k in range(2):
				var now: Vector3 = hands[k]
				var was: Vector3 = hand_was[k]
				if now.y < m.lip.y+0.04 and was.y < m.lip.y+0.04: slid = maxf(slid,now.distance_to(was))
		hand_was = hands
	var went := start.distance_to(Vector2(m.lip.x,m.lip.z))
	check(went > 1.2,"Along the lip, he shimmies (%.2f m in 3 s)" % went)
	check(under,"Staying under the lip round its curve")
	check(facing,"Turning to face it as it curves")
	check(slid < 0.012,"A gripping mitt doesn't slide (worst %.4f m in a frame)" % slid)
	_check_hang("Shimmying")
	# Climb up: towards the wall.
	var lip := m.lip
	var out_way := m.lip_out
	var climbed := _until(func() -> bool: return m.grounded and not m.on_ledge(),-out_way,false,120)
	var inward := (Vector2(lip.x,lip.z)-Vector2(m.feet.x,m.feet.z)).dot(out_way)
	check(climbed and absf(m.feet.y-lip.y) < 0.05,"Towards the wall, he climbs up and stands on top")
	check(absf(inward-PilotMotor.CLIMB_IN) < 0.12,"In from the edge (%.2f m)" % inward)
	_until(func() -> bool: return false,Vector2.ZERO,false,30)
	# Let go: away from the wall.
	_walk_off(PilotMotor.WALK,0.5)
	_until(func() -> bool: return m.hold == "hang",Vector2.ZERO,false,90)
	var let_go := _until(func() -> bool: return not m.on_ledge(),m.lip_out,false,30)
	check(let_go and not m.grounded,"Away from the wall, he lets go and falls")
	# Jumped at the block: caught falling past its lip, climbed onto it.
	var grabbed := false
	for out: Dictionary in _jump_at_block(0.0):
		if out.has("grabbed"):
			grabbed = out.grabbed == "air"
			break
	check(grabbed,"Jumped at the block, he catches its lip falling past it")
	check(m.hold == "hang" and absf(m.lip.x-BLOCK.position.x) < 0.05 and absf(m.lip.y-BLOCK_TOP) < 0.05,"Hanging from the block's edge")
	for i in range(20): _step(Vector2.ZERO,false)
	_check_hang("From the block")
	var up := _until(func() -> bool: return m.grounded,Vector2.ZERO,true,120)
	check(up and absf(m.feet.y-BLOCK_TOP) < 0.05 and BLOCK.has_point(Vector2(m.feet.x,m.feet.z)),"Space climbs him up onto it")
	# The block's corner stops a shimmy.
	for out: Dictionary in _jump_at_block(0.3):
		if out.has("grabbed"): break
	var stopped := false
	for i in range(240):
		stopped = stopped or _step(_right(),false).has("stopped")
	check(m.hold == "hang" and stopped and absf(m.lip.z-(BLOCK.end.y)) < 0.45 and absf(m.lip.x-BLOCK.position.x) < 0.05,"At the block's square corner the shimmy stops (%.2f from it)" % (BLOCK.end.y-m.lip.z))
	check(worst_jump < 0.08,"The drawn body never jumps (worst %.3f m in a frame, %s)" % [worst_jump,worst_at])
	var ok := true
	for node: Node3D in figure.find_children("*","Node3D",true,false):
		ok = ok and node.transform.origin.is_finite() and node.transform.basis.x.is_finite()
	check(ok,"The drawn pilot's parts stay finite")
	print("PASS: pilot ledge" if failures == 0 else "FAIL: pilot ledge (%d)" % failures)
	quit(1 if failures else 0)

## Stood at `at` facing `way`, at rest.
func _settle(at: Vector3, way: Vector2) -> void:
	m.reset(at,PilotMotor.facing_of(way))
	figure.settle()
	_hips_was = Vector3.INF
	_step(Vector2.ZERO,false)

## Run at the block's near face at `z` and jumped from a metre short of it:
## what happened each frame, until a catch or 2 s.
func _jump_at_block(z: float) -> Array:
	_settle(Vector3(-1.5,0.0,z),Vector2(1.0,0.0))
	var all := []
	var jumped := -1
	for i in range(120):
		if jumped < 0 and m.feet.x > BLOCK.position.x-1.0: jumped = i
		var out := _step(Vector2(1.0,0.0),jumped >= 0 and i-jumped < 20)
		all.append(out)
		if out.has("grabbed"): break
	return all

## Stood 1.5 m in from the rim at angle 0.4 and sent off it at `pace`, the
## stick pushed `push`: what happened as it went over.
func _walk_off(pace: float, push: float) -> Dictionary:
	var a := 0.4
	var out := Vector2(cos(a),sin(a))
	_settle(Vector3(out.x,0.0,out.y)*(rim(a)-1.5),out)
	for i in range(180):
		var events := _step(out*push,false,pace)
		if events.has("grabbed") or not m.grounded: return events
	return {}

## Steps until `done`, the stick at `want` and Space at `jump`: whether it
## was done within `frames`.
func _until(done: Callable, want: Vector2, jump: bool, frames: int) -> bool:
	for i in range(frames):
		_step(want,jump and i%2 == 0)
		if done.call(): return true
	return false

func _step(want: Vector2, jump: bool, top := PilotMotor.RUN) -> Dictionary:
	var out := m.step(DT,want,top,jump,ground,slide,ledge)
	figure.position = m.origin()
	figure.rotation = Vector3(0.0,m.facing,0.0)
	figure.drive(m.pose(),DT)
	# The body against the way the motor moves it: a fall or a run is no
	# jump, nor is the origin's own jump under the climb's clip.
	var hips := _bone("hips")
	if _hips_was.is_finite():
		# (Caught falling, the catch stops it dead.)
		var pop := minf((hips-_hips_was-m.velocity*DT).length(),(hips-_hips_was-_velocity_was*DT).length())
		if pop > worst_jump:
			worst_jump = pop
			worst_at = "%s %.2f" % [m.hold if m.hold != "" else ("ground" if m.grounded else "air"),m.hold_t]
	_hips_was = hips
	_velocity_was = m.velocity
	return out

## The way along the lip to his right.
func _right() -> Vector2:
	return Vector2(m.lip_out.y,-m.lip_out.x)

## Hanging: under the lip, facing it, both mitts on it.
func _check_hang(how: String) -> void:
	for i in range(30): _step(Vector2.ZERO,false)
	var edge := Vector2(m.lip.x,m.lip.z)
	var feet := Vector2(m.feet.x,m.feet.z)
	check(m.hold == "hang" and absf(m.lip.y-m.feet.y-PilotMotor.HANG_DROP) < 0.02 and absf((feet-edge).dot(m.lip_out)-PilotMotor.HANG_OUT) < 0.03,"%s: hanging under the lip" % how)
	check(PilotMotor.forward(m.facing).dot(-m.lip_out) > 0.95,"%s: facing it" % how)
	var worst := 0.0
	for hand in ["hand.L","hand.R"]:
		var at := _bone(hand)
		var inward := (edge-Vector2(at.x,at.z)).dot(m.lip_out)
		worst = maxf(worst,maxf(absf(at.y-m.lip.y-0.035),absf(inward-0.03)))
	check(worst < 0.06,"%s: both mitts on the lip (worst %.3f m off)" % [how,worst])

func _bone(name: String) -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bones[name]).origin

func check(ok: bool, what: String) -> void:
	if ok: print("ok   ",what)
	else:
		failures += 1
		print("FAIL ",what)

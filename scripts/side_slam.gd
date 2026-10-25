extends Node3D
## The side slam (docs/design/side-slam/side-slam-handoff.md): the slide's
## forward burst held into a horizontal slam. With a segment of charge, on the ground
## (a slide, or standing, walking, running), Q / pad RB HELD past HOLD s
## coils him (COIL s: a slide brakes, he winds back low; off a slide he
## plants and crouches back, GROUND_COIL s) and launches him body-first,
## shoulder leading, much faster than the burst, low and flat (the motor's
## move "lunge"): along the slide, or off a slide along the stick (held) or
## the way he faces. It spends one segment (the gauge's SEG; unsegmented,
## it still needs and spends the whole charge).
##
## - **The tap is as before.** With a segment on the ground the press is
##   kept till it is let go or held past HOLD: let go first, it is the burst
##   in a slide, the updraft out of one, exactly as a press would have been,
##   a tap's length later. The coil's first share (WAIT_COIL) shows from the
##   press, so the wait reads as the wind-up. With no segment, or in the
##   air, nothing here touches the press.
## - **The lunge.** LUNGE_PACE m/s along the slide's way, HOVER m over the
##   ground (it rides slopes up at CLIMB, sinks off an edge no faster than
##   SINK), for at most REACH m. Run out with nothing met, his pace drops to
##   MISS_KEEP of it and he falls back to the ground (crouch held: the
##   slide).
## - **The hit.** Stopped by something (his step through the world comes up
##   short of HIT_SHARE of the asked; a wall, a kit piece, a rock, the rune
##   knight's room) or reaching a lock target (an enemy) within
##   ENEMY_REACH: the impact. The breakables hubs take `hit(at, HIT_RADIUS,
##   -1, &"side_slam")` (the hub's own strength for "side_slam"), the slam's
##   group hears `slam(at, HIT_RADIUS, PUSH)`, a lock target near it with a
##   `hit(at, way, strength)` (the rune knight's stagger) is hit KNOCK hard.
##   Hit-stop, a shake, a punch of the view, dust (the host's) and the
##   slam's thump (kit_audio), on the step's "side_slam" event.
## - **The rebound.** Thrown back off the surface: the way out its normal
##   and his bounce mixed (BOUNCE), REBOUND_OUT m/s, up REBOUND_RISE m, in
##   the wall kick's move ("kick"): the stick his own at once, so the sail,
##   the twirl or the downward slam follow from it.
##
## Lengths by the wanderer's size (the motor's `size`), paces by it to
## PilotMotor.PACE_POWER, as the motor's own.
##
## The updraft owns the key: `updraft.side_slam` set to this, it calls
## `arm` on a press and `before` each frame (before the motor's step). The
## host calls `after(events, motor)` after the step (its events merged
## into the step's) and `apply_feel(camera)` once the camera is set.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Updraft = preload("res://scripts/updraft.gd")
const Slam = preload("res://scripts/slam.gd")
const Pad = preload("res://scripts/pad.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")

## Master toggle (also `--no-side-slam`).
const ON := true
## The breaker name the hubs know it by (scripts/breaks/breakables.gd).
const SOURCE := &"side_slam"
# --- The trigger
const HOLD := 0.16               # s the key is held before it is the side slam, not the burst
const COIL := 0.2                # s of coil after that, then the launch
const COIL_BRAKE := 3.0          # per s the slide's pace bleeds through the coil
const GROUND_COIL := 0.24        # s of coil off a slide (standing, running): a touch longer, he plants first
const PLANT := 14.0              # per s his run's pace bleeds through that coil (planted)
const AIM_TURN := 18.0           # per s he turns to the stick through that coil
const WAIT_COIL := 0.3           # share of the coil's pose shown through the wait (the wind-up from the press)
const GROUND_MOVES := ["","crouch","slide"]   # the ground moves it arms from
# --- The lunge (m, m/s at size 1)
const LUNGE_PACE := 22.0         # m/s along the slide (a full-charge burst adds ~9 to a slide of 6-10)
const REACH := 8.0               # m it runs with nothing met
const HOVER := 0.45              # m over the ground it skims
const HOVER_EASE := 0.08         # s it takes to close on the hover height
const CLIMB := 9.0               # m/s up at most (a slope met)
const SINK := 1.5                # m/s down at most (off an edge: flat, sinking)
const LIFT := 1.5                # m/s up at the launch
const MISS_KEEP := 0.45          # share of the pace kept when it runs out
# --- The hit
const HIT_SHARE := 0.45          # a step short of this share of the asked is a hit
## Feelers: rays out along his way from his feet at these heights (his
## body's cylinder starts over the motor's step, so a low chest or the
## corner of a pier he would glance off or skim over is still met), this far
## past his body, this far off his line either side at the chest.
const FEEL_HIGH := [0.1,0.45,0.85]
const FEEL_AHEAD := 0.22         # m past his body's radius
const FEEL_SIDE := 0.2           # m off his line, the side feelers (at FEEL_HIGH[1])
const FEEL_FACING := 0.25        # a face met must turn at least this much against his way
const FEEL_STEEP := 0.6          # and be no flatter than this (|normal.y|): a slope is ridden, not hit
const ENEMY_REACH := 1.4         # m from his chest to a lock target's aim point that is a hit
const HIT_RADIUS := 1.6          # m the hit reaches round the contact
const PUSH := 0.6                # strength the slam's group hears
const KNOCK := 1.0               # strength handed to an enemy's `hit`
const CHEST := 0.75              # m over the feet the contact is looked for at
# --- The rebound
const REBOUND_OUT := 7.5         # m/s off the surface
const REBOUND_RISE := 1.8        # m up
const BOUNCE := 0.4              # share of his own bounce (the reflection) in the way out; the rest the normal
# --- Feel
const HITSTOP_FRAMES := 6
const HITSTOP_SCALE := 0.04
const FOV_LUNGE := 10.0          # deg wider through the lunge
const FOV_COIL := -3.0           # deg narrower through the coil
const FOV_EASE := 0.07           # s the view follows
const FOV_PUNCH := 7.0           # deg narrower on the hit, easing back
const KICK := 0.45               # m the camera jolts along the lunge on the hit
const KICK_TIME := 0.45          # s it takes to jolt and come back
const SHAKE := 0.13              # m of shake on the hit
const SHAKE_TIME := 0.5          # s it dies over
const PULSE := Vector3(0.5,1.0,0.25)   # the pad's weak motor, strong, s
# --- Look
const STREAKS := 4               # speed streaks behind him through the lunge
const STREAK_TAIL := 0.14        # s of his path they keep
const STREAK_HIGH := [0.35,0.7,1.0,1.25]
const STREAK_SIDE := [-0.3,0.25,-0.1,0.15]
const STREAK_WIDTH := 0.16
const STREAK_ALPHA := 0.55
const BURST_ARCS := 7            # arcs of the shockwave on the wall
const BURST_TIME := 0.22         # s it takes to spread
const BURST_FADE := 0.3
const BURST_R := 2.2             # m it spreads to

## "" idle, "wait" (pressed at full charge, not yet HOLD), "coil", "lunge".
var phase := ""
## Where it was armed: "slide", or "ground" (standing, walking, running).
var from := ""
var hits := 0
var misses := 0
var launches := 0
## The last hit: {at, normal, way, broke, enemy, kind} ({} none yet).
var last := {}
## The host's physics ground (PhysicsGround: `space`, `mask`) for the
## contact ray; null: the contact is taken in front of him.
var ground: Object = null
var _up: Object = null           # the updraft
var _t := 0.0
var _dir := Vector2.ZERO
var _aim := Vector2.ZERO
var _touch := {}                 # what a feeler met this frame ({at, normal}), {} none
var _pace := 0.0
var _gone := 0.0
var _size := 1.0
var _before := Vector3.ZERO
var _dt := 1.0/60.0             # the last frame's delta (before's)
var _events := {}
var _clock := 0.0
var _hitstop := 0
var _fov := 0.0
var _fov_goal := 0.0
var _fov_applied := 0.0
var _kick_t := 0.0
var _kick_way := Vector3.ZERO
var _cam: Camera3D
var _trail: Array[Dictionary] = []   # {at, side, t}
var _bursts: Array[Dictionary] = []  # {at, n, t}
var _mesh: ImmediateMesh

func setup(host: Node3D, updraft: Object) -> void:
	host.add_child(self)
	name = "SideSlam"
	_up = updraft
	updraft.set("side_slam",self)
	_mesh = ImmediateMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/breeze_ribbon.gdshader")
	var view := MeshInstance3D.new()
	view.name = "SideSlamStreaks"
	view.mesh = _mesh
	view.material_override = mat
	view.top_level = true
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.extra_cull_margin = 32.0
	add_child(view)

func reset() -> void:
	phase = ""
	_events = {}
	_fov_goal = 0.0
	_kick_t = 0.0
	_trail.clear()
	_bursts.clear()
	if _hitstop > 0:
		_hitstop = 0
		Engine.time_scale = 1.0
	if _mesh != null: _mesh.clear_surfaces()

func busy() -> bool:
	return phase != ""

## The coil's share now (0..1), for the figure's wind-up: WAIT_COIL of it
## through the wait, the rest through the coil.
func coil() -> float:
	if phase == "wait": return WAIT_COIL*clampf(_t/HOLD,0.0,1.0)
	if phase == "coil": return lerpf(WAIT_COIL,1.0,clampf(_t/_coil_time(),0.0,1.0))
	return 0.0

func _coil_time() -> float:
	return COIL if from == "slide" else GROUND_COIL

## Whether the host keeps the stick, jump and crouch from the motor now (the
## coil off a slide: planted; the stick aims, read here).
func holds() -> bool:
	return phase == "coil" and from == "ground"

## Whether a press now may be the side slam's: a segment of charge (unsegmented:
## full), on the ground (a slide, or standing, walking, running).
static func wanted(m: PilotMotor, up: Object) -> bool:
	var enough: bool = up.call("can_spend") if up.get("segmented") else float(up.get("charge")) >= 1.0-Updraft.SEG_HAIR
	return ON and m.grounded and m.move in GROUND_MOVES and enough \
		and not m.recovering() and not m.swimming and not m.seized() and m.rider == null and m.hold == ""

## The updraft's press: true if it is kept here (the updraft does nothing
## with it now).
func arm(m: PilotMotor, up: Object) -> bool:
	if phase != "" or not wanted(m,up): return false
	_up = up
	phase = "wait"
	from = "slide" if m.move == "slide" else "ground"
	_t = 0.0
	return true

## One frame before the motor steps: the wait (let go: the burst; held: the
## coil), the coil, the lunge's pace set.
func before(delta: float, m: PilotMotor, held: bool, want: Vector2) -> void:
	_clock += delta
	_dt = delta
	if _cam != null and _fov_applied != 0.0:
		_cam.fov -= _fov_applied
		_fov_applied = 0.0
	_size = m.size
	match phase:
		"wait":
			_t += delta
			if not held:
				# A tap: the press as it would have been.
				phase = ""
				if not _up.burst(m,want): _up.updraft(m)
			elif _t >= HOLD and from == "ground" and not m.grounded:
				# Jumped off the ground in the wait: the press as it would
				# have been (the updraft).
				phase = ""
				if not _up.burst(m,want): _up.updraft(m)
			elif _t >= HOLD:
				if from == "slide" and m.move != "slide" and m.grounded: from = "ground"
				_aim = PilotMotor.forward(m.facing)
				phase = "coil"
				_t = 0.0
				_fov_goal = FOV_COIL
				_events["side_slam_coil"] = true
		"coil":
			_t += delta
			if m.recovering() or m.swimming or m.seized() or m.rider != null or m.hold != "":
				_end()
			elif from == "ground":
				# Planted: his pace bled away, turned to the stick (held).
				if want.length() > 0.3:
					_aim = want.normalized()
					m.facing = lerp_angle(m.facing,PilotMotor.facing_of(_aim),1.0-exp(-AIM_TURN*delta))
				if _t >= GROUND_COIL: _launch(m)
				else:
					var k := exp(-PLANT*delta)
					m.velocity.x *= k
					m.velocity.z *= k
			elif _t >= COIL: _launch(m)
			else:
				var k := exp(-COIL_BRAKE*delta)
				m.velocity.x *= k
				m.velocity.z *= k
	if phase == "lunge": _drive(delta,m)
	_before = m.feet
	_step_bursts(delta)

## The launch: one segment spent, tossed flat along the slide.
func _launch(m: PilotMotor) -> void:
	var h := Vector2(m.velocity.x,m.velocity.z)
	if from == "ground": _dir = _aim if _aim.length() > 0.5 else PilotMotor.forward(m.facing)
	else: _dir = h.normalized() if h.length() > 0.3 else PilotMotor.forward(m.facing)
	_pace = LUNGE_PACE*pow(_size,PilotMotor.PACE_POWER)
	_gone = 0.0
	_t = 0.0
	launches += 1
	_up.spend_lunge(m,-Vector3(_dir.x,0.0,_dir.y)*Updraft.LOOSE_DRIFT)
	m.toss(Vector3(_dir.x*_pace,LIFT*pow(_size,PilotMotor.PACE_POWER),_dir.y*_pace))
	m.move = "lunge"
	m.facing = PilotMotor.facing_of(_dir)
	phase = "lunge"
	_fov_goal = FOV_LUNGE
	_trail.clear()
	_events["side_slam_launch"] = _pace

## Each lunge frame: his pace along the way, the hover's height closed on.
func _drive(delta: float, m: PilotMotor) -> void:
	if m.move != "lunge":
		_end()
		return
	_t += delta
	m.velocity.x = _dir.x*_pace
	m.velocity.z = _dir.y*_pace
	var goal := m.ground_y+HOVER*_size if is_finite(m.ground_y) else m.feet.y
	var pace := pow(_size,PilotMotor.PACE_POWER)
	if _t > 0.06: m.velocity.y = clampf((goal-m.feet.y)/HOVER_EASE,-SINK*pace,CLIMB*pace)
	m.facing = PilotMotor.facing_of(_dir)

## After the motor's step: met something (the hit and the rebound), run out
## (the drop), or landed (lifted on). Its events, to merge into the step's.
func after(events: Dictionary, m: PilotMotor) -> Dictionary:
	if phase == "lunge":
		var step := m.feet-_before
		var went := Vector2(step.x,step.z).dot(_dir)
		var asked := _pace*_dt
		_gone += maxf(went,0.0)
		_trail.append({"at":m.feet,"side":Vector3(-_dir.y,0.0,_dir.x),"t":_clock})
		var enemy := _enemy_ahead(m)
		if m.swimming or m.recovering() or m.seized() or m.rider != null or m.hold != "" or m.move == "slam":
			_end()
		elif enemy != null: _hit(m,enemy)
		elif asked > 0.0 and went < HIT_SHARE*asked and _t > 0.0: _hit(m,null)
		elif _feel(m): _hit(m,null)
		elif _gone >= REACH*_size: _run_out(m)
		elif m.grounded or m.move != "lunge":
			# Touched down on a rise: lifted on, the lunge kept.
			m.toss(Vector3(_dir.x*_pace,LIFT,_dir.y*_pace))
			m.move = "lunge"
			m.facing = PilotMotor.facing_of(_dir)
	while _trail.size() > 2 and _clock-float(_trail[0].t) > STREAK_TAIL: _trail.pop_front()
	_draw()
	var out := _events
	_events = {}
	return out

func _process(_delta: float) -> void:
	if _hitstop > 0:
		_hitstop -= 1
		if _hitstop == 0: Engine.time_scale = 1.0

func _exit_tree() -> void:
	if _hitstop > 0: Engine.time_scale = 1.0

## A lock target (an enemy) with its aim point within ENEMY_REACH of his
## chest, ahead of him; null none.
func _enemy_ahead(m: PilotMotor) -> Node3D:
	if not is_inside_tree(): return null
	var chest := m.feet+Vector3.UP*CHEST*_size
	for n: Node in get_tree().get_nodes_in_group(&"lock_targets"):
		if not (n is Node3D) or not is_instance_valid(n) or not n.has_method("aim_point"): continue
		var p: Vector3 = n.aim_point()
		var off := p-chest
		var flat := Vector2(off.x,off.z)
		if flat.dot(_dir) < -0.3*_size: continue
		var reach := ENEMY_REACH*_size
		if flat.length() <= reach and absf(off.y) <= reach*1.5: return n as Node3D
	return null

## Whether a feeler meets a face against his way now (kept in `_touch`).
func _feel(m: PilotMotor) -> bool:
	_touch = {}
	if ground == null or ground.get("space") == null: return false
	var space := ground.get("space") as PhysicsDirectSpaceState3D
	var way := Vector3(_dir.x,0.0,_dir.y)
	var side := Vector3(-_dir.y,0.0,_dir.x)
	var reach := (PhysicsGround.RADIUS+FEEL_AHEAD)*_size
	var from: Array[Vector3] = []
	for h: float in FEEL_HIGH: from.append(m.feet+Vector3.UP*h*_size)
	var mid := m.feet+Vector3.UP*float(FEEL_HIGH[1])*_size
	from.append(mid+side*FEEL_SIDE*_size)
	from.append(mid-side*FEEL_SIDE*_size)
	for a: Vector3 in from:
		var q := PhysicsRayQueryParameters3D.create(a,a+way*reach)
		q.collision_mask = int(ground.get("mask"))
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty(): continue
		var n: Vector3 = hit.normal
		if absf(n.y) > FEEL_STEEP or n.dot(way) > -FEEL_FACING: continue
		n.y = 0.0
		_touch = {"at":hit.position,"normal":n.normalized()}
		return true
	return false

## The contact: what a feeler met, else a ray from his chest along the way,
## else just ahead of him facing back. {at, normal (flat)}.
func _contact(m: PilotMotor) -> Dictionary:
	if not _touch.is_empty():
		var t := _touch
		_touch = {}
		return t
	var chest := m.feet+Vector3.UP*CHEST*_size
	var way := Vector3(_dir.x,0.0,_dir.y)
	if ground != null and ground.get("space") != null:
		var q := PhysicsRayQueryParameters3D.create(chest-way*0.3*_size,chest+way*(1.2*_size+_pace*_dt))
		q.collision_mask = int(ground.get("mask"))
		var hit: Dictionary = (ground.get("space") as PhysicsDirectSpaceState3D).intersect_ray(q)
		if not hit.is_empty():
			var n: Vector3 = hit.normal
			n.y = 0.0
			return {"at":hit.position,"normal":n.normalized() if n.length() > 0.2 else -way}
	return {"at":chest+way*0.35*_size,"normal":-way}

## The hit: the hubs, the slam's group, an enemy; the feel; the rebound.
func _hit(m: PilotMotor, enemy: Node3D) -> void:
	var way := Vector3(_dir.x,0.0,_dir.y)
	var c := _contact(m)
	if enemy != null:
		var p: Vector3 = enemy.call("aim_point")
		var off := Vector3(m.feet.x-p.x,0.0,m.feet.z-p.z)
		c = {"at":p-way*0.4*_size,"normal":off.normalized() if off.length() > 0.05 else -way}
	var at: Vector3 = c.at
	var normal: Vector3 = c.normal
	var radius := HIT_RADIUS*_size
	var broke := 0
	if is_inside_tree():
		for hub: Node in get_tree().get_nodes_in_group(Slam.HUBS):
			if is_instance_valid(hub) and hub.has_method("hit"): broke += int(hub.hit(at,radius,-1.0,SOURCE))
		for node: Node in get_tree().get_nodes_in_group(Slam.GROUP):
			if is_instance_valid(node) and node.has_method("slam"): node.slam(at,radius,PUSH)
		for n: Node in get_tree().get_nodes_in_group(&"lock_targets"):
			if not is_instance_valid(n) or not n.has_method("hit") or not n.has_method("aim_point"): continue
			var p: Vector3 = n.aim_point()
			if n == enemy or p.distance_to(at) <= radius+ENEMY_REACH*_size: n.hit(at,way,KNOCK)
	# The rebound: off the normal, his own bounce mixed in.
	var bounce := way-2.0*way.dot(normal)*normal
	var out := (normal*(1.0-BOUNCE)+bounce*BOUNCE)
	out.y = 0.0
	out = out.normalized() if out.length() > 0.05 else normal
	var pace := pow(_size,PilotMotor.PACE_POWER)
	var vy := sqrt(2.0*m.gravity*REBOUND_RISE*_size)
	m.toss(Vector3(out.x*REBOUND_OUT*pace,vy,out.z*REBOUND_OUT*pace))
	m.move = "kick"
	# Still facing what he hit, thrown back from it: a recoil the follow
	# camera keeps (it never swings round to his face).
	m.facing = PilotMotor.facing_of(_dir)
	if _up != null: _up.set("_prev_move","kick")   # the rebound's kick bumps no charge
	phase = ""
	hits += 1
	last = {"at":at,"normal":normal,"way":out,"broke":broke,"enemy":enemy != null,"kind":"enemy" if enemy != null else "wall"}
	_events["side_slam"] = last
	_feel_hit(way)
	_bursts.append({"at":at+normal*0.05,"n":normal,"t":0.0,"turn":randf()*TAU})

func _feel_hit(way: Vector3) -> void:
	_fov_goal = 0.0
	_fov = -FOV_PUNCH
	_kick_t = KICK_TIME
	_kick_way = way
	if _hitstop <= 0 or HITSTOP_SCALE < Engine.time_scale: Engine.time_scale = HITSTOP_SCALE
	_hitstop = maxi(_hitstop,HITSTOP_FRAMES)
	Pad.pulse(PULSE.x,PULSE.y,PULSE.z)

## Run out with nothing met: his pace cut, he falls back to the ground.
func _run_out(m: PilotMotor) -> void:
	m.velocity.x = _dir.x*_pace*MISS_KEEP
	m.velocity.z = _dir.y*_pace*MISS_KEEP
	m.velocity.y = minf(m.velocity.y,0.0)
	if m.move == "lunge": m.move = ""
	misses += 1
	_events["side_slam_miss"] = true
	_end()

func _end() -> void:
	phase = ""
	_fov_goal = 0.0

# --- Feel ---------------------------------------------------------------------------

## The view: narrower through the coil, wide through the lunge; on the hit
## punched in, jolted along the lunge and shaken.
func apply_feel(camera: Camera3D) -> void:
	_cam = camera
	if camera == null: return
	var dt := get_process_delta_time()
	if dt > 0.0: _fov = lerpf(_fov,_fov_goal,1.0-exp(-dt/FOV_EASE))
	if absf(_fov) > 0.01:
		camera.fov += _fov
		_fov_applied = _fov
	if _kick_t > 0.0:
		_kick_t = maxf(_kick_t-dt/maxf(Engine.time_scale,0.2),0.0)
		var u := 1.0-_kick_t/KICK_TIME
		var jolt := minf(u/0.12,1.0)*pow(1.0-u,2.0)
		var shake := pow(maxf(1.0-u*KICK_TIME/SHAKE_TIME,0.0),2.0)*SHAKE*_size
		var wob := camera.global_basis.x*sin(_clock*73.0)*shake+camera.global_basis.y*sin(_clock*61.0+1.1)*shake
		camera.global_position += _kick_way*KICK*_size*jolt+wob

# --- Look ---------------------------------------------------------------------------

func _step_bursts(delta: float) -> void:
	for i in range(_bursts.size()-1,-1,-1):
		_bursts[i].t += delta
		if float(_bursts[i].t) > BURST_TIME+BURST_FADE: _bursts.remove_at(i)

## Speed streaks behind him through the lunge; the shockwave spreading on
## the wall he hit, in the breeze's brush.
func _draw() -> void:
	if _mesh == null: return
	_mesh.clear_surfaces()
	var strokes: Array = []
	if phase == "lunge" and _trail.size() >= 3:
		for i in range(STREAKS):
			var path := PackedVector3Array()
			for s: Dictionary in _trail:
				path.append((s.at as Vector3)+(s.side as Vector3)*float(STREAK_SIDE[i])*_size+Vector3.UP*float(STREAK_HIGH[i])*_size)
			strokes.append({"path":path,"width":STREAK_WIDTH*_size,"alpha":STREAK_ALPHA,"seed":float(i)*7.0})
	for b: Dictionary in _bursts:
		var t: float = b.t
		var u := clampf(t/BURST_TIME,0.0,1.0)
		var e := 1.0-pow(1.0-u,3.0)
		var fade := 1.0 if t <= BURST_TIME else clampf(1.0-(t-BURST_TIME)/BURST_FADE,0.0,1.0)
		var n: Vector3 = b.n
		var a1 := n.cross(Vector3.UP).normalized()
		if a1.length() < 0.5: a1 = Vector3.RIGHT
		var a2 := a1.cross(n).normalized()
		var r := BURST_R*_size*maxf(e,0.08)
		for i in range(BURST_ARCS):
			var a0: float = float(b.turn)+TAU*float(i)/float(BURST_ARCS)
			var path := PackedVector3Array()
			for j in range(7):
				var a := a0+TAU/float(BURST_ARCS)*0.75*float(j)/6.0
				path.append((b.at as Vector3)+(a1*cos(a)+a2*sin(a))*r+n*0.1*_size*e)
			strokes.append({"path":path,"width":lerpf(0.5,0.2,e)*_size,"alpha":0.7*fade,"seed":float(i)*5.0+float(b.turn)})
	Updraft.draw_strokes(_mesh,strokes,0.2*_size)
